# SPEC — combine-build-identity: make the recorded digest identify the build

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Closes issue **#156**.

## The problem, proven

`provenance.engine_digest()` is `sha256(engine_versions())`. Comparing
the M13 master before and after yesterday's re-reduction:

```
r5 (pre-floor, 70-commit-stale container):
  ENGINEV = tycho-combine 0.1.0, astropy 8.0.1, reproject 0.21.0, numpy 2.4.6
r6 (current build, different reduction behaviour):
  ENGINEV = tycho-combine 0.1.0, astropy 8.0.1, reproject 0.21.0, numpy 2.4.6
```

Byte-identical, so the digest is identical. **Two masters differing by
20% in integrated star flux and 9.9% in colour balance carry the same
"build identity."**

`tycho-combine` has been version `0.1.0` for the project's entire life.
The only thing that currently moves this digest is bumping astropy,
reproject or numpy. It identifies a **dependency set**, not a build.

ADR 0008/#148 justified recording it as: *"Same recipe on a different
build is a different method, and that distinction is the whole point of
recording it."* The field does not support that claim today.

## What to build

### 1. Bake the git SHA into the image

`combine/Dockerfile` takes no build args today, and `image-combine` is a
plain `docker build`. Add a build arg carrying the commit, have the
Makefile pass it (`TAG` is already `git rev-parse --short HEAD`), and
expose it to the running container.

### 2. Fold it into the digest, and never fake it

`engine_digest()` must incorporate the build commit.

**If the commit is not available, say so — do not silently fall back**
to the dependency-only hash. An unknown build must be recorded as
unknown, visibly, so a reader can tell "built from an untracked tree"
from "built from commit abc1234". Silently degrading to the old
behaviour would reproduce this exact bug in a form nobody can detect,
which is the whole reason this issue exists.

Local `make image-combine` runs and dev runs from a source checkout are
legitimate unknown-build cases. Decide what they record and justify it
in PR.md.

### 3. Name it for what it holds

If the value ends up containing both dependency versions and a commit,
`engine_digest` is defensible. If it becomes only a commit, name it so.

This area has now had three naming failures — `image_digest` that was
not an image digest, a `COMBINE_IMAGE` comment crediting unrelated PRs,
and `engine_digest` implying a build identity it does not provide.
Whatever you choose, the name must describe the contents.

### 4. Recorded-recipe compatibility

Exactly one master in the archive currently carries a recipe
(`masters/m-13/master.fit`, from yesterday). Changing the digest format
is therefore nearly free — but the recipe document is versioned
(`version: 1`) and this changes the meaning of a recorded field.
Decide whether that warrants `version: 2` and justify it either way.

## Tests

- [ ] Two builds from different commits produce different digests, with
  everything else held constant. Assert on the digest function, not on
  a real build.
- [ ] Identical commit + identical dependencies produce an identical
  digest — it must stay deterministic.
- [ ] The unknown-build case is recorded distinguishably, and a test
  asserts you cannot mistake it for a known build.
- [ ] `envcontract_test.go` still cross-checks Go and Python if you add
  an env var. Extend it, do not work around it.
- [ ] The combine image still builds: `make image-combine`.
- [ ] Pixel output is unchanged. This touches provenance only — the
  `RECIPE`/`ENGINEV` cards may change, no pixel may. Prove it on the
  committed fixtures.

## Warts / traps

- **Do not touch the reduction.** No change to background,
  normalization, weighting, rejection, integration or reprojection.
- Do not change the rejection floor (#151, just landed) or
  `reproject_interp` (#152, open).
- The fixtures in `combine/tests/fixtures/real/` are real sky data;
  tests must keep passing with **0 skips**.
- `make venv-combine` now defaults to a repo-relative path.

Finish: `/workspace/PR.md` with the before/after digest for two
different commits, what an unknown build records and why, the naming
decision, the recipe-version decision, and proof no pixel moved.
