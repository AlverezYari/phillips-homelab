# SPEC — osc-explore: the founder's HID exploration harness (wave 3 prep)

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-2.

**Read first:** `CLAUDE.md`;
`docs/design/motion-and-feedback.md` **v2** §2 — law, and it is
strict: capture formats are versioned JSONL with raw-first
provenance (§2.1 line schemas verbatim), the rumble corpus is a
checked-in finite manifest, and the safety wording ("abort, not
emergency stop") is normative. The harness turns the founder's ten
minutes into the fixtures wave 3 is gated on.

## Build

1. - [ ] **`osc-explore` bin target** in the daemon crate (dev tool;
   documented as not-for-release in its --help). Refuses to start
   while the daemon holds the controller (hidraw open fails → clear
   message naming the daemon). VID allowlist 0x28de: it will not
   open anything else, by name in the refusal message.
2. - [ ] **Capture writer** implementing §2.1 exactly: header /
   report / prompt / send / send_result / felt / note / end lines,
   full raw reports as hex, CLOCK_MONOTONIC µs, report descriptor
   in the header. Serialization is pure and round-trip tested; a
   reader for the format lives beside the writer (the wave-3 loops
   and the CSV projection both use it).
3. - [ ] **`osc-explore imu`** per §2.2: live signed-16 LE column
   view of bytes 30-48 (a VIEW — raw reports are what's recorded),
   min/max/variance per column, scripted prompt sequence with
   prompt-boundary records, NON-NORMATIVE best-guess axis map on
   exit, CSV regenerated from the jsonl by a pure function.
   Parsing/statistics/guess/projection all pure and table-tested
   against synthetic streams; only the hidraw loop is glue.
4. - [ ] **`rumble-manifest-v1.toml`** committed at
   `open-steam-controller/assets/`: the 12 SC-2015-family
   candidates from §2.3, exact bytes, transport + rationale fields.
   Loader validates: parseable hex, bounded (count field present
   and ≤ 0x20 in the 0x8f frame), no duplicates.
5. - [ ] **`osc-explore rumble`** per §2.3: prints the manifest and
   requires typed `yes`; sends ONLY manifest bytes; ≥2 s spacing
   (floor), ≤64 sends/session; send line logged BEFORE the write,
   send_result after; any-face-button = felt marker (reads input
   reports between sends); Esc aborts future sends immediately,
   including mid-countdown — the UI text must not claim it stops
   the device. Pacing/abort state machine pure against a fake
   clock; sending is glue.

## Warts / traps

- The design's §2.1 line schemas are the contract — field names
  and types verbatim; the wave-3 loops parse these files.
- No daemon/library behavior changes beyond the new bin target and
  the shared capture reader; no new crates (raw hidapi/hidraw +
  std; serde_json is already in-tree — check Cargo.lock before
  assuming).
- The harness cannot run in the sandbox (no hardware) — its pure
  logic tests are the gate; say so in PR.md with the founder's
  10-minute runbook (exact commands, physical steps, which files
  to hand back and where they get committed).

## Finish — PR.md
The founder runbook front and center; pure-test audit; the manifest
table; untested-here.
