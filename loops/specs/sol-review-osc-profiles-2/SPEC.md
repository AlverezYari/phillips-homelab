# SPEC — sol-review-osc-profiles-2: verify the fold (REVIEW ONLY)

Repo: `loop-bot/OpenSteamController`. Gate: `test -s /workspace/repo/REVIEW.md`.
Engine: codex (Sol). You change NOTHING except creating `REVIEW.md` at
the repo root.

## What to review

`docs/design/config-profiles.md` is now **v2**, rewritten to fold the
9 findings from the previous adversarial review — which is preserved
verbatim on branch `loop/sol-review-osc-profiles` (fetch it:
`git fetch origin loop/sol-review-osc-profiles` and read `REVIEW.md`
from that branch). This is a VERIFICATION pass, not a fresh review:

1. For each of the 9 prior findings, state RESOLVED / PARTIALLY
   RESOLVED / UNRESOLVED against v2's actual text, with the v2 section
   that resolves it or the gap that remains.
2. Hunt for NEW holes the fold introduced — a rewrite this size
   invents fresh contradictions: cross-section inconsistencies
   (vocabulary vs. validation table vs. mode-program fields), the
   §1 interpreter contract vs. the real code in
   `src/devices/mapper.rs` / `src/devices/steam_controller.rs`, the §4
   lifecycle table vs. §5 TrayState vs. §6 D-Bus reply shapes, the §8
   workspace/gate changes vs. the existing Makefile and CLAUDE.md.
3. Judge implementability of stage 1 specifically: could an unattended
   build loop implement §1+§2+§3-types from this text without filing
   avoidable decisions or inventing semantics?

Do not relitigate settled founder rulings (egui, TOML, manual-first
switching, activator reservation, the §13 crate list) or the shipped
input-modes design. Concision beats completeness of prose — findings
only need file/section references and concrete failure scenarios.

## Output

`REVIEW.md` at repo root: the 9-finding resolution table first, then
any new findings ranked by severity, then GO / NO-GO for stage 1
(`osc-config-model`) and which findings, if any, block stages 2–4.
