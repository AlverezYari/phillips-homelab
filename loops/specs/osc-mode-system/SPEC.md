# SPEC — osc-mode-system: Gamepad / Desktop / Hybrid input modes

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-1 (cargo + clippy + rustfmt + libudev/libdbus headers).

**Read first, both on main:** `CLAUDE.md` (sandbox constraints — no
hardware, no /dev/uinput, Windows must keep compiling blind) and
`docs/design/input-modes.md`, which is **law** for this loop: mode
semantics, the Desktop parity table, the Hybrid table, chord rules,
transition hygiene, zone math, and the scope fences all live there.
This spec sequences the work; the design doc defines it. Where they
appear to conflict, say so in PR.md rather than silently picking.

## Why

The app has one real layout plus a half-finished momentary "alt mode".
Steam Input on the same controller ships a polished desktop layer and
per-layer paddle bindings; users drop to this app for non-Steam games
and lose all of it. The design doc turns that into three fixed modes.
Two real bugs die as side effects: chords currently match *mapped*
outputs, so Steam+Y power-off is dead while alt mode is active
(`parse_button_combinations` matching `ControllerInput::Y`); and mode
changes can strand held outputs (hold RT, tap Menu → phantom trigger).

## Build, in order

1. - [ ] **Red-first: the mapping test harness.** Extract per-mode
   button mapping into a pure function (mode, button, states) →
   ControllerInput, and write table-driven tests asserting the FULL
   Gamepad table (current behavior — this pins the refactor) plus the
   Desktop and Hybrid tables from the design doc. Desktop/Hybrid tests
   fail red at this point because only the plumbing exists. Commit the
   red tests before the green.
2. - [ ] **`InputMode` enum + plumbing.** In `DeviceProperties` beside
   `nintendo_layout`; `DeviceCommand::{SetInputMode, InputModeCycle}`
   handled in `try_apply`; effective-mode resolution (Menu-hold
   momentary Desktop overlay) per the design.
3. - [ ] **New `ControllerInput` variants** (Space/Tab/PageUp/PageDown
   keys): registered at uinput device creation AND mapped in the Linux
   emit path — both sites, same commit; explicit Ignore arms with a
   comment in `windows.rs`.
4. - [ ] **Chords to raw-Button level** per the design's "chords are
   pre-mode" section, including the swallow rule. Regression test: the
   Steam+Y power-off command fires identically in all three modes and
   while Menu is held.
5. - [ ] **Desktop mode** to the parity table, including triggers,
   sticks, trackpads. The analog-trigger and joystick handlers gain
   mode arms; trackpad wheel/mouse behavior per table.
6. - [ ] **Transition hygiene.** The held-output tracker: every press
   recorded, every effective-mode change releases the old mode's
   still-held outputs first. Tests: the phantom-RT sequence from the
   design; Menu tapped while a Desktop key held; chord swallow does
   not double-release.
7. - [ ] **Hybrid mode**: right pad mouse+click, left pad click-gated
   4-zone d-pad (pure `dpad_zone` + the remembered-direction state
   machine, tested exhaustively over the sequence space the design
   enumerates), paddles L4/R4→stick clicks, L5/R5→Shift/Ctrl.
8. - [ ] **Tray**: "Input mode" per-controller submenu via the existing
   Int-with-options `PropertyDescriptorWrapper` → `SetInputMode`.

## Warts / traps

- **No hardware exists in your world.** Anything needing a HID device,
  uinput, or D-Bus cannot run here; if a test needs one, the design of
  that code is wrong — purify it. The binary is validated on Casey's
  machine after merge, not by you. The word "verified" may not appear
  in PR.md for anything you could not execute.
- **Do not touch**: HID packet parsing offsets/constants, lizard-mode
  keepalive, battery/status handling, `multi_threading.rs` beyond what
  command plumbing strictly needs, trackpad speed constants.
- **Nintendo layout composes above modes** (the A/B–X/Y swap in
  `passive_refresh_state`). Do not re-implement it inside mode tables;
  do add the test that Desktop's A→Enter is NOT swapped by Nintendo
  mode (keys are not gamepad A/B).
- Left-stick arrows in Desktop: implement per the design doc's
  resolution of the repeat question (post-Sol). If the doc still
  leaves repeat timing ambiguous when you read it, file a decision —
  do not invent a timer thread.
- Adding a crate is a founder decision. So is any deviation from the
  parity table.
- Never `git add -A`.

## Finish — PR.md must contain

- The **mapping audit table**: every physical input × every mode →
  emitted output, side by side with the design table, divergences
  called out (there should be none).
- The chord-in-every-mode test evidence and the transition-hygiene
  test list, named individually.
- Founder-verification checklist for on-hardware smoke: the exact
  manual sequences Casey should run (Steam+X cycle visible in tray;
  Steam+Y in each mode; phantom-RT sequence; left-pad zones in a
  gamepad tester; Desktop typing/scroll/paddles).
- Anything you could not test in-sandbox, listed honestly under
  "Untested here".
