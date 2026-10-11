# SPEC — osc-haptics-2c-keepalive: wire the keepalive into the run loop + run-loop integration test

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-2.

**The defect (conductor-found on hardware, THIRD integration gap of
this arc):** `rusb_transport::keepalive_if_due()` exists and is
unit-tested, but the daemon's per-controller RUN LOOP never calls
it. So the lizard-off config is sent once at `acquire` (good for
~8s) and then the puck reverts to lizard mode — the controller
starts driving the mouse again. The two prior gaps (manifest-v4
selection, RusbTransport selection) were the SAME shape: a unit
built + green-tested but never invoked by the live loop, invisible
to the sandbox because no test exercises the assembled loop. Read
`docs/design/motion-and-feedback.md` §2.3.4/§2.3.5 and the
osc-haptics-2 PR.

## Build

1. - [ ] **Wire the keepalive**: the per-controller run loop arms
   `initial_keepalive_deadline` right after a successful triton
   `acquire`, and calls `keepalive_if_due(now_ms, deadline)` every
   loop turn using the daemon's monotonic clock, re-arming the
   returned deadline — guaranteeing an output report inside the
   watchdog even when input is quiet (the read timeout must not
   exceed the keepalive period, or a silent controller starves the
   keepalive — check and fix that interaction).
2. - [ ] **Run-loop integration test** (the anti-recurrence for the
   WHOLE class): a test that assembles the actual per-controller
   loop (not the transport unit alone) with a `FakeTransport`/fake
   rusb backend and a controllable clock, drives it across a quiet
   period longer than the keepalive, and asserts the keepalive
   output report WAS written at the expected cadence. This is the
   test shape all three gaps lacked — it exercises the wiring, not
   just the unit. Where practical, add the same assertion style for
   the transport-selection wiring (0x1304 → rusb path is actually
   taken by the loop, not just returned by the factory).
3. - [ ] **Graceful degrade**: if a keepalive write fails at
   runtime (Steam took the device, unplug), the loop follows the
   existing disconnect/PARK path, not a panic or busy-spin.
4. - [ ] All prior suites green.

## Warts / traps

- Do NOT change the keepalive frame or period (loop 2 reviewed
  them) — only wire the call and test it.
- Sandbox can't prove the real 8s hardware watchdog; the run-loop
  integration test with a fake clock is the gate, and PR.md states
  the founder confirms "controller stops driving the mouse and
  STAYS stopped past 8s" as final acceptance.
- No new crates. PR.md to /workspace/PR.md.

## Finish — PR.md
The run-loop keepalive wiring; the run-loop integration test (name
it, explain how it would have caught all three gaps); the
read-timeout/keepalive interaction; untested-here (real watchdog).
