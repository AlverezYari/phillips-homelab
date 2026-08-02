# SPEC — combine-declarative-recipe: the method becomes data

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

First step toward member-authored recipes. **No UI, no sharing, no new
stages, no parameter surface for members.** This loop turns a hardcoded
call order into a document, and records that document with the result.

## Why

`pipeline.py`'s own docstring states the sequence:

> *"load -> reproject -> background -> weight -> reject -> integrate ->
> provenance header"*

That order is compiled into Python. The knobs exist but are unreachable
— `reject_outliers(stack, kappa: float = 3.0)` is a function default,
changeable only by rebuilding the image.

And **nothing records what was done**. The gallery page wants to print a
recipe line and cannot; its spec had to say *"omit it or state it is
unrecorded"*. A master today records its inputs and not its method.

## The stages are not ours to invent

The existing modules already map onto the conventional reduction
sequence — `ccdproc`/Astropy's CCD reduction guide, Siril's documented
workflow (already credited in `background.py`), PixInsight's ordering:

| module | stage |
|---|---|
| `reprojection.py` | registration |
| `normalization.py` | normalisation |
| `weighting.py` | weighting |
| `rejection.py` | rejection |
| `integrate.py` | integration |
| `background.py` | background extraction |
| `presentation.py` | stretch / display transform |

Use those standard names. Calibration is absent because the Seestar does
bias/dark/flat on-device.

## What to build

### 1. A recipe document

Declarative: an ordered list of stages, each with `enabled` and typed
parameters. Version it from the start — `version: 1` — because this
document will outlive several of our opinions.

**Every stage is tagged `linear` or `display`.** Everything up to and
including integration is photometrically meaningful; the stretch is a
one-way door into display-referred data. Background extraction after a
stretch gives a different and usually wrong answer, and photometry on
stretched pixels is meaningless.

The model must make that boundary explicit and refuse a recipe that puts
a `linear` stage after the transition. That single constraint prevents
the most common way to produce a technically valid but scientifically
worthless master.

Do **not** build a general DAG. The stage order is standard; a fixed
sequence with enable flags and parameters is what the domain actually
is, and it is far harder to misuse. Loosening later is easy; taking back
a free-form graph after people have built things in it is not.

### 2. The default must be byte-identical to today

If no recipe is supplied, the job behaves **exactly** as it does now.
This is the safety property that makes the change landable: prove it by
combining a real session both ways and comparing the output bytes, not
by reasoning about it.

Say in PR.md how you verified equality.

### 3. Plumb it through

- The operator passes the recipe to the Job. Follow the existing env
  contract (`combinejob/envvars.go`); a large document belongs in object
  storage with a key in the env, a small one can be inline — choose and
  justify.
- `envcontract_test.go` cross-checks the Go and Python sides by reading
  the Python source as text. It is the best test in this repo. **Extend
  it**, do not work around it.

### 4. Record the method with the result

Two places, for two audiences:

- **The FITS header**, alongside `provenance.py`'s existing
  `engine_versions()` — so the file is self-describing wherever it ends
  up.
- **The catalog**, against the `result` row — so the site can render a
  recipe line without opening an 88 MB file.

The recorded recipe must include the **image digest**, not just the
recipe body. Same recipe on a different build is a different method,
and that distinction is the whole point of recording it.

For the shape, look at the **IVOA Provenance Data Model** — the
astronomy standard for describing how data was produced. Follow it where
it is cheap to; say in PR.md where you deviated and why. We are not
implementing IVOA ProvDM, we are trying not to invent a worse version of
it.

### 5. Demonstrate the thing this exists for

Run **two different recipes over the same real session** and show the
difference. `m-13-2026-07-29` is in the archive: 359 subs, 4620s.

Vary one parameter — rejection kappa is the obvious candidate — and put
in PR.md both resulting masters' recorded recipes, and any measurable
difference. This is the capability that lets us find out empirically
whether parameters generalise, instead of arguing about it.

If you cannot run against real data from the sandbox, say so plainly and
show the same thing on synthetic input.

## Tests

- [ ] No recipe supplied → byte-identical output to the current build.
- [ ] A recipe that disables a stage produces a different, correct
  result — and the recorded recipe says that stage was off.
- [ ] A recipe placing a `linear` stage after the display transition is
  **rejected**, with an error naming the stage and the boundary.
- [ ] An unknown stage name is rejected, not skipped.
- [ ] An out-of-range parameter is rejected before any pixel is loaded —
  a two-hour job must not fail at minute 118 on a typo.
- [ ] The recipe recorded in the catalog matches the one in the FITS
  header, and both include the image digest.

## Warts / traps

- Do not add stages, and do not change any stage's maths. If a default
  looks wrong, note it in PR.md — changing behaviour and changing
  structure in one PR makes both unreviewable.
- Do not expose parameters to members. No site changes, no API.
- Do not touch enrolment, credentials, upload or the tailnet.
- `combine` is Python, gated by ruff and its own tests; the operator is
  Go. Both must stay green.
- The gate runs `-race -count=1` and now has Postgres and S3 legs.

Finish: `/workspace/PR.md` with the recipe schema, proof the default is
byte-identical, the linear/display rejection, the two-recipe comparison
over m-13-2026-07-29, and where you deviated from IVOA ProvDM.
