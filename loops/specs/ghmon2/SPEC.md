# SPEC: ghmon2 — gh-working-man backlog, second loop

Continuing the same project as the first loop (merged as PR #1). Read
`CLAUDE.md` (authoritative) and `gh-working-man.md` (handoff) in the repo
before item 1. M1–M8 plus the first loop's work (api tests, status flash,
log search/filter) are live on main; do not regress them.

## Requirements

- [ ] Revert the go-gh/v2 downgrade from the first loop: the toolchain here
      is now Go 1.25, so restore the latest go-gh v2 (and re-vendor). Gates
      must stay green.
- [ ] Apply theme overrides from config at runtime (they currently parse
      but do nothing). Unit-test the config→style resolution as a pure
      function.
- [ ] Apply keybinding overrides from config at runtime (same wart).
      Unit-test the config→keymap resolution.
- [ ] `org:` filter support: list the org's repos via the API and fan out
      ListRuns across them; remove the validator rejection. Respect the
      section's limit across the fan-out. Mock-test the fan-out and the
      limit clamping.
- [ ] `o` on a job row opens the job's html_url (Job already carries it);
      `o` on a run row keeps opening the run URL.
- [ ] Per-job rerun: `R` on a job row calls /jobs/{id}/rerun, and add a
      rerun-failed-jobs-only action on the run (uses
      /runs/{id}/rerun-failed-jobs). Both shift-guarded with the existing
      y/N confirm prompt pattern. Mock-test the api-layer calls.

## Validation gates (harness-enforced)

`make build test lint` — green, offline, no gh auth (mocks only).

## Guardrails

- Repo conventions per CLAUDE.md: conventional commits, one logical change
  per commit, each commit builds. Commit your own work; the harness pushes.
- Known warts (gh-working-man.md): bubbles/table ANSI padding, lipgloss
  Width() word-wrap, submodel pointer re-sync.
- Never run the TUI in tests; pure logic and api layer only.
- Max 3 distinct attempts per item, then BLOCKED + decision file, move on.
- UX judgment calls: simplest reading of CLAUDE.md; decisions only if
  genuinely ambiguous AND consequential.
- No secrets in code/logs/commits. Only the origin remote.
- All done + green -> /workspace/.loop-done AND /workspace/PR.md (reviewer-
  facing: what changed / how verified / review notes). All remaining
  blocked -> /workspace/.loop-blocked.
