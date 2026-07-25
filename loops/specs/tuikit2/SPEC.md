# SPEC — tuikit2: geometry correction — chips are pills, height is law

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

## Why this loop exists (read carefully — it's a correction)

The tuikit restyle (PR #85) got states right and geometry catastrophically
wrong. On a real 40-row terminal the Settings pane rendered every chip as
a lipgloss-BORDERED box (3+ rows each, blank rows between), the total
View exceeded the terminal height, and bubbletea pushed the header off
the top of the screen. Founder verdict on the live result: "really bad
first pass."

Root cause to internalize: in the design's HTML mock, chips are
single-row inline pills (`padding:0 6px`, hairline border, content
width, several per row). A hairline border does not exist in a
terminal — `lipgloss.Border` costs +2 rows. Therefore in terminal
translation, **chips have NO lipgloss border, ever**. State is carried
by background fill, foreground color, and marks, on ONE row.

## Geometry law (non-negotiable, test-enforced)

1. **Chip = exactly 1 row.** `Padding(0,1)`, content width. States,
   extracted from the mock's pattern kit:
   - on: `✓ label` — good (#3ddc97) fg on subtle raised bg (#262626)
   - off: `· label` — dim fg (#7f7f7f) on subtle bg
   - read-only value: `label value` — secondary fg on subtle bg
   - selected (cursor): accent (#ff8c1a) BACKGROUND, near-black fg,
     bold — the only chip state with a loud fill
   - pending (sent, not acked): warn (#ff9d2e) fg + `…` suffix
   - locked/unavailable: dimmest fg, `[—]` mark
2. **Chip grid:** chips joined on a row with a 2-space gap, wrapped to
   as many per row as width allows (uniform cell width per row batch is
   fine); NO blank rows between chip rows; toggles before values
   (existing behavior).
3. **Total View height ≤ terminal height. Always.** Restore/respect the
   height budgeting the pre-restyle code had: panes share the vertical
   budget from tea.WindowSizeMsg; the Events pane is the flexible one;
   the header/status line must NEVER scroll off.
4. **Density ceiling:** for the same model state, the new layout may
   not be taller than the pre-restyle layout (commit d96f995) ±2 rows.
   That layout fit; treat it as the budget.
5. Pane borders (single-line, square) remain pane-only. One blank row
   between stacked panes, none inside a pane body.

## Enforcement (the part the last loop lacked)

- Golden tests that render the FULL View from a populated fixture
  (scope connected, ~15 settings chips, 3 albums, 6 events) at 120x40
  and 80x24 and assert `lines(View()) <= height` — these two tests are
  the reason this SPEC exists; write them FIRST, red, then fix until
  green.
- A chip-height test: any chip state renders to exactly 1 line.
- PR.md MUST embed the raw ASCII render of the 120x40 fixture View in
  a code block, so a human can see the layout in review without
  building. If it looks like bordered boxes again, the loop has failed
  regardless of green gates.

## Work items

- [ ] Height-law golden tests (red first) + chip 1-row test.
- [ ] Rewrite tuikit.Chip to the pill spec above; update chip golden
  tests to the new truth.
- [ ] Restore pane height budgeting in scopetui's View composition
  (header + status always visible; Events flexes; 80-col single-pane
  path keeps working).
- [ ] Density pass: blank-row audit inside panes; verify against the
  d96f995 ceiling; update docs/dev/tui-style.md's geometry section and
  embed the fixture render in PR.md.

## Warts

- Do not touch the headless seam, Theme colors, Pane/Bar/StatusBar
  helpers' state logic — they're correct; this is geometry only.
- Comment style: docs/dev/style.md.
