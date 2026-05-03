#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "httpx",
#   "rich",
# ]
# ///
"""
Bulk-mirror GitHub repos into Forgejo.

Lists repos owned by a GitHub user, filters out the boring ones (forks,
archived, explicit skip list), and creates a pull-mirror in Forgejo for
each via the migration API. Idempotent: repos that already exist in
Forgejo are reported as skipped, not re-migrated.

Auth: uses a GitHub PAT (read on the source repos) + a Forgejo PAT
(write:repository on the destination user). Both can come from env
(GITHUB_TOKEN, FORGEJO_TOKEN) or interactive prompt.

Usage:
    # Dry-run first to see what would happen:
    uv run scripts/forgejo-mirror-github.py --dry-run

    # Real run, takes from env:
    GITHUB_TOKEN=ghp_... FORGEJO_TOKEN=... uv run scripts/forgejo-mirror-github.py

    # Different host/user:
    uv run scripts/forgejo-mirror-github.py \\
      --github-user otherperson --forgejo-owner mirrors

    # Skip extra repos:
    uv run scripts/forgejo-mirror-github.py --skip experimental-thing,other-repo
"""

from __future__ import annotations

import argparse
import getpass
import os
import sys
from typing import Any

import httpx
from rich.console import Console
from rich.table import Table
from rich.prompt import Confirm

console = Console()


def list_github_repos(
    client: httpx.Client,
    github_user: str,
    token: str,
    include_forks: bool,
    include_archived: bool,
) -> list[dict[str, Any]]:
    """List all repos owned by `github_user`, paginated."""
    repos: list[dict[str, Any]] = []
    page = 1
    while True:
        r = client.get(
            "https://api.github.com/user/repos",
            params={
                "per_page": 100,
                "page": page,
                "affiliation": "owner",
                "sort": "updated",
            },
            headers={
                "Authorization": f"Bearer {token}",
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
            },
        )
        r.raise_for_status()
        batch = r.json()
        if not batch:
            break
        for repo in batch:
            if repo.get("owner", {}).get("login") != github_user:
                continue
            if not include_forks and repo.get("fork"):
                continue
            if not include_archived and repo.get("archived"):
                continue
            repos.append(repo)
        if len(batch) < 100:
            break
        page += 1
    return repos


def forgejo_repo_exists(
    client: httpx.Client, forgejo_url: str, forgejo_token: str, owner: str, name: str
) -> bool:
    r = client.get(
        f"{forgejo_url}/api/v1/repos/{owner}/{name}",
        headers={"Authorization": f"token {forgejo_token}"},
    )
    return r.status_code == 200


