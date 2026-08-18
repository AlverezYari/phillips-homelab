# SPEC — osc-config-model: the data-driven mode program (profiles stage 1)

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-1.

**Read first, all on main:** `CLAUDE.md`;
`docs/design/config-profiles.md` **v3** — law for this loop,
specifically §1 (mode program + `step` signature + field-combination
rules + equivalence gate), §2 (closed vocabulary, serialized
spellings), §3 (identity + validation types), §8 (workspace topology,
additive gate), §11 stage 1 (dependency scope); and
`docs/design/input-modes.md` (settled law the new model must express).
The two review rounds that shaped v3 are on branches
`loop/sol-review-osc-profiles` and `loop/sol-review-osc-profiles-2` —
their failure scenarios are your test cases.

## Why

Per-game profiles need the three shipped modes to become *data* in a
model users can also write. Two review rounds established the traps:
the mode behavior is NOT just the desired-outputs table (stateful
behaviors: stick-arrows, zone-dpad, motion anchors, guide-tap), the
vocabulary must be closed and exhaustive (round 2 caught a missing
D-pad!), and chords must flow through the interpreter's return value.
This stage converts the architecture; it must change **zero runtime
behavior**.

## Build, in order

1. - [ ] **Workspace conversion**: three-crate layout per §8
   (`osc-config` new; daemon stays `open-steam-controller`;
   `osc-editor` is NOT created yet — two members for now, topology
   ready for the third). Makefile gains `--workspace --all-targets`
   **additively** — `--release --locked`, `--locked` test, clippy
   `-D warnings`, `fmt --check` all retained. Update `CLAUDE.md`'s
   gate/map wording in the same commit so docs stay true.
2. - [ ] **`osc-config` types**: §2 enums with exact serialized
   spellings (serde derives; serde+toml are `osc-config` deps only),
   §1 `Mode`/program types + field-combination validation, §3
   profile-ID rules + the validation table as typed
   `Diagnostic { profile_id, severity, code, mode, source, message }`
   results. Unit tests exercise every §3 table row and every §1
   combination rule. NO file I/O anywhere in this stage.
3. - [ ] **Red-first equivalence suite**: the compiled-in
   Gamepad/Desktop/Hybrid `Mode` values expressed in the new model,
   with tests asserting the §1 equivalence gate list — all three
   defaults' full tables including D-pad rows, relative motion,
   hysteresis sequences, guide-tap eligibility, Nintendo swap
   output-side rule, alias refcounting, Hybrid's inherited rows —
   written against the NEW interpreter API before it exists (red),
   alongside the existing suite (which must keep passing throughout).
4. - [ ] **The interpreter**: implement §1 `step` exactly —
   `(RawState, ActiveSnapshot, Selection, MapperMemory) ->
   (DesiredOutputs, Vec<RelativeEvent>, Vec<DaemonCommand>,
   Selection', MapperMemory')` — chords resolved first inside `step`,
   Steam+X updating `Selection'` with interpretation running under it
   in the same call, Steam+Y/Steam+A returned as `DaemonCommand`s.
   `MapperMemory` owns all cross-report state, typed per behavior;
   every behavior machine works for ANY mode that declares the
   behavior. Custom-mode tests per §1 (silent-gamepad key mode,
   arrows stick in a custom mode, zone-dpad in a custom mode).
5. - [ ] **Cutover**: `steam_controller.rs`/`mod.rs` drive `step`;
   `InputMode`, `compute_gamepad/desktop/hybrid`, and every
   mode-enum branch deleted; the tray's mode submenu now lists the
   active (compiled-in) profile's mode names via the existing
   descriptor (still three static names — dynamic tray is stage 2).
   `ActiveSnapshot` for now wraps only the compiled-in default
   profile — the type exists, the ConfigStore does not.

## Warts / traps

- **Zero behavior change is the contract.** The pre-existing test
  suite passes unchanged; any test edit beyond imports/namespacing is
  a red flag to justify line-by-line in PR.md.
- Dependency scope per §11: serde/toml in `osc-config` only; daemon
  runtime does no file I/O, no D-Bus changes, no new daemon deps.
- No hardware in the sandbox; pure tests only. "Verified" may not
  appear in PR.md for anything you could not execute.
- Windows must keep compiling blind: the workspace conversion and
  cutover touch shared files — keep `cfg` symmetry, extend
  windows-policy tests to the new API (effective-Gamepad forcing now
  lives in `Selection` resolution).
- Never `git add -A`.

## Finish — PR.md must contain

- The equivalence audit: every default-mode table row old-vs-new,
  divergences called out (there must be none).
- The custom-mode test list, named individually.
- The workspace layout tree and the exact Makefile diff.
- Untested-here honesty section.
