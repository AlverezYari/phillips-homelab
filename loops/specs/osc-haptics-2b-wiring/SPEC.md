# SPEC — osc-haptics-2b-wiring: actually select RusbTransport for the triton (fix loop)

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-2.

**The defect (conductor-found, post-merge of osc-haptics-2 / PR
#38, confirmed on hardware):** `RusbTransport` and its lifecycle
all landed and unit-test green, but the LIVE daemon device-connect
path (`devices/mod.rs`) never constructs it — it still opens the
triton through `HidapiTransport`. Result: no libusb claim, no
lizard-off, controller stays in mouse mode. The gate passed because
loop 2's tests exercised `RusbTransport` in isolation + the 0x42
parity; nothing asserted the daemon SELECTS it for a 0x1304 device.
Read `docs/design/motion-and-feedback.md` §2.3.4/§2.3.5 and the
osc-haptics-2 PR for the intended wiring.

## Build

1. - [ ] **Transport selection**: the device-connect path chooses
   the transport by device + platform — Linux + PID **0x1304** →
   `RusbTransport` (claim iface 2, config, keepalive per loop 2);
   every other device / platform → `HidapiTransport` unchanged.
   The selection lives in ONE factory function so it is testable.
2. - [ ] **The selection guard test** (the anti-recurrence): a test
   asserting the factory returns the rusb-backed transport for a
   0x1304 descriptor on Linux and the hidapi one otherwise — so a
   future refactor that drops the wiring fails the gate. This is
   the test class both this miss and the manifest-v4 miss lacked.
3. - [ ] **Graceful fallback**: if the rusb claim/config fails at
   runtime (no udev rule, permissions, Steam already holding it),
   the daemon logs a NAMED error and — where possible — falls back
   to `HidapiTransport` so the controller still works as a gamepad
   via hidapi (mapper unaffected), rather than dropping the device.
   The fallback path is table-tested against a failing fake rusb.
4. - [ ] All prior suites green; the 0x42 parity holds through the
   real selection path.

## Warts / traps

- Do NOT change RusbTransport's internals (loop 2's lifecycle is
  reviewed) — this loop is purely the selection wiring + guard +
  fallback.
- Sandbox can't verify the real claim; PR.md restates loop 2's
  founder hardware runbook (mouse-mode-stops etc.) as the
  acceptance, now that the wiring exists to make it testable.
- No new crates. PR.md to /workspace/PR.md.

## Finish — PR.md
The selection factory + guard test; the fallback behavior + test;
confirmation the wiring gap is closed; the founder runbook restated;
untested-here.
