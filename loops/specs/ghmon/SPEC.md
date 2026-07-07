# SPEC: ghmon — gh-working-man backlog, first loop

You are continuing an existing, working project: a gh CLI extension showing
a live GitHub Actions dashboard TUI. **Read these in the repo before item 1:**
`CLAUDE.md` (authoritative brief and conventions) and `gh-working-man.md`
(current-state handoff: layout, known warts, backlog rationale).

This loop covers the top of the backlog. M1–M8 work; do not regress them.

## Requirements

- [ ] Add a `Makefile` with `build` (`go build ./...`), `test`
      (`go test ./...`), and `lint` (`go vet ./...`) targets. These are the
      harness validation gates; they must pass in a container with NO
      network and NO gh auth (tests must never hit the real GitHub API).
- [ ] Tests for `internal/api/`: mock the go-gh REST client; cover
      filter → query-param mapping, pagination/limit handling, and error
      paths for runs, jobs, logs, and user (`@me` resolution). Aim for the
      api package to be meaningfully covered, not a token test.
- [ ] Status-transition flash on the list view: diff run conclusions across
      poll ticks; on completion, flash the row briefly (green success / red
      failure) then settle to the normal style. Include unit tests for the
      transition-detection logic (pure function, no TUI needed).
- [ ] Log viewer search/filter: `/` opens search, `n`/`N` next/prev match,
      regex include/exclude filter, dim timestamp prefixes, colorize
      `##[error]` / `##[warning]` / `##[group]` markers (parsing exists in
      `internal/model/logparse.go`). Unit-test the match/filter logic.

## Validation gates (harness-enforced)

`make build test lint` — must stay green with no network and no gh auth.

## Guardrails

- Respect repo conventions (CLAUDE.md): conventional commits, one logical
  change per commit, each commit builds. Commit your own work with proper
  messages; the harness only pushes.
- Mind the known warts in gh-working-man.md: bubbles/table ANSI padding,
  lipgloss Width() word-wrap trap, submodel pointer re-sync in app.go.
- The TUI itself cannot be driven headlessly — do not add tests that run
  the bubbletea program; test pure logic and the api layer only.
- Max 3 distinct attempts per item, then BLOCKED + decision file
  (/workspace/decisions/NNN-slug.json), move to the next item.
- Architecture or UX judgment calls (e.g. flash duration/style, search UX
  details beyond the brief): prefer the simplest reading of CLAUDE.md; file
  a decision only if genuinely ambiguous AND consequential.
- No secrets in code, logs, or commits. Never touch git remotes other than
  origin (Forgejo).
- All items done + gates green -> write /workspace/.loop-done. All remaining
  items BLOCKED -> write /workspace/.loop-blocked.
