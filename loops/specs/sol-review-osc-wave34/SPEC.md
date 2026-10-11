# SPEC — sol-review-osc-wave34: adversarial review of the wave 3 and wave 4 designs (REVIEW ONLY)

Repo: `loop-bot/OpenSteamController`. Gate: `test -s /workspace/repo/REVIEW.md`.
Engine: codex (Sol). You change NOTHING except creating `REVIEW.md`.

First round on two young drafts, both on main:

- `docs/design/motion-and-feedback.md` — gyro/rumble (hardware-gated
  behind the osc-explore harness findings) + ungated analog shaping.
- `docs/design/overlay-and-services.md` — editor diagram view
  (pre-rendered raster + JSON hit-map), pull-based input tester
  (GetInputSnapshot), layer-shell radial menus, yield-to-Steam.

Context you must read: `docs/design/config-profiles.md` (§14 and the
new schema-2 §3/§7 rows), `docs/design/timing-engine.md` v3 (the
engine these features ride on), `docs/design/capability-audit.md` v2
(staging), `docs/design/input-modes.md` v2. The wave-1 vocabulary and
§14.0 transition identity are landed code.

Attack, in priority order:

1. Cross-design contradictions: do the drafts claim anything
   timing-engine v3 or config-profiles forbids (activator lifetimes,
   BindingPath grammar coverage for gyro/shaping sources, schema-2
   trigger list gaps for the new shapes)?
2. Hardware-gating honesty: is every gyro/rumble behavior actually
   derivable from the osc-explore capture formats, or does the design
   smuggle in protocol facts nobody has measured?
3. Unattended-buildability: which sections are law and which are
   vibes? A build loop must not have to invent semantics (deadzones,
   sensitivity curves, radial-menu selection/dismissal, snapshot
   staleness, Steam-detection rules).
4. The usual: totality of state machines, reload/hotplug/transition
   behavior, editor preservation implications, validation bounds.

Do not relitigate settled rulings (schema 2, egui, raster+hit-map
diagram, pull-based tester, hardware gating itself). Concision over
prose.

## Output

`REVIEW.md`: findings ranked per design, GO / NO-GO per design for
its build loops, and the minimal fold list if NO-GO.
