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
import os
import sys
from typing import Any

import httpx
from rich.console import Console
from rich.prompt import Confirm
from rich.table import Table

console = Console()


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
    args = ap.parse_args()

    targets = gather_targets(args.targets)
    targets_set = set(targets)

    password = os.environ.get("SYNO_PASS") or getpass.getpass(
        f"DSM password for {args.user}@{args.host}: "
    )

    with httpx.Client(timeout=30.0) as client:
        sid = login(client, args.host, args.port, args.user, password)
        try:
            luns = list_luns(client, args.host, args.port, sid)
            by_name = {lun["name"]: lun for lun in luns}
            matches = [(name, by_name[name]) for name in targets if name in by_name]
            missing = [name for name in targets if name not in by_name]

            table = Table(title=f"LUNs on {args.host} matched against {len(targets)} PV name(s)")
            table.add_column("Name", style="cyan", no_wrap=False)
            table.add_column("Size", justify="right")
            table.add_column("Status")
            table.add_column("Mapped targets", justify="right")
            table.add_column("UUID (truncated)", style="dim")
            for name, lun in matches:
                size_gib = lun.get("size", 0) / (1024**3)
                mapped = len(lun.get("mapped_targets") or [])
                uuid_short = (lun.get("uuid", "") or "")[:8]
                table.add_row(name, f"{size_gib:.1f} GiB", str(lun.get("status", "?")), str(mapped), uuid_short)
            console.print(table)

            if missing:
                console.print(
                    f"[yellow]not found in DSM ({len(missing)}):[/yellow] " + ", ".join(missing)
                )

            if not matches:
                console.print("[yellow]no matching LUNs to delete.[/yellow]")
                return 0

            mapped_present = [name for name, lun in matches if lun.get("mapped_targets")]
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
            for name, lun in matches:
                console.print(f"deleting [cyan]{name}[/cyan] ... ", end="")
                resp = delete_lun(client, args.host, args.port, sid, lun["uuid"])
                if resp.get("success"):
                    console.print("[green]ok[/green]")
                else:
                    err = resp.get("error", resp)
                    console.print(f"[red]failed: {err}[/red]")
                    failures.append((name, err))

            if failures:
                console.print(f"\n[red]{len(failures)} deletion(s) failed.[/red]")
                return 1
            console.print(f"\n[green]all {len(matches)} LUN(s) deleted.[/green]")
            return 0
        finally:
            logout(client, args.host, args.port, sid)


if __name__ == "__main__":
    raise SystemExit(main())
