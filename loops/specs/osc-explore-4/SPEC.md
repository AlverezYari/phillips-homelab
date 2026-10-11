# SPEC — osc-explore-4: rumble round 4 — the report-id-0x01 verbatim replay

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-2.

**Read first, all on main:** `CLAUDE.md`;
`docs/design/motion-and-feedback.md` **v7 §2.3.3** — law, with the
usbmon fixture `tests/fixtures/hw/osc-usbmon-steam-rumble.txt` as
the byte-level provenance for EVERY frame in manifest v5 (the file
numbering: manifest versions v1-v3 are landed; this loop's manifest
is `rumble-manifest-v4.toml` implementing the design's "round 4"
candidates — name the file v4).

## Build

1. - [ ] **Transport fix**: feature sends use report id **0x01** —
   buffers begin `01`, 65 bytes, zero-padded (the design: "hidapi's
   send_feature_report with buf[0]=0x01 is the whole transport
   fix"). A pure frame-builder test pins buf[0] == 0x01 against a
   regression test quoting the v7 rationale (three rounds failed on
   id 0x00).
2. - [ ] **`rumble-manifest-v4.toml`** EXACTLY per §2.3.3: C1-buzz
   verbatim, C1-ping verbatim, 87-2d-64 → C1-buzz pair, dc+e2 →
   C1-buzz triple, and C1-buzz once to each non-input interface
   (nodes are already enumerated with interface numbers). Manifest
   gains an optional `sequence` grouping (candidates sent
   back-to-back ≤500 ms apart as one announced unit) — validation:
   a sequence's members are consecutive and share one announce.
3. - [ ] **Announcements** per round-3 precedent ("BUZZ — both
   pads, Steam's own test frame", "PING pattern", …); founder
   verbal report is the attribution channel; felt marker retained.
4. - [ ] Pure tests: v4 parsing + sequence validation + frame
   builder; fixture-compat for all earlier capture files; the
   usbmon fixture itself gets a parser test extracting the two
   0xC1 payloads and asserting the manifest bytes EQUAL them
   (provenance enforced by test, not by prose).

## Warts / traps

- Do not decode 0xC1 fields; do not vary bytes. Verbatim means
  verbatim — decode is round 5, gated on round 4 buzzing.
- The per-interface C1 sends reuse round-3's probe machinery
  (per_interface) but with the 0x01 report id.
- Additive capture fields only; earlier fixtures must parse.
- No new crates. PR.md to /workspace/PR.md with the founder
  runbook.

## Finish — PR.md
Runbook; manifest table with provenance test names; frame-builder
regression; untested-here.
