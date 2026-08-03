# SPEC — combine-rejection-floor: stop rejecting data we have no basis to reject

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Addresses issue **#151**. **Depends on #149** (the real fixtures) being
merged first — the photometry gates are the evidence this change is
judged by, and until they run there is no way to see what it did.

This change alters the pixels of every master already published. That
is intended and Casey has approved it. It is not a silent fix.

## Why

Measured on the real M13 master inputs (three nights), varying only
rejection kappa:

| kappa | integrated star flux | vs default |
|---|---|---|
| 1.5 | 1.707e8 | +14.45% |
| 3.0 (shipping) | 1.491e8 | — |
| 8.0 | 1.306e8 | −12.40% |

**A 30.7% swing in star photometry**, with background noise flat. The
parameter is not trimming outliers, it is deciding how much real signal
survives.

Mechanism: `rejection.py` clips with `stdfunc="mad_std"` and a floor of
`MIN_INPUTS_FOR_CLIP = 3`. For three sorted samples the MAD is
`min(|x1−x2|, |x3−x2|)` — the smaller of the two gaps — so the scale
estimate is biased low and the clip threshold far too tight. On clean
Gaussian noise with **no outliers present**, kappa=3.0 rejects at least
one of three samples in **32.6%** of pixels.

The finite-sample MAD literature quantifies the same bias by another
route: the unbiased MAD→σ factor at n=3 is **2.205** against the
asymptotic 1.4826, so `mad_std` underestimates σ by ~0.67× and kappa=3
behaves like ~2. MAD₃ is right-skewed toward zero, so the typical case
is worse than the mean case.

**Raising kappa does not fix this.** MAD₃ has positive density at zero,
so some pixels over-reject at any finite kappa.

## What the field does

- **PixInsight** ships **no rejection preselected**, deliberately.
  Its sigma-clipping pseudocode iterates `while (n > 0 and N > 3)` —
  its own loop declines to keep clipping a stack of three. Documented
  minimum for sigma clipping: *"a minimum of 8 or 10 images."*
- **DeepSkyStacker**'s recommendation engine: average or median for
  2–15 lights; clipping only above 15.
- **Astro Pixel Processor**: *"If you have less then 15-20 frames, use
  median integration without sigma clipping."*
- **IRAF** `sigclip`: *"there should be at least 10 pixels."*

Quotes and URLs are in issue #151. Do not re-derive them; cite it.

And specific to us: our inputs are already on-device stacks of hundreds
of subs, so trails and cosmic rays are diluted ~1/N_subs *before* we
see them. The outlier population this machinery exists to catch is far
thinner than in the frame-stacking case the guidance was written for.

## What to build

### 1. Raise the floor

`MIN_INPUTS_FOR_CLIP` 3 → **8**. Below it, no rejection: the valid mask
reflects only reprojection footprint coverage, exactly as it already
does at N<3.

No target in the archive currently has 8 nights, so in practice this
turns pixel rejection off everywhere today. That is the intent.

### 2. Do NOT switch to median integration

DSS and APP both say *median* at low N. **Do not do this**, and say in
PR.md that you deliberately did not.

Our nights differ enormously in depth — the M13 master combines nights
of very different `TOTALEXP`, and the Rho Herculis pair is 130s against
810s. A median weights them equally, discarding the exposure weighting
ADR 0003 exists for and throwing away most of the deep night's SNR.
Weighted mean with no rejection is correct **for our input shape**.
The published advice assumes roughly equal-depth frames; we do not have
those.

### 3. The recorded recipe must say what actually happened

This is the part that matters most.

When rejection is skipped because N is below the floor, the recipe
recorded in the FITS header and the catalog must show `enabled: false`
**and a machine-readable reason naming N and the floor** — not silently
report the requested recipe as though it ran. #148 established that the
recipe records the method; a recipe that claims a stage ran when it did
not is worse than no recipe.

If a recipe explicitly enables rejection at N below the floor, skip it,
record the skip with its reason, and log at WARNING. Do not fail the
job — N is a property of the data, not a user error.

### 4. Split kappa (additive, safe)

Replace the single `kappa` with `kappa_low` / `kappa_high`, defaults
**4.0 / 3.0** (PixInsight's documented defaults; IRAF splits them too).
Our outliers — trails, planes, satellites — are one-sided bright, so
the high side should do the work while a loose low side protects real
signal. Accept a bare `kappa` in a recipe as setting both, so #148's
recorded recipes remain readable.

### 5. If sigma rejection runs at all (N ≥ 8), fix the estimator

Switch `stdfunc` to **`"std"`** — plain sample standard deviation, what
PixInsight documents and what astropy's own `sigma_clip` defaults to.
Our `mad_std` came from the astropy CCD Reduction Guide, which pairs it
with **kappa=10** on 10–20 calibration frames; we took the estimator and
not the kappa. Take neither rather than half of one.

Keep `cenfunc="median"`.

### 6. Emit a rejection map

Per master, alongside the result: a map of how many inputs were
rejected at each pixel. PixInsight's documented workflow is to judge
rejection *by inspecting the map*, and the regression above would have
been obvious in one instead of needing a hand-built A/B against the
archive.

When rejection is skipped the map is uniformly zero — emit it anyway,
so its absence never has to be interpreted.

## Tests

- [ ] At N=3 with default settings, **no pixel is rejected** — the
  valid mask equals the finite mask.
- [ ] The recorded recipe at N<8 says rejection did not run, and names
  N and the floor. Assert on the recorded document, not on a log line.
- [ ] At N≥8 sigma clipping still runs, with `std` and split kappas.
- [ ] A recipe requesting `kappa: 2.5` sets both low and high.
- [ ] **Red-first on real data**: using #149's committed fixtures, show
  the photometry gate's measured star flux before and after this
  change. Put both numbers in PR.md. This is the whole point — if the
  fixtures cannot show this change, they are not doing their job and
  that is a finding worth reporting.
- [ ] The rejection map exists and is all-zero when rejection is
  skipped.
- [ ] Full gate green including `-race`, Postgres and S3 legs.

## Warts / traps

- **Do not change the stage order.** Moving background extraction after
  integration is the other option discussed in #151 and is a much
  larger change; it is not this loop.
- **Do not touch `reproject_interp`** — that is #152.
- Do not change weighting. Inverse-variance weighting is a real
  follow-up but not this change.
- Do not re-reduce anything. Producing new masters is an operational
  act run against the cluster by the conductor after this merges and
  deploys; your job is the code and the evidence.
- `envcontract_test.go` cross-checks the Go and Python sides. Extend
  it if the env contract changes; do not work around it.

Finish: `/workspace/PR.md` with the before/after star flux on the real
fixtures, the recorded-recipe document for a skipped rejection, what
the rejection map looks like, and an explicit statement that you did
not switch to median integration and why.