def forgejo_migrate(
    client: httpx.Client,
    forgejo_url: str,
    forgejo_token: str,
    github_url: str,
    owner: str,
    name: str,
    mirror_interval: str,
    private: bool,
    github_user: str,
    github_token: str,
) -> dict[str, Any]:
    payload = {
        "clone_addr": github_url,
        "repo_owner": owner,
        "repo_name": name,
        "service": "github",
        "mirror": True,
        "mirror_interval": mirror_interval,
        "private": private,
        "auth_username": github_user,
        "auth_token": github_token,
    }
    r = client.post(
        f"{forgejo_url}/api/v1/repos/migrate",
        json=payload,
        headers={
            "Authorization": f"token {forgejo_token}",
            "Content-Type": "application/json",
        },
    )
    return {"status": r.status_code, "body": r.json() if r.content else None}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--github-user", default=os.environ.get("GITHUB_USER", "AlverezYari"))
    ap.add_argument(
        "--forgejo-url",
        default=os.environ.get("FORGEJO_URL", "https://code.phillips-homelab.net"),
        help="Forgejo base URL.",
    )
    ap.add_argument(
        "--forgejo-owner",
        default=os.environ.get("FORGEJO_OWNER", "cphillips-homelab"),
        help="Forgejo user/org that will own the mirrored repos.",
    )
    ap.add_argument("--mirror-interval", default="1h", help="Forgejo mirror sync interval (e.g. 1h, 8h, 24h).")
    ap.add_argument(
        "--private", action=argparse.BooleanOptionalAction, default=True,
        help="Mark the local mirror as private (default true).",
    )
    ap.add_argument(
        "--include-forks", action="store_true",
        help="Include repos that are forks of upstream projects.",
    )
    ap.add_argument(
        "--include-archived", action="store_true",
        help="Include archived repos.",
    )
    ap.add_argument(
        "--skip",
        default="phillips-homelab",
        help="Comma-separated repo names to skip (default: phillips-homelab — already mirrored).",
    )
    ap.add_argument("--dry-run", action="store_true", help="List what would happen; don't migrate.")
    ap.add_argument("--yes", action="store_true", help="Skip the confirmation prompt before migrating.")
    args = ap.parse_args()

    skip_set = {s.strip() for s in args.skip.split(",") if s.strip()}

    github_token = os.environ.get("GITHUB_TOKEN") or getpass.getpass(
        f"GitHub PAT (read:contents for {args.github_user}'s repos): "
    )
    forgejo_token = os.environ.get("FORGEJO_TOKEN") or getpass.getpass(
        f"Forgejo PAT (write:repository for {args.forgejo_owner}@{args.forgejo_url}): "
    )

    with httpx.Client(timeout=httpx.Timeout(60.0, connect=10.0)) as client:
        console.print(f"[dim]Listing repos for [bold]{args.github_user}[/bold] on GitHub...[/dim]")
        repos = list_github_repos(
            client, args.github_user, github_token,
            include_forks=args.include_forks,
            include_archived=args.include_archived,
        )
        console.print(f"[dim]Found {len(repos)} candidate repo(s) after filters.[/dim]")

        # Classify each against Forgejo state + skip list
        plan = []
        for repo in repos:
            name = repo["name"]
            if name in skip_set:
                plan.append((repo, "skip-explicit"))
                continue
            if forgejo_repo_exists(client, args.forgejo_url, forgejo_token, args.forgejo_owner, name):
                plan.append((repo, "skip-already-exists"))
                continue
            plan.append((repo, "migrate"))

        # Show table
        table = Table(title=f"Migration plan: {args.github_user} → {args.forgejo_owner}@{args.forgejo_url}")
        table.add_column("Repo", style="cyan")
        table.add_column("Visibility")
        table.add_column("Updated", style="dim")
        table.add_column("Action")
        for repo, action in plan:
            color = {"migrate": "green", "skip-already-exists": "yellow", "skip-explicit": "yellow"}[action]
            visibility = "private" if repo.get("private") else "public"
            updated = repo.get("updated_at", "?")[:10]
            table.add_row(repo["name"], visibility, updated, f"[{color}]{action}[/{color}]")
        console.print(table)

        to_migrate = [r for r, a in plan if a == "migrate"]
        already = sum(1 for _r, a in plan if a == "skip-already-exists")
        skipped = sum(1 for _r, a in plan if a == "skip-explicit")
        console.print(
            f"\n[bold]{len(to_migrate)}[/bold] to migrate · "
            f"[yellow]{already}[/yellow] already exist · "
            f"[yellow]{skipped}[/yellow] explicitly skipped"
        )

        if not to_migrate:
            console.print("[green]nothing to do.[/green]")
            return 0

        if args.dry_run:
            console.print("[blue]--dry-run: no migrations performed.[/blue]")
            return 0

        if not args.yes:
            if not Confirm.ask(f"\n[bold]Mirror {len(to_migrate)} repo(s) into Forgejo?[/bold]", default=False):
                console.print("aborted.")
                return 1

        failures = []
        for repo in to_migrate:
            name = repo["name"]
            console.print(f"mirroring [cyan]{name}[/cyan] ... ", end="")
            try:
                resp = forgejo_migrate(
                    client,
                    args.forgejo_url,
                    forgejo_token,
                    repo["clone_url"],
                    args.forgejo_owner,
                    name,
                    args.mirror_interval,
                    private=args.private,
                    github_user=args.github_user,
                    github_token=github_token,
                )
            except httpx.HTTPError as e:
                console.print(f"[red]http error: {e.__class__.__name__}: {e}[/red]")
                failures.append((name, str(e)))
                continue
            if resp["status"] in (200, 201):
                console.print("[green]ok[/green]")
            else:
                console.print(f"[red]failed ({resp['status']}): {resp['body']}[/red]")
                failures.append((name, resp))

        if failures:
            console.print(f"\n[red]{len(failures)} failure(s).[/red]")
            return 1
        console.print(f"\n[green]all {len(to_migrate)} repo(s) mirrored.[/green]")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
