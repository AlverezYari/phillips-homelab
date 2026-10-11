# SPEC — sol-review-osc-wave34-3: verify the round-2 fold (REVIEW ONLY)

Repo: `loop-bot/OpenSteamController`. Gate: `test -s /workspace/repo/REVIEW.md`.
Engine: codex (Sol). You change NOTHING except creating `REVIEW.md`.

`docs/design/motion-and-feedback.md` and
`docs/design/overlay-and-services.md` are now **v3**, folding your
round-2 findings (ROUND2.md in this spec directory, verbatim).
Tight verification pass — this is round 3 of a converging series;
scope is the round-2 fold ONLY:

1. Resolution table: the five ranked round-2 findings (yield
   blindness/ownership, snapshot wire contract, rumble bound
   honesty, schema diagnosis, stick-scroll deadzone) plus the
   registry gap → RESOLVED / PARTIAL / UNRESOLVED.
2. Hole-check the two rewritten machines only:
   - §4.2 yield table: walk every (state, event) pair for
     unreachable/undefined cells; check PARKED-implies-evidence
     holds through the force rows; check AWAY re-entry resets
     backoff sanely.
   - §2.1 snapshot: is the ident/known-map law total across
     restart + serial-less + replacement? Any remaining D-Bus
     signature error?
3. Per-track GO / NO-GO: osc-explore, osc-analog-shaping, diagram,
   tester, yield.

Do not reopen round-1 territory that round 2 marked RESOLVED, and
do not relitigate fences. If a finding would be P2 polish rather
than a build-loop hazard, say so and don't let it gate.

## Output

`REVIEW.md`: resolution table, any new findings ranked with
gate/no-gate honesty, per-track verdicts.
