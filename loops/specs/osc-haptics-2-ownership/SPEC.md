# SPEC — osc-haptics-2-ownership: triton USB ownership lifecycle (rusb)

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-2.

**Read first, all on main:** `CLAUDE.md`;
`docs/design/motion-and-feedback.md` **§2.3.4** (the verified
protocol) + **§2.3.5 v2** fold items 2, 3, 4 and the loop-2
description; the working reference
`tests/fixtures/hw/haptic3-working-reference.py` (the exact claim/
config/keepalive sequence); the merged loop-1 transport seam
(`devices/transport.rs`) — you add a `RusbTransport` behind it;
`overlay-and-services.md` §4 (yield-to-Steam) — loop 2 makes PARK
release the USB claim.

Loop 2 of 6. Introduces `rusb`. **NO haptic vocabulary, NO profile
changes** — this loop is purely: own interface 2 correctly, hold
the controller out of lizard, hand it back to Steam cleanly. The
haptic OUTPUT bytes come in loop 3; here interrupt-OUT is exercised
only by the keepalive.

## Build

1. - [ ] **`RusbTransport`** behind the loop-1 seam, for the triton
   (PID 0x1304, Linux) ONLY — SC-2015/others keep `HidapiTransport`.
   Claim interface 2 (auto-detach kernel driver), interrupt-IN for
   input (0x42 → RawState, parity with loop 1's test), interrupt-OUT
   for the keepalive, control transfer (0x21/0x09/wValue 0x0301/
   wIndex 2) for the config. Partial-acquisition unwind on any
   claim/config failure (release what was claimed, restore kernel
   driver), all table-tested against a fake rusb layer.
2. - [ ] **Lizard session lifecycle** (fold 3): send §2.3.4's
   config on acquire; a **monotonic keepalive deadline** driven by
   the §1 tick scheduler (NOT the 300-turn `active_refresh_state`)
   guaranteeing an output report inside the 8 s watchdog even when
   input is quiet; on graceful exit send stop + release + rebind
   kernel driver; a crash-recovery note (the controller returns to
   lizard on its own watchdog — acceptable, documented).
3. - [ ] **USB-aware PARK** (fold 2): when yield-to-Steam parks,
   RELEASE the interface (Steam needs it); reacquire on unpark with
   the full claim/config sequence. Every disconnect/replace/exit
   transition in the §4 matrix re-expressed for USB ownership,
   table-tested.
4. - [ ] **Shared exclusion with `osc-explore`** (fold 4): both
   want interface 2 via libusb; the daemon-holds-device refusal the
   harness relies on must still hold (a claimed interface → explore
   refuses by name). The udev rule for non-root access is committed
   and documented; a non-root acceptance path is stated in PR.md.

## Warts / traps

- Sandbox has no hardware: the gate is fake-transport transition
  tables (claim/config/keepalive/PARK/reacquire/disconnect/two
  controllers) + the 0x42 parity. Real claim/rebind/Steam-handoff
  are a HARDWARE gate — PR.md states the founder acceptance runbook
  (the daemon should hold gamepad mode: controller stops acting as
  a mouse when the daemon runs; Steam still claims it on launch).
- `rusb` is the one new crate (founder-approved, §2.3.5). Justify
  in PR.md; no others.
- Keep every existing device working through the seam.
- PR.md to /workspace/PR.md. Never `git add -A`.

## Finish — PR.md
The RusbTransport + unwind; the keepalive-deadline design; the USB
PARK matrix; the explore exclusion + udev rule; the FOUNDER
HARDWARE RUNBOOK; untested-here (everything hardware).
