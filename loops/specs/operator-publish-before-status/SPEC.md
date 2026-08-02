# SPEC — operator-publish-before-status: the requeue can never republish

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Closes issue **#127**. Scope: `operator/` only. A sibling loop is in
`gateway/internal/storage` and `gateway/internal/upload` — stay out.

## The failure

Every terminal-state reconciler commits the phase transition and *then*
publishes:

```
Status().Update(...)   // phase := Done
publish(...)           // fails
return err             // requeue
```

The requeued Reconcile hits a guard at the top that returns `nil`
unless the phase is `Combining` — sees the phase it just wrote — and
no-ops. **The event is lost permanently and nothing retries.**

Six sites:

| controller | update → publish | guard |
|---|---|---|
| `combine_controller.go` | `:195→220`, `:265→286` | `:90` |
| `master_controller.go` | `:137→184`, `:196→218` | `:83` |
| `fleetmaster_controller.go` | `:138→180`, `:231→253` | `:100` |

`master_controller.go:184` is the costly one — `tycho.job.master.succeeded`
carries `input_keys`, the **only** source of `combine_input` provenance.
Lose it and a master exists with no record of which sessions built it.

Same shape in `sessionclose.go:328-333`: `created=false` on redelivery
skips `publishJobStarted` forever.

`combine_controller.go:226-239` describes this exact hazard for
`ensureMasterCombine` and correctly downgrades it to log-and-continue —
then leaves `:220` returning the error. The reasoning was right and was
applied in one place out of seven.

## Why it was never caught

`eventbus/mem.go` declares a `PublishErr` fault-injection hook in
**both** gateway and operator.

```
grep -rn "PublishErr" --include='*_test.go'   →   nothing
```

The hook exists. Someone built it. Nobody wired it up. So every
publish-failure branch in the operator is dead code under test. Four of
seven fault hooks in the gateway fakes are similarly dead.

## What to build

### 1. Publish before the status update

The consumer is already idempotent — `RecordResult`'s revision guard
(`postgres.go:479`) makes a redelivered event safe. So publishing
first, then committing the phase, means a publish failure requeues into
a Reconcile that still sees `Combining` and retries properly.

If you find a site where publishing first is genuinely wrong — an event
that must not be emitted unless the transition committed — **say so in
PR.md and use `Status.PublishedRevision`** (or an equivalent) to gate
the guard instead. Do not silently leave one of the seven unfixed; that
is how this survived.

### 2. Fix `sessionclose.go`'s redelivery case

`created=false` must not mean "never publish". Decide what redelivery
should do and say why.

### 3. Wire up `PublishErr`

Use the hook that already exists. Every one of the seven sites needs a
test where the publish fails and the event is **still delivered after a
requeue**. That is the whole point — not that an error is returned, but
that the event eventually arrives.

## Tests

- [ ] For each of the six controller sites: publish fails once, the
  reconcile requeues, and on retry the event **is published**. Assert
  on the event reaching the bus, not on the error.
- [ ] `sessionclose.go`'s redelivery path publishes.
- [ ] The idempotency the fix relies on holds: a duplicate
  `master.succeeded` does not corrupt `combine_input`.
- [ ] Existing behaviour is unchanged when publishing succeeds first
  time — assert it, since this reorders the happy path.

**Note `operator/fullloop_test.go:170,302` construct
`CombineJobReconciler` without `Scheme`**, which trips an early
`return nil` at `master_trigger.go:92-94` and
`fleetmaster_trigger.go:123-125` — silently disabling the master and
fleet-master spawn paths inside the test that claims to cover the full
loop. If your change touches those paths, that test will not tell you.
Say in PR.md whether you fixed it or worked around it.

## Warts / traps

- Do not touch `gateway/` — a sibling loop is there now.
- Do not change event payloads or subjects; consumers depend on them.
- `RequeueAfter` appears exactly once in the whole operator
  (`seestar_controller.go:75`). Related to issue #51 but **not this
  loop** — do not fix it here, and do not make it harder to fix later.
- The gate runs `-race -count=1` by default.

Finish: `/workspace/PR.md` with the seven sites and what each does now,
the `PublishErr` tests, and your answer on `fullloop_test.go`.
