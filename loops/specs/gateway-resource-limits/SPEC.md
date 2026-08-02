# SPEC — gateway-resource-limits: a client-declared number allocates gateway memory

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Closes issue **#129**. Scope: `gateway/` and `deploy/gateway/`. A
sibling loop is in `operator/` — stay out.

## The failure

`storage/s3.go` reads a part with:

```go
buf, err := io.ReadAll(io.LimitReader(body, size))
```

where `size` is `r.ContentLength` (`upload/http.go:122`) — **entirely
client-supplied**, capped nowhere. `upload.go:115-120` states plainly
that the gateway does not enforce `partSize`.

The comment above that line claims *"Bounded at one protocol part
(8MiB)"*. It is false. A request declaring
`Content-Length: 8000000000` makes the gateway allocate 8 GB in a
single buffer.

**And `deploy/gateway/deployment.yaml` has no `resources:` block at
all**, so that OOMs the node rather than the pod. With `replicas: 1`,
the node it lands on is the whole ingest path.

Related, same class:

- `grep MaxBytesReader gateway/ operator/` → **zero hits**. Every JSON
  handler streams an unbounded body, including `POST /v1/enrol` — the
  one deliberately unauthenticated write in the system.
- `main.go:232-236` sets only `ReadHeaderTimeout`. No `WriteTimeout`,
  no `IdleTimeout`. Part uploads legitimately run for minutes over
  flaky links, so stalled connections accumulate with nothing to reap
  them.

This is an availability problem before it is a security one, and the
unauthenticated enrol endpoint makes it reachable without a credential.

## What to build

### 1. Reject oversized parts before allocating

A declared size beyond what the protocol permits is a **413**, refused
before any allocation. `partSize * 2` is a reasonable ceiling; pick one
and justify it — the point is that a client cannot name a number that
becomes a buffer.

Delete the comment claiming it is already bounded. It is exactly the
kind of confident-and-wrong comment this project has been removing all
week.

### 2. Bound every request body

`http.MaxBytesReader` on every handler that reads one. `POST /v1/enrol`
matters most: unauthenticated, and a code is a fixed 14 characters, so
its limit can be very small.

### 3. Server timeouts

`WriteTimeout` and `IdleTimeout` on the `http.Server`. Choose values
that do not break a legitimate slow part upload over a bad connection —
say what you chose and why. A too-aggressive `WriteTimeout` here would
break exactly the members this system exists for.

### 4. Container resources

`requests` and `limits` in `deploy/gateway/deployment.yaml`. Base them
on something: the part ceiling, the concurrency, and observed usage if
you can find it. Say how you arrived at the numbers.

Consider a concurrency semaphore on part uploads, so N concurrent
uploads cannot each allocate the ceiling simultaneously. If you add
one, its limit and the memory limit must be consistent with each other,
and say so.

## Tests

- [ ] A request declaring a `Content-Length` above the ceiling is
  refused with 413 **before** any storage call — assert the storage
  call did not happen.
- [ ] A legitimate part at the normal size still succeeds unchanged.
- [ ] An oversized body to `/v1/enrol` is refused.
- [ ] A body whose declared length exceeds what it actually sends is
  handled without hanging — note `s3.go`'s `io.ReadAll` currently
  returns a **short buffer with nil error** and then declares the full
  size, which is a real divergence from `Mem`'s `io.ReadFull`.

`storage/s3.go` can now be tested against a real MinIO in CI
(`TYCHO_TEST_S3_ENDPOINT`, added in #137) — use it.

## Warts / traps

- Do not weaken checksum verification.
- Do not change the upload protocol shape — resumability is the reason
  it exists and works.
- Do not touch `operator/` — a sibling loop is there.
- The gateway currently runs `replicas: 1`. Do not change that here;
  if your reading is that it should be higher, say so in PR.md as a
  recommendation.
- The gate runs `-race -count=1` by default.

Finish: `/workspace/PR.md` with the ceiling you chose and why, the
timeout values and their justification, the container numbers and how
you derived them, and proof that an oversized declaration never reaches
storage.
