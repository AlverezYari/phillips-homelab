# SPEC — osc-steam-tap-home: Steam button = Guide tap on un-chorded release

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-1.

**Read first, both on main:** `CLAUDE.md`, and
`docs/design/input-modes.md` §Chords — specifically the "Steam tap =
Guide (founder ruling)" paragraph, which is law and defines this loop
completely. The mode system it amends landed in PR #1 (branch
`loop/osc-mode-system`, merged); `src/devices/mapper.rs` is the pure
transaction core you are extending.

## Why

Founder ruling: pressing the Steam button alone should act like the
Xbox Guide button, the way real Steam behaves — emulator frontends and
overlays key off it. PR #1 made Steam a pure chord modifier with no
output; that was flagged in its PR.md as a design tension and the
ruling resolves it: silent while held, Guide tap on un-chorded release.

## Build

1. - [ ] **Red-first tests** in `mapper.rs`, then the implementation:
   - un-chorded Steam press+release in Gamepad emits Home press in the
     release transaction and Home release in the next transaction —
     exactly one pulse, both edges;
   - same in Hybrid;
   - any chord fired during the hold (test Steam+Y, Steam+A, Steam+X)
     → no Home pulse at all;
   - Desktop mode: un-chorded tap emits nothing;
   - Menu held (momentary Desktop) at Steam-release time: effective
     mode is Desktop → no pulse;
   - `reset_outputs` between the pulse's press and release
     transactions releases Home like any held output — no stuck Guide;
   - two consecutive un-chorded taps produce two clean pulses.
2. - [ ] The pulse state lives beside the mapper's other cross-report
   state (like the pad-zone machine), NOT as a timer or thread; the
   design's "press in release transaction, release in next
   transaction" is the whole mechanism.

## Warts / traps

- Touch nothing outside `mapper.rs` (+ its tests) unless the pulse
  state genuinely needs a field beside its siblings — the I/O glue
  already forwards whatever the mapper emits.
- Do not add Home to Desktop's table, do not touch the deviations
  table, do not revisit PR #1 decisions.
- `Home` is an existing `ControllerInput` variant already registered in
  both backends — no backend changes.
- No hardware in the sandbox; pure tests only. "Verified" may not
  appear in PR.md for anything you could not execute.
- Never `git add -A`.

## Finish — PR.md must contain

- The test list, named individually, one line each on what it pins.
- A short "how the pulse interacts with chords/reset" paragraph a
  reviewer can check against the design paragraph.
- Untested-here honesty section (hardware behavior of the pulse width).

## Outcome (conductor note, post-loop)

Landed green in one effective iteration as
`loop-bot/OpenSteamController` PR #2, merged 2026-08-18. 8 new tests,
83 total; implementation confined to `mapper.rs` as fenced.
