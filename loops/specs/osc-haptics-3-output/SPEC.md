# SPEC — osc-haptics-3-output: typed haptic commands through the live transport

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-2.

**Read first, all on main:** `CLAUDE.md`;
`docs/design/motion-and-feedback.md` §2.3.4 (protocol law),
§2.3.5 v2 (loop 3 of the phased plan), §2.3.6 (transport verified
closed — the RusbTransport/keepalive path is LIVE and proven on
hardware; founder confirmed side attribution 2026-08-19, backed by
sc2-research's side enum and the usbmon capture).

Loop 3 of 6. **No profile/schema changes** (loop 4). This loop
gives the daemon a typed haptic command surface, callable by tests
and by loop 4's dispatch later.

## Build

1. - [ ] **Typed commands** in the daemon (new module, e.g.
   `haptics.rs`): `HapticCommand::Pulse { side, on_us, off_us,
   repeat }`, `::Script { side, script_id, gain_db }`, `::Rumble
   { intensity, left, right, left_gain, right_gain }`,
   `::StopAll { side }` — encoding EXACTLY the §2.3.4 output
   report frames (0x81/0x85/0x80/0x82), with the documented enums:
   side 0=TP_R 1=TP_L 2=TP_BOTH 3=INT_L 4=INT_R 5=INT_BOTH,
   gain_db i8 clamped −23..24, script_id 0x01..0x10. Frame
   encoding is pure + table-tested against the §2.3.4 byte layouts
   and the usbmon fixture's captured frames (byte-equality tests
   for the ping `85 05 0c 00` and the click `81 01 9001 0000
   0100`).
2. - [ ] **Send path**: commands go out via the transport seam's
   `write_output` (the same path the keepalive proved on
   hardware). On `HidapiTransport` devices (non-triton), commands
   return a typed Unsupported error — never a silent no-op, never
   a panic.
3. - [ ] **Named presets** (the vocabulary loop 4 will bind):
   `click`, `soft`, `strong`, `ping` — exact frames documented in
   the module with provenance comments (capture/doc-cited). A
   preset → HapticCommand mapping table, tested.
4. - [ ] **Wiring guard** (the lesson of this arc, now standard):
   a run-loop-level test proving a dispatched HapticCommand
   actually reaches the FakeTransport's output — the assembled
   path, not just the encoder.

## Warts / traps

- Rate limiting: a simple floor (≥20 ms between haptic sends per
  controller, keepalive excluded) so a future buggy caller can't
  flood the interrupt pipe; table-tested.
- No new crates. PR.md to /workspace/PR.md.

## Finish — PR.md
The command/frame table with provenance; preset list; the wiring
guard test name; rate-limit law; untested-here.
