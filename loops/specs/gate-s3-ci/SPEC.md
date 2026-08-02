# SPEC — gate-s3-ci: the storage that runs in production is untested

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Closes issue **#135**. Scope: `ci/`, the `Makefile`, `docs/dev/`, and
whatever `gateway/internal/storage` needs to be reachable. A sibling
loop is in `gateway/internal/catalog` — stay out of it.

## The failure

PR #134 added `gateway/internal/storage/contract_test.go`, which runs
the same behavioural assertions against `Mem` and `S3Storage` so a
divergence between the fake and production fails in CI. It is a good
test and it closed three real divergences.

**Its S3 half never runs.** It skips unless `TYCHO_TEST_S3_ENDPOINT` is
set, and nothing sets it:

- not the `Makefile`, which has a loud warning block for
  `TYCHO_TEST_DATABASE_URL` and nothing for S3
- not `ci/main.go`, which now runs a Postgres service — so the pattern
  exists and was simply not applied
- not `docs/dev/testing.md`, the document whose entire job is
  enumerating the gate's blind spots

So the half of the contract test covering **the implementation that
actually runs in production** never executes anywhere, and
`storage/s3.go` stays at 0% coverage.

This is the same shape as the eight Postgres tests that skipped
silently for months, fixed this morning in #124 — reintroduced on the
very next PR. Not the loop's fault: it copied the
`TYCHO_TEST_DATABASE_URL` convention faithfully, and that convention
was silent until today. **Conventions propagate faster than fixes**,
which is why this one needs closing rather than noting.

## What to build

### 1. An S3-compatible service in CI

Same shape as the Postgres service in `ci/main.go`. MinIO or Garage —
pick one and say why. Set `TYCHO_TEST_S3_ENDPOINT` (and whatever
region/bucket/credentials the test needs) alongside
`TYCHO_TEST_DATABASE_URL`.

The bucket must be **disposable and created by the test setup**, not
assumed to exist.

### 2. A loud skip when it is absent

Match the Postgres banner in the `Makefile` exactly — same shape, same
`STRICT=1` hard failure. A developer running `make test` without a
bucket must be told, in the same words, that a real part of the gate
did not run.

### 3. Correct the blind-spot docs

`docs/dev/testing.md` must list S3 alongside Postgres. If
`docs/MATURITY.md` states coverage or skip counts, they change too.

Be exact. That file was wrong about the Postgres skip count for weeks
("three Go tests skip" when it was eight across six files), which is
part of why this class of gap survived.

### 4. Verify the contract test actually finds something

With the S3 leg running, confirm `Mem` and `S3Storage` genuinely agree
on the assertions in that file. If a divergence surfaces, **that is the
finding** — report it prominently in PR.md rather than adjusting the
test to pass. The three already closed (short-read handling, minimum
part size, `StatObject`'s missing error path) suggest there may be
more.

## Tests

- [ ] `TYCHO_TEST_S3_ENDPOINT` set → the S3 leg of `contract_test.go`
  runs and passes. Paste the output in PR.md — `--- PASS` lines naming
  the S3 subtests, not a summary.
- [ ] Unset → a loud banner, and a hard failure under `STRICT=1`.
- [ ] `storage/s3.go` coverage is no longer 0%. State the number.

## Warts / traps

- Do not weaken any assertion in `contract_test.go` to make the S3 leg
  pass. If production behaves differently from the fake, production is
  the fact and the fake is wrong — unless the fake encodes what we
  *want*, in which case that is a bug in `s3.go` and a separate issue.
- Do not touch `gateway/internal/catalog` — a sibling loop is there.
- The gate runs `-race -count=1` by default. Keep it.
- CI is offline apart from services it starts itself. A test that
  reaches the public internet will not run.

Finish: `/workspace/PR.md` with the S3 subtests passing, the coverage
number for `s3.go`, the loud-skip banner, the corrected blind-spot
docs, and any divergence the newly-running leg exposed.
