#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "httpx",
#   "rich",
# ]
# ///
"""
Delete orphan Synology iSCSI LUNs that the CSI created (named pvc-<uuid>).

Reads PV names (one per line) from positional args or stdin, looks them up in
DSM's LUN list, shows what would be deleted, and asks for confirmation.

Auth: prompts for DSM password interactively. Host/user can come from env or
flags; defaults match the homelab.

Usage:
    # By args:
    uv run scripts/synology-lun-cleanup.py pvc-aaa... pvc-bbb...

    # From kubectl pipe:
    kubectl get pv -o jsonpath='{range .items[?(@.status.phase=="Released")]}{.metadata.name}{"\\n"}{end}' \\
      | uv run scripts/synology-lun-cleanup.py

    # Dry-run (just show what would be deleted):
    uv run scripts/synology-lun-cleanup.py --dry-run pvc-...

Env vars: SYNO_HOST (default 192.168.10.195), SYNO_PORT (5000), SYNO_USER
(homelab-srv), SYNO_PASS (if set, skip prompt — useful for piping but exposes
in process list / shell history; prefer the prompt).
"""

from __future__ import annotations

import argparse
import getpass
import json
import os
import subprocess
import sys
from typing import Any

import httpx
from rich.console import Console
from rich.prompt import Confirm
from rich.table import Table

console = Console()


def kubectl_pv_names() -> set[str]:
    """Return the set of PV names currently known to the cluster (any phase)."""
    proc = subprocess.run(
        ["kubectl", "get", "pv", "-o", "json"],
        check=True,
        capture_output=True,
        text=True,
    )
    obj = json.loads(proc.stdout)
    return {item["metadata"]["name"] for item in obj.get("items", [])}


def discover_orphans(luns: list[dict[str, Any]], prefix: str, live_pv_names: set[str]) -> list[str]:
    """LUNs whose <prefix><pv-name> is NOT in the live k8s PV set."""
    orphans = []
    for lun in luns:
        name = lun.get("name", "")
        if not name.startswith(prefix):
            continue
        bare = name[len(prefix):]
        if bare not in live_pv_names:
            orphans.append(bare)
    return sorted(orphans)


def login(client: httpx.Client, host: str, port: int, user: str, password: str) -> str:
    r = client.get(
        f"http://{host}:{port}/webapi/auth.cgi",
        params={
            "api": "SYNO.API.Auth",
            "version": "3",
            "method": "login",
            "account": user,
            "passwd": password,
            "session": "DSM",
            "format": "cookie",
        },
    )
    r.raise_for_status()
    body = r.json()
    if not body.get("success"):
        raise SystemExit(f"login failed: {body!r}")
    return body["data"]["sid"]


def logout(client: httpx.Client, host: str, port: int, sid: str) -> None:
    try:
        client.get(
            f"http://{host}:{port}/webapi/auth.cgi",
            params={
                "api": "SYNO.API.Auth",
                "version": "1",
                "method": "logout",
                "session": "DSM",
                "_sid": sid,
            },
        )
    except Exception as e:
        console.print(f"[yellow]warn: logout failed: {e}[/yellow]")


def list_luns(client: httpx.Client, host: str, port: int, sid: str) -> list[dict[str, Any]]:
    r = client.get(
        f"http://{host}:{port}/webapi/entry.cgi",
        params={
            "api": "SYNO.Core.ISCSI.LUN",
            "version": "1",
            "method": "list",
            "additional": '["mapped_targets","status","is_action_locked"]',
            "_sid": sid,
        },
    )
    r.raise_for_status()
    body = r.json()
    if not body.get("success"):
        raise SystemExit(f"list LUN failed: {body!r}")
    return body["data"]["luns"]


def delete_lun(client: httpx.Client, host: str, port: int, sid: str, uuid: str) -> dict[str, Any]:
    r = client.get(
        f"http://{host}:{port}/webapi/entry.cgi",
        params={
            "api": "SYNO.Core.ISCSI.LUN",
            "version": "1",
            "method": "delete",
            "uuid": f'"{uuid}"',
            "_sid": sid,
        },
    )
    r.raise_for_status()
    return r.json()


