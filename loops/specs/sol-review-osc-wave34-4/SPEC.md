# SPEC — sol-review-osc-wave34-4: verify the round-3 fold (REVIEW ONLY)

Repo: `loop-bot/OpenSteamController`. Gate: `test -s /workspace/repo/REVIEW.md`.
Engine: codex (Sol). You change NOTHING except creating `REVIEW.md`.

Round 4 of a converging series. v4 of
`docs/design/motion-and-feedback.md` and
`docs/design/overlay-and-services.md` folds your round-3 findings
(ROUND3.md in this spec directory). Round 3 already granted GO to
osc-analog-shaping and diagram — those are settled; scope is ONLY
the three previously gated tracks:

1. `osc-explore`: the new device/interface predicate (§2 of
   motion) — sysfs HID_ID VID/PID allowlist, parent-USB-device
   grouping, probe-only-the-input-streaming-interface rule, and
   the hardware note (five interfaces on PID 0x1304). Exact and
   implementable? Duration prose now matches the corpus?
2. tester: `(session, seq)` staleness law + name-owner restart
   rule + GetControllers-driven selector. Total across
   replacement-between-polls, restart, serial-less devices?
3. yield §4.2: the matrix now claims totality with explicit no-op
   cells, ACQUIRING(reason, not_before), force guards, and a
   replacement row. Walk it: any (state, event) cell still
   undefined or contradictory? Does PARKED-implies-evidence hold
   everywhere now, including persisted-force startup?

GO / NO-GO per track. P2 polish is not a gate — say so explicitly
when a finding is polish. Concision over prose.

## Output

`REVIEW.md`: short resolution table, any remaining findings ranked
with gate/no-gate honesty, three verdicts.
