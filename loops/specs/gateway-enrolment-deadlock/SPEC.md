# SPEC — gateway-enrolment-deadlock: two paths, two locks, opposite order

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Closes issue **#130**. Scope: `gateway/internal/catalog/postgres.go`
and its tests. A sibling loop is in `ci/` and
`gateway/internal/storage` — stay out of both.

## The failure

Two code paths take the same two row locks in opposite order:

- **`IssueEnrolmentCode`** (`postgres.go:159-196`) locks `source` first
  (`:167` `SELECT revoked_at FROM source WHERE id = $1 FOR UPDATE`),
  then takes row locks on `enrolment_code` via `:183`
  `DELETE FROM enrolment_code WHERE scope_id = $1 AND redeemed_at IS NULL`.
- **`RedeemEnrolmentCode`** (`postgres.go:205-249`) locks
  `enrolment_code` first (`:216` `... WHERE code_hash = $1 FOR UPDATE`),
  then `source` (`:229`).

For one scope X with one live unredeemed code C:

| | T1 = Redeem(C) | T2 = Issue(new code for X) |
|---|---|---|
| 1 | `BEGIN`; locks `enrolment_code` **C** | |
| 2 | | `BEGIN`; locks `source` **X** |
| 3 | wants `source` X → **blocks on T2** | |
| 4 | | must lock code **C** → **blocks on T1** |

Postgres aborts one transaction with SQLSTATE 40P01 after
`deadlock_timeout`. Neither path retries, so it surfaces as a **500**
through `scope/http.go:172-175`'s default branch.

**It happens with a single site instance** — it needs two concurrent
*requests*, not two replicas. Realistic trigger: an owner clicks
"regenerate code" on their deck at the same moment their agent redeems
the previous one. Agents retry, so an in-flight redemption is normal.

Severity is moderate, not urgent: the window is milliseconds, the
outcome is a 500 rather than corruption, and both operations are safely
retryable. It is worth fixing because it is cheap and because a 500 on
enrolment is a support ticket nobody can diagnose.

## What to build

Make both paths acquire the locks in the same order.

The suggested fix is a **two-line reorder**: in `IssueEnrolmentCode`,
move the `DELETE` (`:183`) above the `SELECT ... FOR UPDATE` on
`source` (`:167`), so both paths take `enrolment_code` before `source`.
The revoked check stays correct — it is still inside the same
transaction, so a revoked scope rolls back and undoes the DELETE.

If you would rather not reason about lock order at all,
`SELECT pg_advisory_xact_lock(hashtext($scope_id))` as the first
statement in both functions is equally cheap and obviously correct.
Either is acceptable; **say which you chose and why**.

Whatever you choose, leave a comment at both sites stating the ordering
invariant and what breaks if a future edit reverses it. That comment
earns its place under the project's own rule: it names a constraint the
type system cannot hold, and the failure it prevents.

## Tests

This is the hard part, and it is the point of the loop.

- [ ] A **Postgres-backed** test that drives the two paths concurrently
  against the same scope and asserts neither returns a deadlock error.
  Postgres is now available in CI (#124), so this can be a real test
  rather than a thought experiment.
- [ ] Both operations still behave correctly under contention: exactly
  one redemption succeeds, the issued code is the live one afterwards,
  and a revoked scope is still refused.
- [ ] Say in PR.md whether your test **fails against the current
  ordering**. A concurrency test that passes before and after the fix
  proves nothing — demonstrate it catches the bug, the way the leak
  tests were made to prove they could fail.

**Note this is invisible to the in-memory fake by construction:**
`MemCatalog` takes one global mutex per method body (`mem.go:181`), so
no fake can express lock ordering. Delete `FOR UPDATE` from both
queries and every existing test still passes. Do not add a fake-level
test and call it covered.

## Warts / traps

- Do not change the enrolment protocol, the code format, TTLs, or
  hashing. This is a lock-ordering fix, nothing else.
- Do not remove `FOR UPDATE` — the row locks are load-bearing for
  single-use redemption, which is verified working in production.
- Do not touch `gateway/internal/storage` or `ci/` — sibling loops.
- The gate runs `-race -count=1` by default.

Finish: `/workspace/PR.md` with your chosen fix and why, the concurrent
test, and evidence that it fails against the current ordering.
