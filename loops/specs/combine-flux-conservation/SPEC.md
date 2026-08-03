# SPEC — combine-flux-conservation: measure the claim, then decide

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Addresses issue **#152**.

**This is a measurement task first and a code change only if the
measurement justifies one.** Do not assume the answer. A PR that
measures carefully and concludes "no change needed, here is the bound"
is a complete success.

## The claim, and why it is unexamined

`reprojection.py` resamples every input with `reproject_interp`. The
[reproject docs](https://reproject.readthedocs.io/en/stable/celestial.html)
state plainly that this method is **not flux conserving**. The library
offers alternatives:

- `reproject_exact` — flux-conserving, documented as "essentially an
  exact form of drizzling", substantially slower
- `reproject_adaptive(conserve_flux=True)` — intermediate

Meanwhile ADR 0003 and #148's linear/display boundary both rest on the
premise that **everything up to and including integration is
photometrically meaningful**. That premise is why a recipe placing a
linear stage after the stretch is rejected. Registration is the first
stage in that chain, and it resamples with a method whose own
documentation disclaims flux conservation.

Nobody has measured it. The guarantee is asserted in an ADR, in
comments, and in a validation rule — which is exactly the pattern #132
was about: the assertion is what stopped anyone checking.

Our geometry is favourable — same instrument, same pixel scale, modest
relative rotation (the committed Rho Herculis pair differ by 8.9°). The
error may well be negligible. But "may well be" is the problem.

## What to measure

Use the committed real fixtures (`combine/tests/fixtures/real/`), which
now include the Rho Herculis pair and three M13 nights. Synthetic data
alone is not sufficient — the whole point is the real geometry.

For each of `reproject_interp`, `reproject_adaptive(conserve_flux=True)`
and `reproject_exact`, report:

1. **Total flux before vs after reprojection**, over the region covered
   by both input and output grid. The headline number.
2. **Per-star aperture photometry** on the brightest stars, before vs
   after — this is what actually matters scientifically, and a method
   can conserve total flux while redistributing it between stars and
   background.
3. **Wall-clock cost** per reprojection at full fixture size. `exact`
   being correct is not interesting if it makes a 20-night master
   untenable; say how long each takes.
4. Whether the error **grows with rotation angle**. The Rho pair is
   8.9°; a fleet spanning many mounts will see worse. Rotate a fixture
   synthetically if you need more angles, and say that you did.

Put all of it in PR.md as numbers.

## Then decide, and say why

Three legitimate outcomes:

- **Negligible** — pin the measured bound in a test, and replace the
  comment at the call site with the number and its date. The claim then
  rests on evidence rather than assertion. This is a good outcome; do
  not manufacture a change to look productive.
- **Material and affordable** — switch the default, prove the pixel
  change on the fixtures, and state the cost.
- **Material and expensive** — do not switch silently. Report it,
  state what it would cost, and leave the decision. A 20% photometric
  error we know about beats one we have quietly papered over.

Whichever it is, the outcome must be **recorded where the next person
looks**: at the call site, and in the recipe if the method becomes a
recorded choice.

## Tests

- [ ] A test pinning the flux-conservation error of the shipping method
  on real fixtures, with an explicit bound. It must fail if the error
  materially worsens — verify by injecting a change and showing it red.
- [ ] Pixel output unchanged if you do not switch methods.
- [ ] If you do switch: the fixture gates (photometry, background
  flatness, coverage boundary) still pass, and PR.md shows their
  before/after numbers.
- [ ] Full gate green including `-race`, Postgres and S3 legs, 0 skips.

## Warts / traps

- **Do not add a member-facing knob.** Whether registration method
  becomes a recipe parameter is a separate decision; this loop
  measures and, at most, changes a default.
- Do not touch rejection (#151, just landed), the digest (#156, just
  landed), or background/normalization/weighting/integration.
- `reproject_exact` on full-size frames may be slow enough to need
  care in tests — measure at full size, but do not leave a
  multi-minute test in the suite. Say what you did.
- The reference input is passed through **without** reprojection
  (`is_reference` short-circuits). Whatever you conclude, that
  asymmetry is part of the picture: the deepest frame is never
  resampled, every other frame is.

Finish: `/workspace/PR.md` with the four measurements as tables, the
decision and its justification, and — if you changed nothing — the
exact comment now standing at the call site in place of the old claim.
