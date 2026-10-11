# SPEC — osc-explore-3: rumble round 3 — interface probe + loud attribution

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-2.

**Read first, all on main:** `CLAUDE.md`;
`docs/design/motion-and-feedback.md` **v6 §2.3.2** — law: the
two-phase round-3 session (per-interface feature probe, then loud
one-side-at-a-time output candidates with announced attribution).
Round-1/2 fixtures in `tests/fixtures/hw/` are ground truth; the
manifest-v2 machinery (latching/stop law, stop_for_seq) is landed —
extend, don't rewrite.

## Build

1. - [ ] **Manifest v3 schema**: candidates gain optional
   `phase = "probe" | "main"` (default main) and probe candidates
   gain `per_interface = 1`: the session sends that ONE frame via
   feature to EVERY node in the device group, bInterfaceNumber
   order, ≥2 s apart, logging each with an additive `probe_node`
   field (sysfs interface number) on the `send` line. Round-1/2
   manifest fixtures still parse (test).
2. - [ ] **`rumble-manifest-v3.toml`** EXACTLY from §2.3.2: the one
   probe candidate (0x8F side 0, on 5000 µs, off 5000 µs, repeat
   20, 65-byte 0x00-prefixed), then the main phase on the OUTPUT
   pipe: 0x8F side 0 and side 1 at repeat 200; the two "hard"
   variants (on 10000 µs, off 2000 µs, repeat 150); 0xEB intensity
   0xFFFF left-only and right-only at speed 0xFFFF with
   stop_after_ms 800. Each candidate carries a `announce` string
   ("LEFT pad long buzz", …) printed before its countdown and shown
   in the consent table.
3. - [ ] **Session flow**: probe phase runs first with its own
   header line ("probing N interfaces for command acceptance");
   per-node results printed live (accepted/refused). Main phase
   then announces each candidate's expected feel and side before
   sending. Felt marker stays; the runbook says the founder's
   verbal report is the attribution channel.
4. - [ ] Pure tests: v3 parsing + validation (announce required on
   main-phase candidates; probe candidates must be non-latching and
   bounded), probe fan-out ordering against a fake node list,
   fixture-compat for v1/v2 captures with the new optional field.

## Warts / traps

- The byte strings come from §2.3.2's table — design wins over your
  reading; PR.md flags any discrepancy instead of resolving it.
- Probe sends are FEATURE transport to non-input interfaces — the
  harness must open those nodes read-free (no input identification
  on them) and close them after the probe phase.
- Additive capture fields only; round-1/2 fixtures must parse.
- No new crates. PR.md to /workspace/PR.md with the founder
  runbook (two phases, what each announcement should feel like,
  and that "felt nothing" per candidate is still data).

## Finish — PR.md
Runbook; v3 manifest table as landed; probe/announce test names;
fixture-compat; untested-here.
