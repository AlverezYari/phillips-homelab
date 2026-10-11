# SPEC — osc-haptics-2d-keepalive-starve: keepalive starves under read backlog

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-2.

**The defect (conductor-diagnosed from real USB traces on hardware):**
the keepalive is wired (loop 2c) but NEVER FIRES in practice. An
instrumented run on the triton showed: 3 config `write_control`
Ok(64), then a continuous flood of `read_interrupt` ep=0x83 Ok(54)
(the controller streams 0x42 gamepad reports back-to-back), and
**zero `write_interrupt` (keepalive) in 10 seconds.** The per-turn
read drains reports as fast as they arrive, so the run loop never
returns to the `keepalive_if_due` call site — the keepalive is
starved by the read backlog. The working reference
(`tests/fixtures/hw/haptic3-working-reference.py`) avoids this by
running its 200 ms keepalive on a SEPARATE THREAD, independent of
the read loop. Result: lizard-off is never re-asserted, the puck
keeps driving the mouse, and (later) haptics won't hold.

## Build

1. - [ ] **Guarantee the keepalive fires on schedule regardless of
   input volume.** Options (pick the cleanest for the landed run
   loop, justify in PR.md): (a) call `keepalive_if_due(now_ms)`
   inside the read-drain path — before/after each individual
   read — not only once per outer loop turn; or (b) bound reads
   per turn so control returns to the keepalive site well within
   `KEEPALIVE_INTERVAL_MS`; or (c) a dedicated keepalive cadence
   decoupled from the read loop. The invariant: with a transport
   that ALWAYS returns a report immediately (never blocks), a
   keepalive output report is still written at least every
   `KEEPALIVE_INTERVAL_MS` of monotonic time.
2. - [ ] **The regression test (the real one this needs):** a
   run-loop test with a `FakeTransport` whose `read_input` ALWAYS
   returns a report immediately (models the 0x83 flood) and a
   controllable clock; advance time past several keepalive
   intervals and assert keepalive frames WERE written at the
   expected cadence. This is the exact scenario the hardware hit
   and the loop-2c test missed (its fake must have let reads idle).
3. - [ ] Confirm the monotonic clock source feeding `now_ms` is
   real wall-time-derived (not a per-turn counter that the flood
   also starves) — the trace showed time must advance for the
   deadline to trip.
4. - [ ] All prior suites green; do not change the keepalive frame,
   period, or the config.

## Warts / traps

- The fix is in the run-loop cadence, NOT rusb_transport's
  primitives (those are correct — the trace proved config + read
  work).
- Sandbox proves the cadence via the flood-fake + fake clock; the
  hardware acceptance (mouse actually stops and STAYS stopped) the
  conductor verifies via an instrumented trace showing periodic
  write_interrupt, then the founder confirms.
- No new crates. PR.md to /workspace/PR.md.

## Finish — PR.md
The cadence fix + why that option; the flood regression test
(name it); the clock-source confirmation; untested-here.
