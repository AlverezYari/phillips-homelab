# SPEC: ghmon3 — UX overhaul + failure insights, third loop

Continuing the same project as loops 1 and 2 (merged as PRs #1 and #2).
Read `CLAUDE.md` (authoritative) and `gh-working-man.md` (handoff) in the
repo before item 1. Live on main and not to be regressed: M1–M8, api tests,
status flash, log search/filter, theme+keybinding config overrides, `org:`
filter fan-out, job-URL open, per-job rerun.

This loop is driven by operator feedback from real use: the default look is
fatiguing, failures don't stand out, wide terminals waste space, one bad
repo poisons an org section, and there is no failure-trend visibility.

## Requirements

- [ ] Restrained default theme: neutral fg/bg for chrome (title, tabs,
      headers, key hints) and table text; color reserved for semantics —
      green success, red failure, dim skipped — plus a subtle selection
      highlight and ONE accent use (active tab). Keep the current
      orange-heavy look available as a named built-in theme ("blaze" or
      similar) selectable from config; verify config theme overrides
      actually restyle these surfaces end-to-end. Unit-test theme
      resolution as a pure function.
- [ ] Failed runs must pop in the run list: a loud, unambiguous failure
      treatment (e.g. red marker/badge + bold row text) that reads
      instantly when scanning a full page of rows. skipped stays dim,
      success stays quiet. Unit-test the row-style resolution.
- [ ] Flexible column layout: stop fixed-truncating Workflow/Branch/Event
      while the right half of a wide terminal sits empty. Keep naturally
      narrow columns (Status, Duration, Started) fixed; distribute the
      remaining width to Workflow and Branch; recompute on terminal
      resize. Shorten Event labels instead of truncating (pull_request →
      "PR", workflow_dispatch → "manual", etc.). Unit-test the width
      allocation as a pure function over terminal widths.
- [ ] Org fan-out resilience: one failing repo must not fail the section.
      Render results from the repos that succeeded, surface the failing
      repo as a compact per-repo warning (not a section-wide error), and
      wrap the error context exactly once (currently doubled: "list runs
      (org X, repo X/Y): list runs X/Y: ..."). Distinguish a permanent
      per-repo condition (404 / Actions disabled → skip with badge) from
      a transient error (worth surfacing as retryable). Mock-test partial
      fan-out failure and both error classes.
- [ ] Failure-stats aggregation layer: pure functions that, given runs,
      compute per-workflow and per-section failure counts and rates over
      selectable windows (24h / 7d / 30d). Extend the api layer to fetch
      runs with a `created>=` filter for the window. Runs already carry
      conclusion/created_at. Mock-test aggregation and window filtering.
- [ ] Stats view: a screen (or tab) showing failure rate + counts per
      workflow over the selected window, with a keybinding to cycle
      24h/7d/30d. Simple textual bars are fine; readability over flash.
- [ ] Bad-actor attribution in the stats view: group failures by actor,
      head_branch, and workflow — a small "top breakage sources" breakdown
      (e.g. "flaky-e2e: 12 fails/7d", "renovate/*: 8"). Runs already carry
      actor and head_branch. Unit-test the grouping/ranking.
- [ ] Readability polish pass across all views: consistent alignment,
      spacing, truncation behavior, timestamp formats, and header
      treatment. No new features in this item; smallest diffs that make
      each screen scan cleanly.

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
  genuinely ambiguous AND consequential. For theme/layout items the intent
  above is the spec — do not file decisions over color-shade choices.
- No secrets in code/logs/commits. Only the origin remote.
- All done + green -> /workspace/.loop-done AND /workspace/PR.md (reviewer-
  facing: what changed / how verified / review notes). All remaining
  blocked -> /workspace/.loop-blocked.
