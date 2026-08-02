# SPEC — gateway-upload-integrity: the one path that destroys photons

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Closes issue **#125**. Scope: `gateway/internal/storage/` and
`gateway/internal/upload/`.

## The failure

`storage/s3.go` takes the upload token and throws it away — the
parameter is literally `_`:

```go
func (s *S3Storage) UploadPart(ctx context.Context, key, _ string, partNumber int32, body io.Reader, size int64) (string, error)
func (s *S3Storage) ListParts(ctx context.Context, key, _ string) ([]PartInfo, error)
```

The file says so itself (`:42-46`): *"ErrTokenConflict is therefore
never returned by this implementation; it exists for Mem-backed tests,
which document the intended protocol semantics precisely."*

So the tests exercise a protocol the production storage does not
implement. Two uploads to the same object key share one multipart
upload, parts overwrite by number, and `CompleteUpload` assembles an
interleaved object.

**The checksum catches the corruption — after `assembleObject`
(`upload.go:377`) has already overwritten whatever was at that key.**
`InsertSub` then returns `ErrDuplicateSub` (`postgres.go:316`), so the
response reads as a benign duplicate.

This is the only path in the system that destroys data and reports
something success-adjacent. A night of photons cannot be recaptured.

## Two more defects in the same file

- **`StartUpload` (`s3.go:95-111`) is check-then-create.** Concurrent
  starts create two upload ids, and `resolveUploadID` picks
  non-deterministically.
- **Abandoned multiparts are never reaped.** A week-old partial upload
  is silently *resumed* on the next attempt for that key, producing an
  object built from two different capture attempts.

## What to build

### 1. Never overwrite an object that already has a catalog row

Before assembling, check whether the destination already exists **and**
whether the catalog holds a row for it with a different checksum. If so,
refuse — do not assemble, do not overwrite.

Say in PR.md what the caller sees, and make sure it is distinguishable
from the benign duplicate case. "Already uploaded, identical" and
"already uploaded, different bytes" are completely different facts and
must not share a response.

### 2. Honour the upload token, or delete the concept

Decide deliberately and say why in PR.md:

- **Implement it** — persist the token (object metadata, or a catalog
  column) and return `ErrTokenConflict` when a second writer appears.
- **Or delete it** — remove `ErrTokenConflict` and the dead 409 branch,
  and stop the `Mem` fake asserting a protocol that does not exist.

What is not acceptable is leaving a fake that documents a guarantee the
real implementation does not provide. That exact shape — a test double
enforcing more than production — is how the unauthenticated upload path
survived a full day of green builds last week.

### 3. Make `StartUpload` not race

Concurrent starts for one key must converge on one upload id, or fail
cleanly. Non-deterministic selection is not acceptable.

### 4. Reap abandoned multiparts

An incomplete multipart older than some age must not be silently
resumed. An S3 lifecycle rule is one answer, an age check at resume is
another; either is fine if you say which and why. Note the lifecycle
rule is infrastructure, not code — if that is your answer, state
exactly what an operator must configure.

## Tests

- [ ] Two uploads to the same key with **different content** do not
  produce an interleaved object, and the second is refused rather than
  silently assembled over the first.
- [ ] A genuine retry of the **same** content still succeeds — the
  resume path is the reason this protocol exists and must not regress.
- [ ] Concurrent `StartUpload` for one key converges deterministically.
- [ ] A stale abandoned multipart is not resumed.
- [ ] **`Mem` and `S3Storage` agree.** Add a shared contract test run
  against both, in the shape of
  `operator/internal/combinejob/envcontract_test.go` — which reads the
  Python source as text and asserts set-equality across a
  cross-language boundary, and is the best test in this repo. The
  reviewers found three divergences beyond the token:
  `Mem` uses `io.ReadFull` and errors on a short body while `s3.go:124`
  uses `io.ReadAll` (short read, nil error, then declares the full
  size); `Mem.StatObject` has **no error path at all**, so
  `upload.go:635-637`'s recovery branch is unreachable under test; and
  `Mem` accepts any part size while S3 requires ≥5 MiB for non-final
  parts.

`storage/s3.go` has **no test file at all** (226 lines, 0% coverage).
Postgres is now available in CI — use it.

## Warts / traps

- Do not change the agent or the client upload path.
- Do not weaken the checksum verification; it is the last line and it
  works.
- `Mem.CallCount()` returns `len(uploads) + len(objects)` — it counts
  **state, not calls** — while being asserted under the words *"assert
  the storage call did not happen"*. If you touch it, make it count
  calls or stop claiming it does.
- `docs/adr/**` is a record; `docs/specs/**` likewise.

Finish: `/workspace/PR.md` with your token decision and why, what a
caller sees for each of the three collision cases, the shared
`Mem`/`S3Storage` contract test, and what an operator must configure.
