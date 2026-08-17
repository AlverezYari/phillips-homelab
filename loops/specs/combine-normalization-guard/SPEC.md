# SPEC — combine-normalization-guard: no more negative photometric scales

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

## The failure (live master, 2026-08-16)

The sh2-157 master (`master-seestar-1-sh2-157`, 2 night-stack inputs)
integrated one night with a NEGATIVE photometric scale factor —
actively subtracting that night's signal from the master. External
analysis of `masters/sh2-157/master.fit`'s `INnSCALE` provenance cards
surfaced it; the mechanism is confirmed in code:

- `combine/src/tycho_combine/normalization.py` is designed for RAW,
  pre-background-subtraction inputs — its docstring's premise is that
  sky brightness dominates the overlap median (large, positive,
  stable).
- **Master mode violates that premise**: its inputs are per-night
  `stack.fit` products the session combine already background-
  subtracted, so the overlap median is residual noise around zero.
  `pipeline.py:1143-1144` measures the median before this run's own
  background stage — i.e. on the already-subtracted stack.
- `scale_factor_from_medians` (`normalization.py:44-55`) falls back to
  1.0 only for non-finite or EXACTLY zero medians. A residual median
  of −1e-5 passes the guard and flips the ratio's sign.

## What to build

### 1. Statistical-zero guard, not exact-zero

A median is unusable when it is indistinguishable from zero, not only
when it equals zero. Alongside each overlap median, measure the
overlap's robust noise (MAD-based) and treat the median as invalid
when |median| is below a small multiple of that noise scaled for the
sample size. Both call paths — `compute_scale_factors` and the
streaming path in `pipeline.py` (`overlap_median` +
`scale_factor_from_medians`) — must apply the same rule:

- invalid input median → that input's factor is 1.0;
- invalid REFERENCE median → every factor 1.0 (the existing exact-zero
  pattern, widened).

Pick the threshold constant deliberately and document why (it must not
disable normalization on genuinely sky-dominated session inputs, whose
medians are orders of magnitude above their noise — show that margin
in PR.md with realistic numbers).

### 2. A computed factor must never be non-positive

Defense in depth regardless of how it was computed: a factor ≤ 0 is
never applied — fall back to 1.0. A negative multiplicative
photometric scale has no physical meaning in this pipeline.

### 3. Say so in the recipe/provenance

This codebase's rule: a skipped stage must never read as a ran stage
(see `rejection_skip_reason`, pipeline.py). When the guard forces
factors to 1.0 — per-input or wholesale — the recipe and the result
header must record that normalization was skipped/degraded and why
(reference-median-indistinguishable-from-zero, input-median-invalid,
non-positive-factor-clamped). `INnSCALE` cards keep being written
(they'll read 1.0).

### 4. File the master-mode question as a decision, don't solve it here

Even guarded, a sky-median ratio measured on background-subtracted
stacks is meaningless as a *normalization signal* — the guard makes it
harmless (1.0), not right. The correct master-mode normalization (e.g.
positive-signal/star-flux ratio between night stacks) is a design
change: write it as a `decisions/` file with options and a
recommendation for founder sign-off, and leave master-mode behavior at
"guarded to 1.0" in this loop.

## Tests (red first)

- [ ] The sign-flip reproduction: reference median a realistic sky
  value, input median −1e-5 with realistic overlap noise → factor is
  1.0, and specifically NOT negative. Name the sh2-157 incident in the
  test comment.
- [ ] Property: for any pair of finite medians, the returned factor is
  > 0.
- [ ] Statistically-zero reference (both signs) → all factors 1.0 +
  skip reason recorded.
- [ ] Sky-dominated medians far above noise → ratio behavior UNCHANGED
  (existing session-mode tests keep passing untouched).
- [ ] Streaming path (pipeline.py) and list path
  (compute_scale_factors) agree on the same inputs.
- [ ] Provenance: header/recipe carry the skip/degrade reason; a run
  with healthy normalization records none.
- [ ] Tests are REAL: no fixture-gated self-skips (the known gate-debt
  trap) — these must run in the ordinary `make test` combine leg.

## Warts / traps

- Do not touch the combine-job fingerprint/GC/idempotency work — that
  is a separate loop's territory. This loop changes only
  normalization math, its guards, and provenance.
- Session-mode behavior on genuinely raw inputs must be bit-identical
  when medians are healthy — this is a guard, not a re-tune.
- Deploy note for PR.md: dev dark mode means merge ≠ live — the
  combine image must be built/pushed and gitops-bumped, AND the
  master's combinable-set fingerprint keys on inputs, not engine
  version, so the existing sh2-157 master will NOT self-recombine on
  deploy. Spell out the operator step to force the re-run (or note
  that the next night's new input retriggers it naturally).
- `docs/design/**` is read-only law.

Finish: `/workspace/PR.md` with the threshold rationale + margin
numbers, before/after factor tables for the sh2-157-shaped case, the
decision file, and the deploy/re-run note.
