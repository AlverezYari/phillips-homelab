# SPEC: ghmon5 — stats view visual redesign, fifth loop

Continuing the same project as loops 1–4 (merged as PRs #1–#4). Read
`CLAUDE.md` (authoritative) and `gh-working-man.md` (handoff) in the repo
before item 1. Do not regress anything live on main — especially the
ghmon4 rate-limit machinery (ETag cache, budget tracker, stats window
cache) and the ghmon3 theme system; all new styling must flow through the
theme palette so built-in themes (default, blaze) and config overrides
keep working.

Operator feedback driving this loop (from real use of the stats view):
"visually blunt, a bit hard to read." Specifics observed: hand-rolled
ASCII `[####----]` bars; entire rows painted bold red when failure rate
> 0 (name, bar, numbers all shout — color carries no signal); content
hugs a narrow left column while most of a wide terminal sits empty (the
run table got flex columns in loop 3, the stats view never did);
`100% (1/1)` renders like an inferno but is a single failed run; the
breakage breakdown spends five double-spaced lines on three one-item
groups, repeats "/30d" per line when the window is already in the
header, and says "1 fails".

## Requirements

- [ ] Block-glyph failure bar: replace `failureBar`'s `[####----]` with
      block elements (filled `█`, empty `░` or the project's chosen
      pair), no bracket noise, with severity-graded color from the theme
      palette (calm at low rates through loud at high). Pure function of
      (rate, width) for geometry + a separate style-resolution function
      for color; unit-test both (fill proportion at boundary rates 0,
      0.5, 1; grade thresholds).
- [ ] Color discipline in stats rows: workflow name stays neutral
      foreground; only the bar and the percentage carry the severity
      color; zero-failure rows muted as today. Update the row rendering
      and unit-test the row-style resolution.
- [ ] Flex-width stats layout: reuse the loop-3 column-allocation
      machinery (internal/model/columns.go) so the workflow-name column
      and bar width scale with terminal width and recompute on resize,
      instead of fixed statsBarWidth + narrow left hug. Unit-test
      allocation at narrow/wide widths.
- [ ] Low-sample damping: rows whose total run count is below a small
      threshold (e.g. 5) render the bar dimmed and show n prominently
      (e.g. "100% of 1 run" reads honestly instead of screaming). Config-
      overridable threshold; pick a sane default without filing a
      decision. Unit-test the damping cutoff.
- [ ] Compact breakage breakdown: one aligned line per source within
      each group (actor / branch / workflow), top-N with counts, no
      repeated window suffix (the window lives in the view header),
      correct pluralization ("1 fail", "2 fails"). Tighten vertical
      spacing so the section reads as one block. Unit-test the
      formatting as a pure function.
- [ ] Header/summary polish: the "overall: 1/2 failed (50%)" line gets
      the same bar language (small overall bar + honest n), and the
      window indicator reads cleanly with the keybinding hints. Align
      with the list view's header conventions from the loop-3
      readability pass.

## Validation gates (harness-enforced)

`make build test lint` — green, offline, no gh auth (mocks only).

## Guardrails

- Repo conventions per CLAUDE.md: conventional commits, one logical change
  per commit, each commit builds. Commit your own work; the harness pushes.
- Known warts (gh-working-man.md): bubbles/table ANSI padding, lipgloss
  Width() word-wrap, submodel pointer re-sync. Block glyphs + lipgloss
  Width() interactions deserve care — measure with lipgloss.Width, never
  len().
- All colors via the theme palette (internal/ui/theme.go) — never
  hard-code; verify default and blaze both resolve.
- Never run the TUI in tests; pure logic and rendering-as-string only.
- Max 3 distinct attempts per item, then BLOCKED + decision file, move on.
- Judgment calls: simplest reading of CLAUDE.md; decisions only if
  genuinely ambiguous AND consequential. Glyph choice, grade thresholds,
  and the damping default are operator-tunable details — pick reasonable
  values, do not file decisions over them.
- No secrets in code/logs/commits. Only the origin remote.
- All done + green -> /workspace/.loop-done AND /workspace/PR.md (reviewer-
  facing: what changed / how verified / review notes). All remaining
  blocked -> /workspace/.loop-blocked.
