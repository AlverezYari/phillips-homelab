# SPEC — osc-yield: yield-to-Steam arbitration (PRIORITY — founder hit the conflict live)

**2026-08-19 amendment — the USB-ownership world changes §4's
evidence model.** Since osc-haptics-2/2b/2d landed, the daemon OWNS
the triton's interface 2 via libusb: while we hold it, the puck's
hidraw nodes DO NOT EXIST, so the original "Steam holds a hidraw
fd" evidence can never occur. Founder repro: launching Steam while
the daemon held the device made Steam prompt to re-set-up the
controller — we fought it. The corrected evidence rule for the
triton: **a running Steam client process IS the yield trigger.**
Steam-launches → PARK immediately (release interface, rebind
kernel driver — loop 2's landed release path); Steam-exits →
reacquire. "Steam always wins the tie" (founder law). The §4.1/§4.2
machine below still governs states/cadence/force-hold; read
"evidence" as steam-process-exists for the USB-owned triton, with
the fd-based rule retained only for hidraw-transport devices. The
30 s baseline scan is the launch detector's upper latency bound;
tighten to 5 s ALWAYS (a /proc comm sweep is microseconds) so the
park happens before Steam's device probe in practice. State the
race honestly in PR.md: a park can still lose to Steam's first
probe by milliseconds; Steam recovers on its next enumeration.

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-2.

**Read first, all on main:** `CLAUDE.md`;
`docs/design/overlay-and-services.md` **v5 §4** — law with GO from
sol-review-osc-wave34 round 4. The §4.2 matrix is TOTAL by design:
every cell, including the explicit no-ops, is a test.

## Build, in order (red-first per item)

1. - [ ] **Observer traits**: `ProcessObserver` (steam-comm scan +
   per-pid fd → hidraw resolution) and `DeviceObserver` with real
   /proc + sysfs implementations and full fakes. Evidence law per
   §4.1 verbatim (comm == "steam", same uid, fd resolves to a
   hidraw node matching the claim predicate).
2. - [ ] **The state machine**: `HOLDING`/`PARKED`/
   `ACQUIRING(reason, not_before)`/`AWAY` + the force policy flag
   (persisted per controller in state.toml), the §4.2 matrix
   cell-for-cell, backoff ladder, post-park grace via not_before,
   PARKED-implies-evidence as an internal assertion.
3. - [ ] **Cadence wiring**: startup pre-open scan, FocusChanged
   hook, udev add/remove hooks, 5 s fast timer while steam exists,
   30 s baseline always, hidepid loud degradation.
4. - [ ] **Tray surface**: per-state lines ("yielded to Steam",
   "connecting", "controller busy", error with errno), the
   force-hold toggle, the §4.1 unavailable text.
5. - [ ] **Tests**: every matrix cell + the §4.3 named scenarios
   (evidence-flap, failed force acquisition, non-EBUSY errors,
   disconnect during force + flag surviving reconnect,
   persisted-force startup with evidence, event-less Steam start
   caught by baseline, replacement while HOLDING, two controllers
   independent) — all against the fakes with an injected clock.

## Warts / traps

- The machine must not perturb the mapper: parking releases the
  read loop cleanly mid-transaction (finish the transaction, then
  release) and reacquisition goes through the normal device-init
  path.
- No polling when no steam process exists except the 30 s baseline
  — a hot loop is a review rejection.
- Real-observer integration can't run in the sandbox; say so in
  PR.md (pure-machine tests are the gate) with a founder smoke
  runbook (launch Steam, watch tray park/reacquire).
- No new crates (udev is already a daemon dependency — verify in
  Cargo.lock before assuming; if absent, sysfs polling on the
  existing timers replaces udev hooks and PR.md says so).
- PR.md to /workspace/PR.md.

## Finish — PR.md
Matrix-coverage audit (cell → test name); founder smoke runbook;
cadence audit; untested-here.
