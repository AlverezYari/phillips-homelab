# SPEC — tuikit: scopetui redesign phase A (pattern kit, theme, headless split, restyle)

Repo: `loop-bot/tycho`. Gate: `make build test lint` (offline — the
combine/scorer venv skips are expected and loud; your work is Go-only).

## Read first, it is the law

`docs/design/scopetui/README.md` — the design handoff. This SPEC
implements its **phase A** only: the pattern kit ("3 · Pattern kit"),
the design tokens, the grid rules, the headless split, and re-rendering
scopetui's EXISTING panes through the kit. You are NOT building the new
screens (6a/6b/6c/5a/5b/4a/4b/2c) — those need agent/operator data that
does not exist yet and come in later phases. Every current scopetui
feature must keep working in all three modes (-scope direct, -agent,
-conf field) — this phase changes how things LOOK and how view code is
STRUCTURED, not what the TUI does.

Current state: `agent/cmd/scopetui/` (~3.8k lines, package main), one
bubbletea model, hand-rolled lipgloss everywhere, ~12 package-level
style vars (main.go:71-86), rounded borders, ANSI-256 colors. No
`bubbles` imports — keep it that way in this phase (the handoff permits
`bubbles/textinput` for the `/` filter LATER; the filter is not in
phase A).

## Work items (one per iteration, in order)

- [ ] **Theme.** New package `agent/internal/tuikit`: a `Theme` struct
  holding every color from the handoff's Design-tokens table
  (background #1b1b1b, border #4d4d4d, rule #333333, text #e6e6e6 /
  #8f8f8f / #7f7f7f / #5a5a5a, accent #ff8c1a, good #3ddc97, info
  #56d4dd, warn #ff9d2e, bad #ff3b30) as
  `lipgloss.CompleteColor` — TrueColor hex plus a hand-picked ANSI256
  approximation for each (the current TUI's 208/42/81/196/240 values
  are good approximations for accent/good/info/bad/border). One
  `DefaultTheme`. State marks are constants here too (⇩ ○ ✓ ! ✗ ▮
  [✓] [ ] [—]) — color NEVER carries state alone (NO_COLOR rule).
- [ ] **Pattern kit, part 1: pane, bar, statusBar.** In `tuikit`,
  per the handoff's "Lip Gloss helpers" signatures: `Pane(title,
  state, body)` with Idle/Focused/Alert/Stale states (square
  `lipgloss.Border` single-line — rounded borders are RETIRED; Alert
  beats Focused: when both, focus shows only by brightening the
  title; Stale = dashed border), `Bar(segments, width)` (fill ▮
  U+25AE, empty ▯ U+25AF, NEVER █ — advance-width trap, handoff "Grid
  rules" #1), `StatusBar(mode, endpoint, facts)` (worst fact last).
  Golden-string unit tests, including a bar-width invariance test
  (rendered cell width identical at 0%, 50%, 100% fill) and the
  focus-vs-alert precedence.
- [ ] **Pattern kit, part 2: chip, eventLine, emptyState, confirm,
  keyHints.** `Chip` with the four independent axes (value on/off/
  read-only · selected · in-flight/pending amber · locked),
  `EventLine` (fixed 5-column gutter), `EmptyState` (sentence + key
  hint, never "(none)"), `Confirm` (Plain y/n vs TypeToConfirm —
  type-to-confirm ONLY when frames die), `KeyHints`
  (Global/Pane/Destructive; lowercase never destroys, destructive
  keys shifted). Golden tests per state.
- [ ] **Headless split.** Introduce the model/view seam the handoff's
  "Non-TTY / headless" section calls for, sized for phase A: the
  update loop's state becomes observable through one interface (a
  snapshot/event emitter the View consumes), and a new
  `-headless` flag runs the same model WITHOUT the bubbletea program,
  emitting one JSON line per state-changing event to stdout
  (journald-friendly). Scope discipline: same connection modes, same
  folding logic, no attach protocol, no socket — just the seam + JSON
  emission, so the TUI is provably one consumer of the model rather
  than entangled with it. Test: headless mode against fakescope
  emits parseable JSON lines for connect/status/event.
- [ ] **Restyle Now + Albums through the kit.** Replace hand-rolled
  borders/styles in the existing Now and Albums panes with
  tuikit.Pane/Bar/theme; keep information content identical except
  where the handoff's 2a/2b state language directly applies to data
  that already exists (e.g. disconnected → the pane renders Stale
  dashed with values marked stale, never blank/zero — scopetui
  already tracks misses). Grid rules #2-4: fixed-width cells sized to
  widest possible value +1 slack, truncate never wrap, bars in fixed
  columns.
- [ ] **Restyle Settings chips + Events + footer through the kit.**
  Settings chips move to tuikit.Chip preserving current behavior
  (shift-T toggle, in-flight amber until agent ack maps to the
  pending axis); Events uses EventLine; footer uses KeyHints;
  status line uses StatusBar. Rounded borders now fully gone.
- [ ] **80-col + NO_COLOR pass, and docs.** Verify (test where
  feasible) the layout degrades to single-pane at 80 cols per grid
  rule #5, and that NO_COLOR/non-TTY rendering still reads (marks
  carry state). Update `docs/dev/style.md` or add
  `docs/dev/tui-style.md` describing tuikit as the reality: theme
  tokens, helper inventory, glyph/grid rules, and which handoff
  screens remain future phases (list them explicitly so the next
  SPEC writer doesn't re-derive).

## Warts / traps

- scopetui is package main — the kit goes in `agent/internal/tuikit`
  (importable by fleetview later), NOT inside cmd/scopetui.
- Do not break `agent/cmd/scopetui` tests (fieldmode_test, campaign
  tests, condition_test) or the three modes; refactor incrementally —
  every iteration must gate green, so restyle pane-by-pane, not
  big-bang.
- Comment style: docs/dev/style.md (why, not what).
- The handoff HTML is a browser reference; you cannot render it —
  the README's tables are authoritative and transcribed above where
  needed.
- No new deps beyond what exists (bubbletea + lipgloss). No
  bubbles imports in phase A.

Finish: /workspace/PR.md — lead with before/after of the style-var
inventory (12 package vars → theme+kit), the headless seam contract,
and what phase B/C screens remain.
