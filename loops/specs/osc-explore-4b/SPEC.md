# SPEC — osc-explore-4b: wire the rumble session to manifest v4 (fix loop)

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-2.

**The defect (conductor-found, post-merge of osc-explore-4 / PR
#34):** all v4 machinery landed — parser, `rumble-manifest-v4.toml`,
provenance tests — but `explore/rumble_session.rs::run()` still
calls `load_v3()`, so the shipped binary replays round 3 and the
linker strips MANIFEST_V4 as dead code. The gate stayed green
because no test pins WHICH manifest the session uses. Read
`docs/design/motion-and-feedback.md` v7 §2.3.3 and the osc-explore-4
PR for context.

## Build

1. - [ ] **Port `run()` to `ManifestV4`**: consent screen (shows
   "version 4" and the sequence groupings), the probe/main phases,
   announcements, felt/Esc handling — all against V4. Implement the
   `sequence` law: members of one sequence send back-to-back
   ≤500 ms apart (still individually logged) as one announced unit;
   the inter-candidate 2 s floor applies BETWEEN units. Pure
   sequence-pacing tests against the fake clock.
2. - [ ] **The version guard**: a test that fails if the session's
   manifest source is not v4 — e.g. `run()` obtains its manifest
   from one function `session_manifest()` and a test asserts its
   version == 4 AND that its candidate ids equal
   `load_v4()`'s. This class of miss must be structurally
   impossible to repeat silently.
3. - [ ] V3 stays parseable (fixtures); nothing else changes.

## Warts / traps

- Small, surgical loop — no refactors beyond what the port needs.
- PR.md to /workspace/PR.md, noting explicitly this closes the
  osc-explore-4 wiring gap.

## Finish — PR.md
The wiring diff summary; version-guard and sequence-pacing test
names; untested-here.
