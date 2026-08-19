# SPEC — sol-review-osc-wave34-2: verify the wave 3/4 fold (REVIEW ONLY)

Repo: `loop-bot/OpenSteamController`. Gate: `test -s /workspace/repo/REVIEW.md`.
Engine: codex (Sol). You change NOTHING except creating `REVIEW.md`.

`docs/design/motion-and-feedback.md` and
`docs/design/overlay-and-services.md` are now **v2**, folding your
round-1 findings (your REVIEW.md is preserved verbatim in the spec
directory's ROUND1.md — read it). Verification pass, the
profiles/editor/timing precedent:

1. Resolution table: round-1 findings 1-5 (motion) and 1-6
   (overlay) → RESOLVED / PARTIAL / UNRESOLVED against the v2 text.
2. New holes the fold introduced. Priority checks:
   - §3.2 shaping golden vectors: recompute them — are the numbers
     right (rounding rule, 7282, 19660/26214, the 0.45 custom
     point)? Is the pipeline total for corner inputs (|n| > 1
     diagonals) and the curve law self-consistent with out[0]=0,
     out[3]=1 given `out` non-decreasing?
   - §3.3 staging: the same-commit amendment rule — does the
     "daemon too old for <key>" reader row contradict schema 2's
     existing unknown-key law in timing-engine §3 or
     config-profiles §3?
   - motion §2.3 manifest: are the 12 candidates truly bounded and
     finite as claimed? Does any wording still smuggle protocol
     knowledge into safety claims?
   - overlay §2.1 GetInputSnapshot: is the tuple total for every
     lifecycle row (no-report-yet, disconnect, replacement, daemon
     restart)? Any D-Bus signature error (t for u64 monotonic — is
     that the right choice vs x)?
   - overlay §4.2: walk the yield table for stuck states — is
     there a path where evidence vanishes but no timer is armed
     (Steam exits while NOT parked and no steam process remains →
     does anything still poll)? FORCE_HOLD acquire-fail behavior?
   - overlay §1.2 registry vs the actual landed SVG ids (fetch the
     asset and diff the table against reality).
3. Confirm §3 (radial) and motion §4 (gyro/haptics destination)
   are now watertight non-authorizing fences.

Do not relitigate settled rulings (schema 2, raster + hit-map,
pull-based tester, hardware gating, radial deferral itself).
Concision over prose.

## Output

`REVIEW.md`: resolution tables, new findings ranked, GO / NO-GO per
buildable track (osc-explore, osc-analog-shaping, diagram, tester,
yield), and the minimal fold list for anything short of GO.
