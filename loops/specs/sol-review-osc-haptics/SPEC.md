# SPEC — sol-review-osc-haptics: review the haptic integration architecture (REVIEW ONLY)

Repo: `loop-bot/OpenSteamController`. Gate: `test -s /workspace/repo/REVIEW.md`.
Engine: codex (Sol). You change NOTHING except creating `REVIEW.md`.

Haptics are SOLVED on hardware (`docs/design/motion-and-feedback.md`
**§2.3.4**, working Python reference at
`open-steam-controller/tests/fixtures/hw/haptic3-working-reference.py`,
usbmon provenance in the same fixtures dir). **§2.3.5** proposes the
daemon integration architecture. Review §2.3.5 against the landed
codebase and the wave-1/2 law.

Read: §2.3.4 + §2.3.5; `devices/mod.rs` (the hidapi input path, the
`step_by(3)` enumeration, the per-device factory); the mapper's
`RawState` consumption; `config-profiles.md` §14 + timing-engine v3
§3 (schema-2) + §14.6 (pulse law); the radial-menus §2.3 synthetic
activation precedent (a resolved-event sink).

Attack, priority order:

1. **The libusb-owns-interface-2 decision**: is porting ONLY the
   triton's input transport to `rusb` (interrupt-IN) while other
   devices stay hidapi actually clean, or does it fracture the
   device abstraction? What breaks — hotplug, the ghost-pad
   lifecycle, the daemon-holds-device refusal the harness relies
   on, multi-controller, the `osc-explore` tool (which also needs
   libusb now and must not fight the daemon)? Is "daemon becomes
   hid-steam" a scope the founder should accept or fence?
2. **Lizard-off ownership & lifecycle**: startup order, the 8s
   watchdog vs the existing read loop cadence, what happens on
   daemon exit (does the controller stay unmuted / return to
   lizard cleanly?), reload, disconnect/reconnect, and the
   yield-to-Steam interaction (§overlay-and-services §4 — when we
   PARK for Steam, we must release interface 2 so Steam can claim
   it; libusb ownership makes that explicit — is the design's park
   path compatible?).
3. **The `haptic` profile vocabulary**: does it compose with the
   landed activator pipeline and §14.6 pulses without inventing a
   new sink law? Side/gain validation, schema-2 gating, the
   game-rumble-passthrough path (where does XInput rumble ENTER the
   mapper — it's an input from the OS, not the controller). Editor
   preservation implications.
4. Root/permissions: libusb needs device access the daemon may not
   have as a user service — udev rule? Is that in scope and stated?

GO / NO-GO for a haptics build loop, with the minimal fold list and
an explicit call on whether the transport port is one loop or needs
splitting (transport port → haptic output → profile vocab → editor).

## Output
`REVIEW.md`: findings ranked, the transport-port verdict, GO/NO-GO,
loop-split recommendation.
