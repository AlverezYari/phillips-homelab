# SPEC — gate-race-detector: `-race` is red, and nothing runs it

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

## The failure

`go test -race ./agent/...` **fails, reproducibly, today**:

```
--- FAIL: TestEnrolMode_TailnetAuthKeyNeverLeaks
    testing.go:1712: race detected during execution of test
```

Nothing runs it. `Makefile:74` is `go test ./agent/... ...` with no
`-race`. `ci/main.go:41-42` drops it deliberately — *"alpine's musl
lacks the C toolchain CGO needs; race detection runs locally via
`go test -race`"* — and it does not run locally either, so the failure
has simply been sitting there.

## Why this is more than a flaky test

The race is **in the tests that certify our three secrets never leak.**

`enrolmode_test.go:1391` declares `var logBuf bytes.Buffer`, hands it to
`slog.NewTextHandler` *and* `slog.SetDefault`, then reads
`logBuf.String()` at `:1449` while pipeline goroutines are still writing
to it. The assertion *"the boot log must not contain the tailnet auth
key"* is therefore checked against a **torn, partially-written
snapshot** — a leak logged a millisecond later is silently missed.

Same pattern in the other two: `:501`/`:594` (the per-scope secret) and
`:887`/`:993` (the device interop key). Those two pass only because
their `waitLoop` happens to quiesce the pipeline first. That is luck,
not synchronisation. All three read the buffer *before* their deferred
`cancel()` + `p.Wait()`.

So the three tests standing between us and a leaked credential cannot
reliably see one.

**The correct pattern already exists, unused, in the same package:**
`syncBuffer` at `headless_test.go:21-36`.

## What to build

### 1. Fix the three races

Use `syncBuffer` (or an equivalent mutex-guarded writer) for all three,
and read the buffer **after** the pipeline has stopped — deferred
`cancel()` and `Wait()` must happen before the assertion, not after.

Do not weaken the assertions to make the race go away. The tests must
still walk the whole buffer tree, the config file, and the rendered TUI
frames.

Check for the same pattern anywhere else a test shares a buffer with a
running goroutine.

### 2. Put `-race` in the gate

- A `make` target that runs the Go suite with `-race`, and `make test`
  must reach it locally. Say in PR.md whether you made it the default or
  a separate target, and why.
- **CI: add a `-race` leg rather than dropping the check.** The current
  reason is real — musl lacks the CGO toolchain — so the fix is a
  glibc-based job (a `golang:` image rather than alpine), not disabling
  race detection. If the existing runner genuinely cannot host that, say
  so explicitly in PR.md with what you tried; do not quietly leave the
  gate as it is.
- Add `-count=1` where it matters: `make test` can currently serve
  entirely cached results.

### 3. Correct the comments that are now false

`ci/main.go:41-42` claims race detection "runs locally via `go test
-race`". It does not, and that sentence is why nobody checked. Whatever
you end up with, the comment must describe what actually happens.

## Tests

- [ ] `go test -race ./agent/...` passes.
- [ ] The three leak tests still fail if a secret *is* leaked — prove
  it. Temporarily log the secret in a scratch build, confirm each test
  catches it, then remove that. Describe the exercise in PR.md. A leak
  test that cannot fail is worse than no leak test, and that is exactly
  what we have had.
- [ ] `-race` is reachable from the documented gate command.

## Warts / traps

- Do not touch `gateway/`, `operator/` or the catalog — a sibling
  effort covers Postgres in CI and will collide.
- Do not change production code to silence a test race. If a race is in
  production code, that is a finding: report it in PR.md prominently
  rather than papering over it.
- `docs/MATURITY.md` and `docs/dev/testing.md` describe the gate's blind
  spots. If you change what the gate covers, they must change too —
  `MATURITY.md:37` is already wrong about the skip count.

Finish: `/workspace/PR.md` with the race fixed and `-race` output
attached, the proof each leak test can still fail, what you did about
CI, and every comment you corrected.
