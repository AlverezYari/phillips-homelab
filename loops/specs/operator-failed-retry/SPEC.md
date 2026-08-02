# SPEC — operator-failed-retry: a target that fails once is never mastered again

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Closes issue **#51**, open since 2026-07-19 and independently
re-confirmed by a senior review. Scope: `operator/` only. A sibling
loop is in `loop-bot/tychofleet` — different repo, no overlap.

## The failure

**Two defects that compound into "no master, ever".**

### 1. `Failed` is terminal, permanently

`sessionclose.go` returns `nil` immediately when a session's phase is
`Failed`. A combine that failed for a transient reason — node OOM, an
image pull, an S3 blip — parks that session forever. New subs,
re-closes and redeliveries all no-op. The only signal was a one-shot
ntfy.

The original report (2026-07-19) is a live instance: an M13 session
first combined at 14 subs and failed, then grew to **169 subs** and
re-closed cleanly, and the operator did not spawn anything.

### 2. Nothing ever requeues

`RequeueAfter` appears in exactly **one** file in the whole operator —
`seestar_controller.go`, for staleness. Nowhere else.

`ensureCombine` (`combine_trigger.go:94-101`) defers when a combine is
already `Combining`, on the assumption that "the next trigger
re-evaluates". But the only trigger is **another session closing for
that target**, and `markDone`'s calls to `ensureMasterCombine` /
`ensureFleetCombine` are best-effort log-and-drop
(`combine_controller.go:240-249`).

So: shoot a target three nights, have the master spawn fail once, never
shoot that target again → **no master, ever**. Nothing in the system
will ever revisit it.

## What to build

### 1. Bounded retry for `Failed`

A `Failed` session must be retryable — but not infinitely, and not
instantly. Add attempt tracking (a `Status.Attempts` field or
equivalent) and a bounded retry with backoff.

Say in PR.md: how many attempts, over what period, and what happens
when the bound is exhausted. A permanently-failed session should end up
in a state a human can **see and act on**, not a silent dead end. That
is the actual bug — not that it failed, but that nothing said so and
nothing tried again.

### 2. Re-evaluate combinable sets on a timer, not only on a trigger

The senior review's suggestion: move combinable-set evaluation into
`MasterCombineReconciler.Reconcile` — which **already watches
`TargetMaster`** — with a modest `RequeueAfter`.

That way a master that failed to spawn gets another chance without
requiring a new session to close for that target.

Pick the interval deliberately. Too tight and the operator busies
itself re-evaluating sets that have not changed; too loose and a
member waits days. Say what you chose and why.

### 3. Do not make `markDone`'s best-effort calls load-bearing

`combine_controller.go:226-239` deliberately downgrades those to
log-and-continue, and that reasoning is correct — a master spawn
failing must not fail the session close. The fix is that **something
else** retries, not that those calls start returning errors.

## Tests

- [ ] A `Failed` session that grows and re-closes **does** spawn a new
  combine revision — the exact scenario from the 2026-07-19 report:
  fail at 14 subs, grow to 169, re-close, expect a spawn.
- [ ] Retry is bounded: after N attempts it stops, and the terminal
  state is observable.
- [ ] A master whose spawn failed is retried by the requeue path
  **without** a new session closing. This is the second half and the
  one most likely to be skipped.
- [ ] A healthy session is unaffected — no extra spawns, no churn.
  Assert this; a retry loop that re-combines working sessions would be
  worse than the bug.

**`operator/fullloop_test.go` constructs `CombineJobReconciler` without
`Scheme`**, which trips an early `return nil` in the master and
fleet-master trigger paths — silently disabling exactly the paths this
loop touches inside the test that claims to cover the full loop. #139
may have addressed this; check, and say in PR.md what state you found
it in and whether your tests actually exercise those paths.

## Warts / traps

- Do not touch `gateway/`.
- Do not change event payloads or subjects.
- Idempotency is what makes retry safe: `RecordResult`'s revision
  guard already handles redelivery. Do not weaken it.
- Retrying must not create duplicate `TargetMaster` objects or
  duplicate Jobs — revision numbering exists for this; use it.
- The gate runs `-race -count=1` by default.

Finish: `/workspace/PR.md` with your retry bound and interval and the
reasoning for both, what a permanently-failed session looks like to a
human, and the 14-subs-to-169-subs scenario passing.
