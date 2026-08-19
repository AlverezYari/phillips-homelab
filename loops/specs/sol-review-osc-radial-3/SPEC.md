# SPEC — sol-review-osc-radial-3: verify the round-2 fold (REVIEW ONLY)

Repo: `loop-bot/OpenSteamController`. Gate: `test -s /workspace/repo/REVIEW.md`.
Engine: codex (Sol). You change NOTHING except creating `REVIEW.md`.

Round 3 of a converging series. `docs/design/radial-menus.md` is
**v3**, folding your round-2 findings (ROUND2.md here). Round 2
already confirmed: synthetic activation, control composition, touch
ownership (minus the WaitingRender hole), positional identity, click
rejection, ordered-stack validation, runtime-vs-load degradation.
Those are settled. Scope is ONLY the four folds:

1. Wire (§3.2): `(generation, instance, revision)` ordering with
   revision on every signal including close, plus the normative
   overlay-side name-owner reset. Walk: open → select → select →
   close; clear-then-reopen; daemon restart with surviving overlay;
   two (ident, side) streams interleaved.
2. Item grammar (§1): the examples now claim to be landed
   `DigitalBinding` shapes verbatim — check them against
   `osc-config/src/vocabulary.rs` (rich activator sinks for fan-out
   and cycle).
3. WaitingRender (§2.1): the timeout row, the every-exit-emits-close
   rule, and MenuReady/touch-end precedence — total now? Does Open
   entry's "computed from THIS transaction's touched sample" have a
   no-touch corner left?
4. Placement (§3.3): output-sized anchored canvas + painted six-slot
   layout + mod-3 fallback — implementable with plain wlr-layer-shell
   (configure gives size, no margin tricks)? Layout total for
   disconnect/reorder/output-swap?

GO / NO-GO for promotion to law with its same-commit amendments
(crate ruling stays a separate build gate). P2 polish is not a gate —
say so when a finding is polish. Concision over prose.

## Output

`REVIEW.md`: short resolution table, remaining findings ranked,
verdict.
