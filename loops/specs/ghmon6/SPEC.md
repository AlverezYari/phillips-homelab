# SPEC: ghmon6 — stats view polish round 2, sixth loop

Continuing the same project as loops 1–5 (merged as PRs #1–#5). Read
`CLAUDE.md` (authoritative) and `gh-working-man.md` (handoff) in the repo
before item 1. Small, surgical loop: refine the loop-5 stats redesign
based on operator screenshots of real data. Do not regress loop-5's
tests — extend them.

Observed on real data: the severity style is applied to the ENTIRE bar
string, so the empty glyphs render as solid slabs — a 0% (0/169) row
draws a full-width grey block and a 1% (1/123) row draws a full-width
olive block whose actual 1-cell fill is invisible. With full-terminal
flex width and no visual separation, the empty bar space is the loudest
element on screen. Separately, every breakage-source line is bold red
even at 1–2 fails, and the breakdown's workflow group duplicates the
per-workflow table directly above it.

## Requirements

- [ ] Bar fill/empty separation: style filled cells with the severity
      color and empty cells near-invisibly (very dark glyph or plain
      background) — never wrap the whole bar in one style. Nonzero rates
      always render at least 1 filled cell. Extend the loop-5 bar tests:
      0% shows no filled cells, 1% of a wide bar shows exactly the
      minimum fill, styles differ between fill and empty segments.
- [ ] Bar column restraint: cap the bar column at a maximum width (~40
      cells) instead of absorbing all flex space — return surplus width
      to the workflow-name column. Keep it proportional below the cap on
      narrow terminals. Update the column-allocation tests.
- [ ] Breakage-source severity grading: source lines use graded emphasis
      via the theme palette — muted/neutral at 1 fail, warm at moderate
      counts, red reserved for genuinely hot sources (relative to the
      group's max or a small threshold; pick simply, don't over-model).
      No more bold-red-for-everything. Unit-test the grading resolution.
- [ ] De-duplicate the workflow breakdown group: it repeats the
      per-workflow table above it. Show it only when it adds signal —
      e.g. only sources with 2+ fails — and omit the group entirely when
      empty. actor/branch groups unchanged. Unit-test inclusion logic.

## Validation gates (harness-enforced)

`make build test lint` — green, offline, no gh auth (mocks only).

## Guardrails

- Repo conventions per CLAUDE.md: conventional commits, one logical change
  per commit, each commit builds. Commit your own work; the harness pushes.
- All colors via the theme palette (internal/ui/theme.go); verify default
  and blaze both resolve. Measure widths with lipgloss.Width, never len().
- Never run the TUI in tests; pure logic and rendering-as-string only.
- Max 3 distinct attempts per item, then BLOCKED + decision file, move on.
- Judgment calls: simplest reading of CLAUDE.md; decisions only if
  genuinely ambiguous AND consequential. Exact glyphs, the bar cap width,
  and grading thresholds are operator-tunable details — pick reasonable
  values, do not file decisions over them.
- No secrets in code/logs/commits. Only the origin remote.
- All done + green -> /workspace/.loop-done AND /workspace/PR.md (reviewer-
  facing: what changed / how verified / review notes). All remaining
  blocked -> /workspace/.loop-blocked.
