# SPEC — osc-haptics-4-vocab: HapticEffect in profiles + runtime dispatch

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-2.

**Read first, all on main:** `CLAUDE.md`;
`docs/design/motion-and-feedback.md` §2.3.5 v2 fold 5 + loop 4;
the merged loop-3 module (`devices/haptics.rs`: HapticCommand,
presets with provenance, the rate floor, DeviceCommand::Haptic);
timing-engine v3 §2.2 (activator law) and config-profiles §14.6
(pulse law); the schema-2 gate in osc-config.

Loop 4 of 6. Sol's fold 5 verbatim: "a schema-2 `HapticEffect`
output action and `FeedbackEvent` result using existing activator
rising-edge law; delete the separate `haptic` and `tick` sink
concepts."

## Build

1. - [ ] **Schema-2 vocabulary** in osc-config: a binding's
   activator table admits `haptic = "click" | "soft" | "strong" |
   "ping" | { script = 1..16, side?, gain_db? } | { pulse = {
   side, on_us, off_us, repeat } }` — an OUTPUT ACTION attached to
   the binding, firing a `FeedbackEvent` on the activator's
   RESOLVED rising edge (the same §14.6 rising-edge law pulses
   use; no new sink machine, no timing semantics of its own).
   Validation: closed names; script 1..=16; gain −23..=24; pulse
   fields bounded (on/off ≤ 65535 µs, repeat ≤ 1000); schema-2
   gate rows + editor preservation per the standing law; the
   same-commit design-doc amendment rule applies (timing-engine §3
   list + config-profiles §3 rows quoted as diff hunks in PR.md).
2. - [ ] **step() output**: `FeedbackEvent(HapticSpec)` joins the
   step outputs (like RelativeEvents — a Vec, cleared per
   transaction, emitted only on resolved rising edges). Trace
   tests across the activator matrix: press/double/long/toggle/
   turbo — a haptic fires exactly when its slot resolves, never on
   raw edges, never on releases, cleared on transitions.
3. - [ ] **Daemon dispatch**: the controller loop converts
   FeedbackEvents to `DeviceCommand::Haptic` through loop 3's
   surface (rate floor already enforced there). Non-triton
   transports: the Unsupported error is logged once per profile
   activation, not per event. Run-loop wiring guard: a FakeTransport
   test proving a bound haptic on a synthetic press reaches
   `write_output` — the assembled path.
4. - [ ] All prior suites green; preview tour untouched (editor UI
   is loop 5 — the parser/preservation side must round-trip files
   containing haptic keys byte-for-byte even though no UI edits
   them yet, tested).

## Warts / traps

- No `tick` key, no separate sink — zones/rings get haptics in a
  later amendment via the same HapticEffect-on-binding law.
- No new crates. PR.md to /workspace/PR.md. Never `git add -A`.

## Finish — PR.md
Vocabulary table + validation rows; the two design diff hunks; trace
audit; the wiring-guard test name; untested-here.
