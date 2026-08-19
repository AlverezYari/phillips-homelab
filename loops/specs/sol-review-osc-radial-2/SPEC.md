# SPEC — sol-review-osc-radial-2: verify the radial fold (REVIEW ONLY)

Repo: `loop-bot/OpenSteamController`. Gate: `test -s /workspace/repo/REVIEW.md`.
Engine: codex (Sol). You change NOTHING except creating `REVIEW.md`.

`docs/design/radial-menus.md` is now **v2**, folding your round-1
findings (ROUND1.md in this spec directory) — and, critically,
written against the LANDED wave-2 engine: PRs #24 (clock/pipeline/
schema-2) and #26 (control pass, shifts/layers, chords, dual/rings,
zones) are merged on main. Read the landed code where the design
cites it — especially `osc-config`'s interpreter/activator modules
and PR #26's review-note scope boundaries (controls only on direct
`mode.buttons` entries; `chord-outside-buttons`).

Verification pass:

1. Resolution table: round-1 findings 1–6 → RESOLVED / PARTIAL /
   UNRESOLVED against v2.
2. Priority checks:
   - §2.3 synthetic activation: is "indistinguishable from a
     one-transaction physical press" actually total against the
     LANDED pipeline (check the real classifier: what does a
     one-transaction press do to double windows, fire_delay,
     toggle, turbo, start/release_press — any sink where a
     1-transaction duration hits an untested boundary)?
   - §2.4: does the control-source amendment compose with the
     landed §4 reduction (canonical-order winner, unconditional
     releases) without a new rule? Is the "physical wins ties"
     claim actually what canonical order yields?
   - §2.1/§2.2: the WaitingRender machine and the touch mask vs
     the landed touch-source code — total, and honestly amendable
     in §14.2's terms?
   - §3.2 wire ordering: (generation, instance) per (ident, side)
     with a mapper-external instance counter — any remaining
     stale/reset hole, including §5.1-clear-then-reopen and
     daemon restart (name-owner)?
   - §3.3: null-output surfaces + fixed offsets — implementable
     without pointer protocols, and is the concurrent-menu layout
     rule total?
3. GO / NO-GO for promoting v2 to law with its same-commit
   amendments (the build loops remain gated on the founder's crate
   ruling regardless — that is not yours to gate).

Do not relitigate: positional identity (v2 explicitly rejects
stable IDs with its generation argument — attack the argument only
if it is WRONG, not to re-prefer stable IDs), schema 2, the fence
mechanism, crate deferral. Concision over prose.

## Output

`REVIEW.md`: resolution table, new findings ranked with
gate/no-gate honesty, verdict.
