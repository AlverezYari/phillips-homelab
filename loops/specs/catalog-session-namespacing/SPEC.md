# SPEC — catalog-session-namespacing: two scopes, one session row

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Scope: **`gateway/` only.** A sibling loop (`operator-session-namespacing`)
is doing the operator half in parallel — stay out of `operator/` and
`agent/`.

## The failure

Session ids are minted client-side as `slugify(target)-YYYY-MM-DD`
(`agent/internal/uploader/session.go:31`) — e.g. `m-13-2026-07-27`.
**There is no scope in that string**, and it is the primary key of
`session` (`0001_init.sql`).

`sub` has **no `source_id` column at all**; attribution runs entirely
through `sub.session_id`'s foreign key (`catalog.go:80-84` documents the
choice deliberately).

So when two scopes shoot the same target on the same night,
`postgres.go:302-305`'s

```sql
INSERT INTO session (...) VALUES (...) ON CONFLICT (id) DO NOTHING
```

files the second scope's frames under **the first scope's session row**.
Every downstream consumer then attributes those frames to the wrong
telescope, and the combine runs over one scope's object prefix while the
row claims both.

This has not happened yet: there is exactly one real source
(`seestar-1`, 8 sessions, 798 subs). That is why this is worth doing
today.

## Why today and not next month

Right now the backfill is **mechanical and lossless**: every
`sub.source_id` is recoverable unambiguously from its `object_key`,
which begins `tycho-source-<sourceID>/`. One source, no ambiguity.

The day a second scope shares a session id, that stops being true.
`session.source_id` is already wrong for half the rows, a combine has
already run over the wrong prefix and produced a stack, and the CR
history is conflated. Per-frame attribution stays recoverable from
object keys; the derived artifacts do not.

The migration does not get slower. It goes from lossless to partly
unrecoverable, on a date you do not control.

## What to build

### 1. `sub.source_id`, backfilled from the object key

Add `source_id` to `sub`, backfilled by parsing the existing
`object_key` prefix (`tycho-source-<sourceID>/...`). Make it `NOT NULL`
once backfilled.

- A row whose `object_key` does not parse must **fail the migration
  loudly**, not default to something. There are 798 rows and all of them
  parse today; if one doesn't, we want to know rather than to guess.
- State in PR.md how many rows the backfill touched and how you verified
  the parse against the real key shape.

### 2. `session` keyed by `(source_id, id)`

The session id stays exactly as the agent mints it — **do not change
`SessionID`**, and do not change object keys. What changes is that a
session id is unique *within a source*, not globally.

- Primary key becomes `(source_id, id)`.
- `ON CONFLICT` on insert becomes the composite.
- Every query joining or filtering `session` gains the source
  predicate. Audit them all — `grep` for `session` across `gateway/` and
  put the list in PR.md with what each now filters on.
- `sub.session_id`'s foreign key must follow the new key.

### 3. Do not break the existing data

`seestar-1` has 8 sessions and 798 subs, including the M13 masters that
are live on the public site. The migration must be exact, and the tests
must prove the existing shape survives:

- [ ] After migration, all 798 subs carry `source_id = 'seestar-1'`.
- [ ] All 8 sessions are intact and still joined to their subs.
- [ ] Per-source integration totals are **unchanged** before and after —
  this is the number the public attribution page renders, and it must
  not move.

### 4. The test that proves the point

- [ ] Two different sources inserting the **same session id on the same
  night** produce two distinct session rows, each owning only its own
  subs. That is the entire reason for this loop; without that test the
  change is unproven.
- [ ] Per-source attribution for that pair is correct — scope A's
  seconds do not include scope B's frames.

## Warts / traps

- Postgres-backed tests **skip silently** without
  `TYCHO_TEST_DATABASE_URL`, so a green gate does not mean they ran.
  Write them anyway, say so in PR.md, and say which of your assertions
  are skip-gated. If you can run them, say how.
- Do not touch `operator/` or `agent/` — the sibling loop owns the
  operator, and the agent's `SessionID` is deliberately unchanged.
- `combine_input.sub_object_key` is deliberately polymorphic (ADR 0005 +
  the gateway's own migration note). Do not "fix" it here.
- Migration numbering: next after the highest in
  `gateway/internal/catalog/migrations/`.
- `docs/adr/**` is a record, not a scratchpad.

Finish: `/workspace/PR.md` with the backfill row count, the audit of
every session query, before/after per-source integration totals proving
they did not move, and the two-scopes-one-night test.
