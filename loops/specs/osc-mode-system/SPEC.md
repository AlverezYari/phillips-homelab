# SPEC — osc-mode-system: Gamepad / Desktop / Hybrid input modes

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-1 (cargo + clippy + rustfmt + libudev/libdbus headers).

**Read first, both on main:** `CLAUDE.md` (sandbox constraints — no
hardware, no /dev/uinput, Windows must keep compiling blind) and
`docs/design/input-modes.md` **v2**, which is **law** for this loop:
the mapper-transaction/reconciliation model, mode semantics, both
mapping tables, the deviations table, chord rules, the pad-zone state
machine, `reset_outputs`, and the scope fences all live there. It has
already survived an adversarial design review (REVIEW.md on branch
`loop/sol-review-osc-modes` — read it; the design's §Mapper
transaction is the answer to its findings 1–3, and the review's
concrete failure sequences are your test cases). This spec sequences
the work; the design doc defines it. Where they appear to conflict,
say so in PR.md rather than silently picking.

## Why

The app has one real layout plus a half-finished momentary "alt mode".
Steam Input on the same controller ships a polished desktop layer and
per-layer paddle bindings; users drop to this app for non-Steam games
and lose all of it. Two real bugs die as side effects of the design:
chords match *mapped* outputs today, so Steam+Y power-off is dead
while alt mode is active; and mode/overlay changes can strand held
outputs (hold RT, tap Menu → phantom 80% throttle, forever).

## Build, in order

1. - [ ] **The mapper core, red-first.** Implement `RawState` parsing
   and the pure boundary from the design:
   `(RawState, ModeState, ConsumedSources) -> DesiredOutputs` and
   `diff(EmittedOutputs, DesiredOutputs) -> Vec<ControllerInput>`.
   Before wiring anything, commit red table-driven tests asserting the
   FULL Gamepad table (pins current behavior) plus Desktop and Hybrid
   tables, plus the review's failure sequences: RT-held-across-mode-
   change neutralizes; B+Start alias keeps Esc; stale L5 cannot
   release X's Meta; Menu+A in one report maps atomically.
2. - [ ] **`InputMode` plumbing.** Enum with `Display` +
   `TryFrom<u8>`, latch in `DeviceProperties`,
   `DeviceCommand::{SetInputMode, InputModeCycle}` routed through the
   mapper transaction (commands emit their cleanup deltas in the same
   transaction — `try_apply` alone must not mutate the mode). HID
   report first, then pending command, per the design's ordering.
3. - [ ] **New `ControllerInput` variants** (Space/Tab/PageUp/PageDown
   keys): registered at uinput device creation AND mapped in the Linux
   emit path — both sites, same commit; `EV_REP` capability on the
   uinput keyboard device; explicit no-op arms in `windows.rs`.
4. - [ ] **Chords, modifier-first.** Raw-bitmap detection, rising-edge-
   while-Steam-held, consumed-until-release sources feeding
   `DesiredOutputs`. Regression tests: Steam+Y fires identically in
   all three modes and while Menu is held; X held before Steam does
   NOT fire the chord; consumed X releases whatever it was bound to
   (gamepad X, Meta, or Nintendo-swapped Y) exactly once.
5. - [ ] **Desktop mode** to the parity table + deviations table,
   including trigger clicks, both sticks, both pads; stick arrows via
   hysteresis crossings with OS-delegated repeat (no timers, no
   `Instant::now()` in mapping logic).
6. - [ ] **`reset_outputs`** on wireless disconnect, `clear_state`,
   read-loop exit, and virtual-device replacement, per the design;
   fake-output-sink tests prove releases/neutrals precede device
   teardown and that a recreated device starts from empty
   `EmittedOutputs`.
7. - [ ] **Hybrid mode**: right pad mouse+click, paddles
   L3/R3/Shift/Ctrl, left-pad zone d-pad implementing the design's
   transition table exactly — test every row, plus the review's
   loss/regain-while-clicked and stale-coordinate cases.
8. - [ ] **Windows policy**: effective mode forced to Gamepad, mode
   control disabled in that tray, pure tests that Desktop/Hybrid/Menu
   requests produce the exact Gamepad stream.
9. - [ ] **Tray**: labelled-choice descriptor (value+label pairs) for
   "Input mode" with checked `TryFrom` at the boundary, wired in BOTH
   `status_tray.rs` and `status_tray_not_linux.rs`.

## Warts / traps

- **No hardware exists in your world.** Anything needing a HID device,
  uinput, or D-Bus cannot run here; if a test needs one, the design of
  that code is wrong — purify it. The binary is validated on Casey's
  machine after merge, not by you. The word "verified" may not appear
  in PR.md for anything you could not execute.
- **Do not touch**: HID packet parsing offsets/constants, lizard-mode
  keepalive, battery/status handling, trackpad speed constants;
  `multi_threading.rs` and `main.rs` only as far as command plumbing
  strictly needs.
- **Nintendo layout** applies to gamepad A/B/X/Y outputs only, inside
  desired-state computation. Do not re-implement it in mode tables; do
  add the test that Desktop's A→Enter is NOT swapped.
- Relative mouse/wheel motion is never tracked in
  `DesiredOutputs`/`EmittedOutputs` — emit-and-forget.
- Adding a crate is a founder decision. So is any deviation from the
  tables beyond the deviations list.
- Never `git add -A`.

## Finish — PR.md must contain

- The **mapping audit table**: every physical input × every mode →
  emitted output, side by side with the design tables, divergences
  called out (there should be none).
- The review-failure-sequence tests, named individually, with a
  one-line statement of what each pins.
- Founder-verification checklist for on-hardware smoke: Steam+X cycle
  visible in tray; Steam+Y in each mode and under Menu-hold; the
  phantom-RT sequence; B+Start alias in a key monitor; left-pad zones
  in a gamepad tester; Desktop typing/scroll/paddles; wireless
  power-off mid-hold releases everything.
- Anything you could not test in-sandbox, listed honestly under
  "Untested here".
