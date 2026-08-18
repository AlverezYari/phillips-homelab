# SPEC — sol-review-osc-modes: adversarial review of the input-modes design (REVIEW ONLY)

Repo: `loop-bot/OpenSteamController`. Gate: `test -s /workspace/repo/REVIEW.md`.
Engine: codex (Sol). This is a DESIGN review — adversarial, before a
build loop implements it. You change NOTHING except creating
`REVIEW.md` at the repo root. Any other file modification is a spec
violation.

## What to review

`docs/design/input-modes.md` on `main` — a three-mode input design
(Gamepad / Desktop / Hybrid) for a Steam Controller userland driver —
against the code it must land in: `src/devices/steam_controller.rs`
(mapping tables, chord parsing, trackpad state), `src/devices/mod.rs`
(DeviceProperties / DeviceCommand / tray property descriptors,
`passive_refresh_state`'s Nintendo-layout swap), and
`src/virtual_controller/{mod,linux,windows}.rs` (output vocabulary and
backends). Read `CLAUDE.md` for the sandbox constraints the
implementation will live under.

## Ground truth for the Desktop table

The design's Desktop mode claims parity with Valve's shipped desktop
layer. This is the raw extract from Casey's Steam install
(`controller_base/desktop_neptune.vdf`, active groups; triton chords in
`controller_base/chord_triton.vdf`). Verify the design's table is a
faithful transcription — flag every divergence not explicitly marked as
a deliberate deviation:

```
button_diamond (four_buttons): A=RETURN B=ESCAPE X=SHOW_KEYBOARD Y=SPACE
dpad (dpad): arrows (UP/DOWN/LEFT/RIGHT_ARROW)
left stick (dpad mode): arrow keys
right stick (joystick_mouse): mouse; click=LEFT mouse
left_trigger (trigger, edge): RIGHT mouse
right_trigger (trigger, edge): LEFT mouse
right_trackpad (absolute_mouse): mouse; click=LEFT mouse
left_trackpad (scrollwheel): scroll_clockwise=SCROLL_DOWN,
  counterclockwise=SCROLL_UP; click=MIDDLE mouse
switches: button_escape=ESCAPE (+CHANGE_PRESET), button_menu=TAB,
  back_left=LEFT_WINDOWS, back_left_upper=LEFT_SHIFT,
  back_right=PAGE_DOWN, back_right_upper=PAGE_UP,
  button_capture=system_key_1
chord_triton (Steam held): B=quit_application X=SHOW_KEYBOARD
  Y=controller_poweroff, right pad=absolute_mouse+LEFT,
  dpad=volume/TAB/RETURN/ESCAPE chords
```

## The brief — try to break it

This design will be implemented by a build loop with no hardware and no
human watching the first draft. Whatever the design underspecifies, the
loop will guess. Hunt for:

- **Stuck-input holes in the transition model.** The design's held-set
  release rule: enumerate concrete sequences it still gets wrong.
  Menu pressed while Steam+X chord half-held? Trigger analog nonzero
  across a latch? Nintendo layout toggled (Steam+A) while Desktop mode
  holds EnterKey via physical A? Pad clicked during a transition, then
  released in the old mode's mapping? Wireless drop / `clear_state()`
  mid-hold — does the virtual device see releases?
- **Chord semantics.** Chords move to raw-Button level. Does the
  swallow rule (emit releases so the game never sees X) actually work
  with the held-set tracker, or does it double-release? What does the
  physical X press emit in Desktop mode where X maps to Meta — does the
  chord swallow keys as well as gamepad buttons?
- **Mode-shift interactions.** Menu-hold = momentary Desktop over any
  latched mode. What happens on Steam+X *while* Menu is held? Tray
  `SetInputMode` racing the chord (different threads)? Is "effective
  mode" evaluated consistently for buttons, triggers, sticks, AND
  trackpads in the same report packet?
- **The left-pad zone spec.** Click-gated, remembered direction,
  no re-evaluation while held: any input sequence with an undefined
  outcome? (Click with no touch sample yet; touch lost and regained
  while clicked; force/position of (0,0) sentinel packets.)
- **Left-stick arrow keys.** The design wants deflection→arrow-keys
  with hysteresis and key repeat. Key repeat needs time; the mapping
  layer is a pure function of HID packets today. Is the proposed
  350ms/40ms repeat implementable without threading a clock through
  the parser — or should the design delegate repeat to the OS
  (uinput EV_REP) or drop it? This smells like the design's weakest
  load-bearing claim; judge it.
- **Backend reality.** New key variants (Space/Tab/PageUp/PageDown):
  anything in `linux.rs`'s two-site registration/emit pattern the
  design fails to demand? Windows: modes silently degrade — is
  "degrade to gamepad everywhere" actually specified tightly enough to
  compile AND behave (Desktop mode on Windows = what, exactly)?
- **Scope fence integrity.** Anything the design implies but fences
  out (per-game configs, gyro) that will force the build loop to
  either violate a fence or file a decision it shouldn't need.

## Output

Create `REVIEW.md` at the repo root: ranked findings (most-severe
first), each with the design-doc section or file:line, why it's a
problem, a concrete failure sequence, and a suggested design edit.
Distinguish genuine correctness/safety-of-input problems from taste.
If the design is sound, say so plainly — do not invent problems to
seem thorough. End with GO / NO-GO for handing it to a build loop.
