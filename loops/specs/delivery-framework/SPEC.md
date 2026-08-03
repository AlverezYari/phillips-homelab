# SPEC — delivery-framework: the CRDs and controller for outbound delivery

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Implements **ADR 0010** (`docs/adr/0010-outbound-delivery.md`). Read it
first, and read `docs/design/crowdsky-delivery-guards.md` — it is
authoritative for adapter behaviour and **wins on any conflict**.

## Scope

**Framework only. No CrowdSky adapter. No network calls. No real
credentials.**

Build the CRDs, the controller, the metering, the admission check, and
the adapter interface, proven end to end against an in-repo **fake
adapter**. The CrowdSky adapter is a later loop, after contract
fixtures exist.

The acceptance test for this loop is stated in ADR 0010:

> Nothing in the framework knows the word "CrowdSky" outside one
> adapter file.

In this loop there is no adapter file, so **the string must not appear
in any code you write at all** — only in docs and in the fake adapter's
test fixtures if genuinely useful. `grep -ri crowdsky operator/` over
your new code should return nothing.

## Why the CRD shape matters now

The guards audit found the far end has effectively no idempotency
against a machine client: its dup-check consults completed stacks only,
its finalize is not itself idempotent, and it has no per-file
uniqueness — a re-sent file is stacked twice and biases their
sigma-clip, corrupting their science invisibly.

**So `Delivery` status is load-bearing state, not a progress bar.** It
is the only idempotency in the pipeline, on either side. Three guards
therefore shape the schema, and this is the cheap moment to get them
right:

- **G1 — at-most-once per file.** An acknowledged file is never sent
  again, across retries, restarts and re-runs. The ack is recorded
  *before* the next file is sent.
- **G2 — commit is a commit.** The far end's commit response is
  persisted before anything acts on it. A commit whose response was
  lost is **ambiguous, not retryable**: terminal `Unknown`, for a
  human or a reconciler to resolve. Never a blind resend.
- **G8 — dedup by content.** The ledger keys on (chunk key, content
  hash), so a renamed duplicate is still a duplicate.

Design the status so an adapter *cannot* violate these — if the
interface makes "send a file without recording its ack" expressible,
the guard is a convention, not a guarantee.

## What to build

### 1. `DeliveryTarget` — member-scoped

Named destination: adapter kind, credential reference, artifact class,
per-target settings, enabled flag (**default off**).

Member-scoped, per ADR §2: a fleet owner must not be able to publish
another member's data by configuring a fleet. Whatever mechanism
enforces that, make it structural rather than a check someone can
forget.

### 2. `Delivery` — one per (session x target)

Phases, attempts, per-file state, bytes transferred, terminal states
including `Unknown`, and what the far end said.

`kubectl get delivery` must answer "what happened to that night's
frames" without reading logs. Follow the existing CRD conventions —
`imagingsession_types.go` and `targetmaster_types.go` are the models,
including their printer columns and status subresource use.

### 3. The controller

Reconciles both. Spawns a Job per delivery (frames are already in
object storage; the operator does the work, the agent is not involved).
Follow `combine_controller.go` / `combinejob` for the Job pattern,
env-contract and retry shape — that path is well-worn and its
`envcontract_test.go` discipline should extend here.

### 4. The adapter interface

A Go interface with **one** implementation in this loop: a fake that
records what it was asked to do. It must be possible to write an
adapter that is *incapable* of violating G1/G2/G8 — demonstrate that by
showing the fake attempting a double-send and being structurally
prevented, not merely asserted against.

### 5. Metering and admission — from the first commit

Per ADR §4/§5:

- every `Delivery` records bytes transferred, per artifact and total
- bytes attributable to **(member, target, period)** without joining
  through object storage
- **admission** refuses or queues a delivery that would exceed a
  member's allowance, with the limit named, **before a byte moves** —
  never mid-transfer
- caps on simultaneously-enabled targets per member and on delivered
  bytes per period, as **fields a plan raises**, not constants

A refusal must be legible to the member. Silent throttling is worse
than refusing.

## Tests

- [ ] An acknowledged file is not re-sent after a simulated crash and
  restart of the delivery Job. Assert on what the fake adapter
  received, not on internal state.
- [ ] A lost commit response leaves the Delivery terminal `Unknown`,
  and no retry path resends.
- [ ] A renamed duplicate of an already-acked file is not sent (G8).
- [ ] A delivery exceeding the member's byte allowance is refused at
  admission with the limit named, and the fake adapter receives
  **nothing**.
- [ ] Enabling more targets than the member's cap is refused.
- [ ] A `DeliveryTarget` cannot be pointed at another member's data.
- [ ] Bytes for a completed delivery aggregate correctly per (member,
  target, period).
- [ ] `envcontract_test.go`-style cross-check for any new Job env
  contract.
- [ ] Full gate green including `-race`, Postgres and S3 legs, 0 skips.

## Warts / traps

- **No network.** Nothing in this loop opens a socket to a third party.
- **No adapter for a real destination**, and no credential handling
  beyond a reference to a secret that the fake ignores.
- Do not touch combine, rejection, reprojection, or the recipe work.
- The `Delivery` ledger is the only idempotency that will exist. If a
  design choice trades ledger integrity for convenience, choose the
  ledger and say so in PR.md.
- CRD changes need `make manifests`/`generate` if the repo has them —
  check, and keep generated files in step.
- The gate runs `-race -count=1`; the Postgres and S3 legs must be
  exercised, not skipped.

Finish: `/workspace/PR.md` with the two CRD schemas and why each
guard-shaped field exists, how the interface makes G1/G2/G8
unviolatable rather than merely tested, the admission path with a
worked refusal, and confirmation that `grep -ri crowdsky` over your new
code returns nothing.
