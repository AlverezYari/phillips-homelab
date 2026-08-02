# SPEC — gateway-jetstream-durability: poison loops, unbounded stream, tests that assert the opposite of production

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Closes issue **#128**. Scope: `gateway/internal/eventstream`,
`operator/internal/eventstream`, the publishers, and the handlers that
decide whether a message is retryable. A sibling loop is in
`loop-bot/tychofleet` — different repo, no overlap.

## Three defects, one theme: nothing bounds anything

### 1. Poison messages hot-loop forever

`eventstream.go:64-69` sets `AckExplicitPolicy` and `AckWait: 30s` but
**no `MaxDeliver` and no `BackOff`**, and `:84` is a bare `msg.Nak()`
with no delay. A message the handler always rejects redelivers in a
tight loop indefinitely — burning CPU and emitting an unbounded stream
of ERROR logs.

Reachable today: `sessionclose.go:128-131` (unknown `close_reason`) and
`results.go:110`.

The comment at `eventstream.go:76-80` records the lesson from a prior
*silent* poison message. The fix applied then was logging, not
stopping.

### 2. The stream has no retention

`eventstream.go:44-47` creates it as `StreamConfig{Name, Subjects}` —
default `MaxAge=0`, `MaxBytes=-1`, and nothing in `deploy/` overrides
it. Meanwhile `tycho.ingest.sub.accepted` embeds the **entire FITS
header map per frame** (`upload.go:448`). It grows without bound on a
5Gi file store.

### 3. Dedup is off, and the tests assert the opposite

Neither publisher passes `jetstream.WithMsgID`, so production is
**at-least-once**. Meanwhile `upload_test.go:406` asserts *exactly one*
`SubjectAccepted` after a retry, and `:125,:294,:565,:791,:847` assert
exact counts.

A lost `PubAck` double-counts a frame in the scorer and fleetview — and
the suite is pinned to the belief that this cannot happen. **The tests
assert the opposite of what production provides.**

## What to build

### 1. Bound redelivery

`MaxDeliver` and a backoff, and `NakWithDelay` rather than a bare
`Nak()`. Choose the numbers and justify them: how long should a
transient failure keep retrying before we stop?

### 2. Terminate what can never succeed

A payload that cannot be decoded, or names a `close_reason` that does
not exist, will not succeed on the thousandth attempt either.
`msg.Term()` those.

**Be careful about the boundary.** "Cannot decode" is terminal; "the
database is down" is not. Getting this wrong in the terminal direction
silently drops real events — worse than the hot loop. Say in PR.md
exactly which conditions you made terminal and why each can never
succeed on retry.

### 3. Retention on the stream

`MaxAge` and/or `MaxBytes`. Say what you chose and what it means: how
long can a consumer be down before it misses events permanently? That
is the real question, and the answer should be stated in PR.md in
those terms, not as a byte count.

Note the operator is the consumer of record, and `RecordResult`'s
revision guard makes redelivery safe — so the cost of a *shorter*
window is bounded and knowable.

### 4. Settle dedup versus the tests

Either add `jetstream.WithMsgID` so exactly-once is real, or change the
tests to stop asserting a guarantee production does not provide.

**Prefer the first**, since the consumers already assume it: the
scorer and fleetview count frames. But say which you chose. What is
unacceptable is leaving the two in disagreement, because that
disagreement is invisible until it double-counts a member's night.

## Tests

- [ ] A message that always fails is redelivered a bounded number of
  times and then stops. Assert the bound, not just that it stops.
- [ ] An undecodable payload is `Term()`ed and not redelivered.
- [ ] A **transient** failure is still retried — the regression that
  would make this change dangerous.
- [ ] If you add `WithMsgID`: a duplicate publish of the same logical
  event results in one delivery.
- [ ] Retention is set on the stream as configured — assert against
  the stream info, not the constant.

Three packages already run against a real in-process JetStream server;
use that rather than a fake.

## Warts / traps

- Do not change event payloads or subject names — consumers depend on
  them, and `schematest` validates them against schemas the emitting
  module does not own.
- `operator/internal/eventbus/nats_test.go:24,33` binds stream
  `JOB_EVENTS` / `tycho.job.>` while production is `TYCHO_EVENTS` /
  `tycho.>`. `JOB_EVENTS` appears nowhere else in the repo. Keep the
  real-server pattern, fix the name.
- Do not touch `operator/internal/controller` or
  `sessionclose.go`'s `Failed` handling — issue #51 is next and will
  collide.
- The gate runs `-race -count=1` by default.

Finish: `/workspace/PR.md` with your redelivery bound and why, the
exact list of terminal conditions, retention expressed as "a consumer
can be down for X", and your dedup decision.
