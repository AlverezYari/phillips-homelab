# SPEC — osc-haptics-1-discovery: physical device discovery + transport backend seam

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-2.

**Read first, all on main:** `CLAUDE.md`;
`docs/design/motion-and-feedback.md` **§2.3.5 v2** (phased plan) and
its fold item 1; the `sol-review-osc-haptics` review preserved at
`loops/specs/sol-review-osc-haptics/REVIEW-round1.md` (its P0 on the
discovery/hotplug model is your scope). Landed code:
`devices/mod.rs` (the `HidApi` enumeration, `step_by(3)` "every
third device", the interface-count hotplug in the main loop, the
per-device factory), and the `RawState` parse path.

This is loop 1 of 6. **NO haptics, NO libusb, NO profile changes** —
this loop only makes the device layer correct and fakeable so the
later USB-ownership loop can slot in cleanly.

## Build

1. - [ ] **Transport seam**: a trait (e.g. `ControllerTransport`)
   abstracting the byte source/sink the device layer uses —
   `read_input(&mut buf) -> n`, `write_output(&[u8])`,
   `send_feature(&[u8])`. The hidapi path becomes ONE impl
   (`HidapiTransport`); add a `FakeTransport` (scripted input
   frames, recorded outputs) for tests. No behavior change to the
   hidapi impl — same reads/writes as today.
2. - [ ] **Physical-device discovery**: group enumerated HID nodes
   by **shared USB parent device** (the same law `osc-explore`'s
   `group.rs` already uses — reuse or mirror it), replacing
   `step_by(3)`. Each physical controller = one group; the factory
   binds per group. Multi-controller and no-serial cases correct.
3. - [ ] **Hotplug identity**: the main loop must key controllers
   by stable physical identity (USB parent / serial), NOT by
   interface COUNT — the P0 fix. A count change must not tear down
   unrelated controllers. Table-test the hotplug transitions
   (add/remove/replace, two controllers) against fakes.
4. - [ ] **`0x42` parity**: a test proving `RawState` parsed from a
   `FakeTransport` replay of the committed IMU fixture
   (`tests/fixtures/hw/osc-imu-capture.v1.jsonl`, report id 0x42,
   54 bytes) equals the hidapi path's parse byte-for-byte — the
   guarantee the USB-ownership loop depends on.

## Warts / traps

- Scope FENCE: Linux triton (PID 0x1304) is where the USB port
  will land later, but THIS loop keeps all existing devices working
  through the seam unchanged — do not drop SC-2015 support.
- No new crates (rusb arrives in loop 2). No schema changes.
- All prior suites green; the mapper is untouched above the seam.
- PR.md to /workspace/PR.md. Never `git add -A`.

## Finish — PR.md
The seam trait + fake; the discovery/grouping change; the hotplug
identity fix with its trace tests; the 0x42 parity test; untested-here.
