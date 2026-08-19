# SPEC — osc-explore-2: rumble round 2 — manifest v2 + latching stop law

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-2.

**Read first, all on main:** `CLAUDE.md`;
`docs/design/motion-and-feedback.md` **v5 §2.3.1** — law, complete
with the SDL citations and the exact candidate table. The round-1
fixtures in `open-steam-controller/tests/fixtures/hw/` are your
ground truth for what happened. The felt-gate and node-dedup fixes
are already on main.

## Build

1. - [ ] **Manifest schema v2** in `rumble_manifest.rs`: candidates
   carry `bytes` (exact hex, the whole buffer including any 0x00
   report-id prefix and zero padding), `latching = 0|1`, and — iff
   latching — `stop_bytes` + `stop_after_ms` (100–1000, validation
   enforces presence and range). v1 parsing stays intact (fixtures
   for both). No duplicate ids / (transport, bytes).
2. - [ ] **`rumble-manifest-v2.toml`** authored EXACTLY from the
   §2.3.1 table: four 0xEB feature rumbles (both-mid 0x8000/0x8000,
   left-full, right-full, intensity-2/gain-2), three 0x8F feature
   pulses (sides 0/1/2, on 5000 µs, off 5000 µs, repeat 20), the
   0xEB and 0x8F frames bare on the output transport. Feature
   buffers are 65 bytes: 0x00 prefix + frame + zero padding. Stop
   frames = same 0xEB frame with zero speeds. Every latching
   candidate: stop_after_ms = 400.
3. - [ ] **Latching send law** in the session: send → poll felt/Esc
   for stop_after_ms → send stop_bytes → log both (`send` line with
   the additive `stop_for_seq` field per §2.3.1). **Esc or any
   abort path sends the pending stop FIRST** — pure state machine
   against a fake clock, red-first, including abort-inside-window
   and session-limit-inside-window.
4. - [ ] `osc-explore rumble` loads v2 by default (v1 stays
   embedded for the parser fixtures); consent screen prints the v2
   table with the latching/stop columns.

## Warts / traps

- The byte strings come from the design table, not from you — if
  §2.3.1 and your reading disagree, the design wins and PR.md says
  so. No new candidates, no generated variations.
- Capture schema change is ADDITIVE only (`stop_for_seq` optional on
  `send` lines); the round-1 fixture files must still parse with the
  updated reader — that's a test.
- No new crates. PR.md to /workspace/PR.md, with the founder's
  round-2 runbook (same 10-minute shape; note that rumble candidates
  now stop themselves and Esc is stop-then-abort).

## Finish — PR.md
Runbook; manifest table as landed; stop-law test names; fixture
compat test; untested-here.