def gather_targets(args_targets: list[str]) -> list[str]:
    if args_targets:
        return args_targets
    if sys.stdin.isatty():
        raise SystemExit(
            "no PV names given (positional args) and stdin is a tty.\n"
            "  pipe in `kubectl get pv ...` output, or pass names as args."
        )
    names = [line.strip() for line in sys.stdin if line.strip()]
    if not names:
        raise SystemExit("no PV names read from stdin.")
    return names


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("targets", nargs="*", help="PV names (e.g. pvc-aaa...). If empty, read from stdin.")
    ap.add_argument("--host", default=os.environ.get("SYNO_HOST", "192.168.10.195"))
    ap.add_argument("--port", type=int, default=int(os.environ.get("SYNO_PORT", "5000")))
    ap.add_argument("--user", default=os.environ.get("SYNO_USER", "homelab-srv"))
    ap.add_argument("--dry-run", action="store_true", help="Show matches; don't delete.")
    ap.add_argument("--yes", action="store_true", help="Skip confirmation prompt.")
    ap.add_argument("--list-all", action="store_true", help="Diagnostic: print all LUNs DSM returns and exit.")
    ap.add_argument(
        "--prefix",
        default="k8s-csi-",
        help="Prefix the Synology CSI driver puts on LUN names. Default: k8s-csi-",
    )
    ap.add_argument(
        "--auto-discover",
        action="store_true",
        help="Discover orphans by querying kubectl for live PVs and diffing against DSM LUNs. "
        "Ignores positional args / stdin.",
    )
    args = ap.parse_args()

    if args.auto_discover:
        live_pvs = kubectl_pv_names()
        console.print(
            f"[dim]auto-discover: kubectl reports {len(live_pvs)} PV(s)[/dim]"
        )
        targets = []  # filled in after we have the LUN list
    else:
        targets = gather_targets(args.targets)

    password = os.environ.get("SYNO_PASS") or getpass.getpass(
        f"DSM password for {args.user}@{args.host}: "
    )

    # DSM is slow — large LUN deletes can take minutes (block deallocation,
    # iSCSI target unmapping). 5-min ceiling per request avoids surprise hangs
    # but lets normal deletes complete.
    with httpx.Client(timeout=httpx.Timeout(300.0, connect=10.0)) as client:
        sid = login(client, args.host, args.port, args.user, password)
        try:
            luns = list_luns(client, args.host, args.port, sid)
            by_name = {lun["name"]: lun for lun in luns}

            if args.list_all:
                console.print(f"[bold]All LUNs returned by DSM ({len(luns)}):[/bold]")
                for lun in sorted(luns, key=lambda x: x.get("name", "")):
                    size_gib = lun.get("size", 0) / (1024**3)
                    console.print(f"  {lun.get('name', '?'):<60} {size_gib:>7.1f} GiB")
                return 0

            if args.auto_discover:
                targets = discover_orphans(luns, args.prefix, live_pvs)
                console.print(
                    f"[dim]auto-discover: {len(targets)} orphan LUN(s) — DSM has them but kubectl doesn't.[/dim]"
                )
                if not targets:
                    console.print("[green]no orphans found.[/green]")
                    return 0

            # Synology CSI prepends `--prefix` to LUN names; the user-provided
            # names are PV UUIDs, so we look for `<prefix><pv-name>`.
            def lookup(pv_name: str) -> tuple[str, dict] | None:
                for candidate in (f"{args.prefix}{pv_name}", pv_name):
                    if candidate in by_name:
                        return candidate, by_name[candidate]
                return None

            resolved = [(pv, lookup(pv)) for pv in targets]
            matches = [(pv, found[0], found[1]) for pv, found in resolved if found]
            missing = [pv for pv, found in resolved if not found]

            table = Table(title=f"LUNs on {args.host} matched against {len(targets)} PV name(s)")
            table.add_column("PV name", style="cyan", no_wrap=False)
            table.add_column("LUN name", style="dim")
            table.add_column("Size", justify="right")
            table.add_column("Status")
            table.add_column("Mapped targets", justify="right")
            table.add_column("UUID (truncated)", style="dim")
            for pv_name, lun_name, lun in matches:
                size_gib = lun.get("size", 0) / (1024**3)
                mapped = len(lun.get("mapped_targets") or [])
                uuid_short = (lun.get("uuid", "") or "")[:8]
                table.add_row(
                    pv_name,
                    lun_name,
                    f"{size_gib:.1f} GiB",
                    str(lun.get("status", "?")),
                    str(mapped),
                    uuid_short,
                )
            console.print(table)

            if missing:
                console.print(
                    f"[yellow]not found in DSM ({len(missing)}):[/yellow] " + ", ".join(missing)
                )

            if not matches:
                console.print("[yellow]no matching LUNs to delete.[/yellow]")
                return 0

            mapped_present = [pv for pv, _ln, lun in matches if lun.get("mapped_targets")]
            if mapped_present:
                console.print(
                    f"[red]warning: {len(mapped_present)} LUN(s) still have mapped targets: "
                    f"{', '.join(mapped_present)}.\n"
                    "These may still be in use — verify before deleting.[/red]"
                )

            if args.dry_run:
                console.print("[blue]--dry-run: no deletions performed.[/blue]")
                return 0

            if not args.yes:
                if not Confirm.ask(
                    f"\n[bold]Delete {len(matches)} LUN(s)?[/bold] (irreversible)",
                    default=False,
                ):
                    console.print("aborted.")
                    return 1

            failures = []
            for pv_name, lun_name, lun in matches:
                console.print(f"deleting [cyan]{lun_name}[/cyan] ... ", end="")
                try:
                    resp = delete_lun(client, args.host, args.port, sid, lun["uuid"])
                except httpx.HTTPError as e:
                    # Timeouts often happen because DSM is slow but completes
                    # the delete anyway — re-running with --auto-discover later
                    # will reveal whether it actually went through.
                    console.print(f"[yellow]http error (may have completed): {e.__class__.__name__}: {e}[/yellow]")
                    failures.append((lun_name, str(e)))
                    continue
                if resp.get("success"):
                    console.print("[green]ok[/green]")
                else:
                    err = resp.get("error", resp)
                    console.print(f"[red]failed: {err}[/red]")
                    failures.append((lun_name, err))

            if failures:
                console.print(f"\n[red]{len(failures)} deletion(s) failed.[/red]")
                return 1
            console.print(f"\n[green]all {len(matches)} LUN(s) deleted.[/green]")
            return 0
        finally:
            logout(client, args.host, args.port, sid)


if __name__ == "__main__":
    raise SystemExit(main())
