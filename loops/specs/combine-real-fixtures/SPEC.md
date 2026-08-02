# SPEC — combine-real-fixtures: the photometry gates have never run

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Closes issue **#149**, and touches **#150**.

## The problem

`make test-combine` reports `OK (skipped=14)`. All 14 skip on a missing
path:

- 9 on `Rho Herculis fixture pair not present in /workspace/fixtures`
- 5 on `/workspace/fixtures/m13-full.fit not present`

`/workspace/fixtures` is a loop-sandbox path and **there is no such PVC
in the cluster** — `kubectl -n loops get pvc` lists only
`nats-js-nats-0`. These tests do not run in a sandbox, do not run in
CI, and do not run locally. They have never run.

The skipped set is exactly the checks that would catch a reduction
regression: `test_photometry_preserved` (integrated flux of the 20
brightest stars), `test_background_is_color_neutral_after_balance`,
`test_no_channel_fully_clipped`, the coverage-boundary step test, the
background-flatness test, and the cross-night reference-grid tests.
**Everything currently green in the combine suite is synthetic.**

This is not hypothetical. Reviewing #148 required hand-pulling three
real night stacks out of Garage to check a byte-identical claim, and
doing so immediately surfaced **#151** — sigma clipping discards a
third of clean samples at N=3. Neither the claim nor the defect was
reachable from the automated suite.

## What to build

### 1. Committed fixtures, downsampled

The real inputs exist in the archive:

```
tycho-source-seestar-1/sessions/rho-herculis-2026-07-15/results/stack.fit
tycho-source-seestar-1/sessions/rho-herculis-2026-07-17/results/stack.fit
tycho-source-seestar-1/sessions/m-13-2026-07-29/results/stack.fit
```

They are 80–95 MB each — too large for git as-is. **Downsample to a
crop that still exercises the assertions**: the photometry test needs
enough bright stars to integrate, the cross-night pair needs the real
rotation/offset between the two Rho Herculis nights, and the
background tests need real gradient structure. A few MB each is the
target. Preserve the WCS and the `TOTALEXP`/`NCOMBINE` header cards —
several tests read them.

Say in PR.md how you derived the crops and what you verified survives
(star count, gradient, the inter-night rotation angle).

### 2. Point the tests at them

Replace the `/workspace/fixtures` gate with a repo-relative fixtures
path. **The tests must run by default**, not on an opt-in env var —
the whole defect here is a check that silently doesn't.

If any single test genuinely cannot work on a crop, say so in PR.md
and leave it skipping *with a reason naming why*, not a missing path.

### 3. Prove they bite

A fixture-backed test that cannot fail is the same defect in a new
costume. For **each** of the photometry, background-neutrality and
coverage-boundary tests, introduce a deliberate regression (e.g.
perturb `weighting.py`'s exposure weighting, or skew a channel in
`presentation.py`), confirm the test goes red, revert, confirm green.
Put the red output in PR.md.

### 4. Fix the venv path (#150)

`Makefile:32,38` default `VENV_COMBINE`/`VENV_SCORER` to
`/workspace/...`, so outside a sandbox `make venv-combine` dies on
permission denied and `make test` then goes **green with the entire
Python suite silently skipped**. Default to a repo-relative,
gitignored path and let the loop rig override via environment. The rig
is the special case; it should carry the special-case config.

## Tests

- [ ] `make test-combine` reports **0 skips** with no env setup, from a
  clean clone.
- [ ] Each of the three named gates demonstrably fails on an injected
  regression (shown in PR.md).
- [ ] `make venv-combine` succeeds outside a sandbox with no overrides.
- [ ] The full gate stays green, including `-race`.

## Warts / traps

- **Do not change any reduction maths.** #151 is a live decision about
  clipping at low N and is *not* this loop. If a fixture test fails
  because of that bias, say so in PR.md and leave the maths alone.
- Do not add a fixture-download step that needs archive credentials —
  CI has no Garage access. Commit the crops.
- Keep the fixture files out of any container image build context that
  would bloat the published images; check `.dockerignore`.
- Real sky data: these are Casey's own frames, already public via the
  attribution page, so committing crops is fine.

Finish: `/workspace/PR.md` with how the crops were derived, the red
output for each injected regression, the before/after skip count, and
confirmation `make venv-combine` works from a clean clone.
