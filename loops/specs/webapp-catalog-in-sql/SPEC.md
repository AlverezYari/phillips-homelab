# SPEC — webapp-catalog-in-sql: the database does the arithmetic, not Node

Repo: `loop-bot/tychofleet`. Gate: `make build test lint`.

Closes issue **#57**. A sibling loop is in `loop-bot/tycho` — different
repo, no overlap.

## The failure

Fine at one member. Fails at a thousand, and the symptom will look like
an outage rather than slowness.

**The `sub` table is pulled into Node and aggregated there.**
`attribution.ts:138-144` selects one row per sub so
`accumulatedIntegrationSecBySource` can compute a MAX per session **in
JavaScript**. That is:

```sql
SELECT source_id, session_id, MAX(totalexp_s) ... GROUP BY 1, 2
```

written as a 100k-row wire transfer. The same shape appears at
`catalog-stats.ts:107-112` (the **public** `/observer` page),
`:267-272` (every `/scopes` deck load), `:622-629`, `:1164-1177`,
`:1522-1530`.

**And a hidden O(n²):** `integrationSecForFrames`
(`catalog-stats.ts:758-765`) full-`.filter()`s all session rows, and is
called *inside loops* at `:889-895` (once per enrolled source) and
`:492-498` (nested in `masters.map`). 1000 sources × 100k rows = 10⁸
comparisons on a single-threaded event loop, blocking every other
request.

**Why the symptom misleads:** each of these blows the 500 ms catalog
budget, so the page renders *"Catalog unreachable — numbers paused"* —
indistinguishable from the database actually being down.

## The stated contract, and why it needs revisiting

`catalog/attribution.ts:120-131` states the design as *"SQL narrows,
TypeScript decides."* That was a reasonable rule when the concern was
keeping arithmetic testable. It stops being reasonable when "narrows"
means "returns every frame".

Keep the testability. Aggregation that is genuinely a **decision** —
the per-session cap, how sources are grouped — can stay in TypeScript
and stay unit-tested. What must move is the **reduction**: SQL should
return one row per (source, session), not one per frame.

Say in PR.md how you preserved the testability the original rule was
protecting.

## What to build

### 1. Push the reduction into SQL

`SUM` over sessions of `MAX(totalexp_s)` is expressible directly. The
per-session cap is the whole point of the rule and must be preserved
exactly — it exists because a scope's reported integration time is a
running total, so summing every reading double-counts.

**The number must not move.** `seestar-1` currently totals
**3353010** seconds across 8 sessions and 798 subs. That figure is
rendered on the public attribution page. Verify before and after and
put both in PR.md.

### 2. Kill the quadratic filter

`integrationSecForFrames` called inside a loop is the worst offender.
Index the data once, or push the grouping into the query.

### 3. Add the missing indexes

**No non-unique index exists in the schema** — every index is a side
effect of a `UNIQUE` constraint, and no foreign key is indexed. On hot
paths:

| column | used by |
|---|---|
| `team_members.member_id` | every authenticated page |
| `fleet_members.principal_type, principal_id` | every deck render |
| `enrollments.member_id` | deck, observer, profile |
| `members.scope_id` | public `/observer/<id>` — full member scan |
| `campaigns.fleet_id`, `campaign_targets.campaign_id` | the N+1 loops |

These are SQLite (site) indexes; the catalog is read-only from here, so
do **not** add indexes to Postgres in this repo.

### 4. Gallery slugs — flag, do not fix

`assignGallerySlugs` (`gallery.ts:28-40`) derives its dedupe suffix
from the **global** master set, so published `/gallery/<slug>` URLs are
a function of every fleet's catalog state. That is a real problem and
it is **not this loop** — it needs a stored identity for masters and
is its own change. Note in PR.md whether your work makes it better,
worse, or neither.

## Tests

- [ ] Per-source integration totals are **identical** before and after
  for the real data shape — the per-session cap must survive.
- [ ] A source with multiple sessions on one night is capped per
  session, not summed per frame.
- [ ] The existing degraded-catalog behaviour is unchanged: a failed
  read still renders `--`, never `0h 00m`.
- [ ] Add a test that would notice the quadratic path returning —
  assert on query count or row count, not on wall-clock time.

## Warts / traps

- The catalog is **read-only** from this repo. No writes, no
  migrations against Postgres.
- PR #35's schema fixture test pins every column name you use — it will
  fail loudly if you name one that does not exist. Good; do not work
  around it.
- Migration numbering for SQLite indexes: next after the highest in
  `drizzle/`.
- `docs/design/**` is read-only law.

Finish: `/workspace/PR.md` with the before/after integration totals,
the queries you moved and what each returns now, the indexes added,
and how you kept the arithmetic unit-testable.
