# SPEC — combine-coverage-threshold: a footprint contract nobody wrote down

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Closes issue **#162**. Regression introduced by #159, **live in
production** in `masters/m-13/master.fit` (revision 7).

## The bug

```python
def common_coverage_mask(footprints):
    return np.all(footprints > 0, axis=0)
```

`reproject_interp` returns an effectively binary footprint — measured on
the committed M13 fixtures, **zero** pixels with `0 < fp < 0.99`.
`reproject_exact`, which #159 switched to, computes true fractional
pixel-overlap area and produces **2,930** partial pixels on the same
data.

Under `> 0`, a pixel covered by one part in a thousand counts as fully
covered. At the **112.8°** rotation real in the M13 nights, a thin
sliver along a rotated edge extends the tight bounding box across a
huge row range.

Production effect, same inputs and same reference grid:

| revision | method | shape | finite |
|---|---|---|---|
| r6 | `interp` | (3, 2360, 1879) | 77.8% |
| r7 | `exact` | (3, 3611, 1880) | 68.7% |

1,251 rows taller, 9 points less real data.

## What it defeats

`crop_to_common_coverage`'s own docstring:

> *"Requiring **every** input to cover a pixel before it survives
> removes that partial-coverage sliver outright (NaN, not a
> lower-count average) rather than smoothing it."*

A step in the number of contributing inputs across a line reads as a
visible brightness seam. That is what the crop exists to prevent, and
with fractional footprints it no longer does.

## What to build

### 1. Threshold on real coverage, not on non-zero

Pick a coverage fraction. **Justify the number with a measurement**, do
not pick 0.99 because this spec said it. Show what the chosen value
does to output geometry on the real fixtures, and what the neighbouring
values would do.

A named constant with a docstring, not a literal. The docstring must
state **which footprint semantics it assumes**, because the entire
failure here is that `> 0` silently depended on `reproject_interp`
returning binary footprints and nothing recorded that.

### 2. Audit for the same assumption elsewhere

Footprints are fractional now. `> 0`, `astype(bool)`, `!= 0`,
truthiness — anywhere a footprint is treated as binary is suspect. Say
in PR.md what you checked and what you found, including "nothing else."

### 3. A test that would have caught this

The existing sliver test runs on the Rho pair at **8.9°**, where the
effect is 2 rows. It passed throughout.

Add a test that combines the **three M13 night fixtures** — real
rotations of 1.3°, 112.8° and 114.1° — and asserts on **output
geometry**, not only pixel statistics. Shape and finite fraction are
the things that moved and that nothing checked.

Verify it bites: reintroduce `> 0`, show it red, revert, show it green.
Put the red output in PR.md.

## Tests

- [ ] The M13 three-night combine produces output geometry consistent
  with `interp`'s, within a stated tolerance — and the test fails if
  the threshold regresses to `> 0`.
- [ ] The existing Rho sliver test still passes.
- [ ] The three numeric gates still pass; report their before/after
  numbers.
- [ ] Full gate green including `-race`, Postgres and S3 legs, 0 skips.

## Warts / traps

- **Do not revert #159.** The 5.2% per-star error at 112.8° is real and
  worth fixing; `reproject_exact` stays.
- Do not change rejection (#151), the digest (#156), or any other
  reduction stage.
- The rejection-count map passes `fill_value=0` through the same crop
  path because an integer array cannot hold NaN — check your change
  does not break it.
- The reference input short-circuits reprojection and gets a footprint
  of exactly `1.0` everywhere. Whatever threshold you choose must not
  accidentally exclude it.

Finish: `/workspace/PR.md` with the chosen threshold and the
measurement justifying it, the output geometry before/after on the real
fixtures, the audit results, and the red output proving the new test
bites.
