# SPEC — operator-session-namespacing: one CR name for two telescopes

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Scope: **`operator/` only.** A sibling loop
(`catalog-session-namespacing`) is doing the schema half in parallel —
stay out of `gateway/` and `agent/`.

## The failure

A session id is `slugify(target)-YYYY-MM-DD` — `m-13-2026-07-27` — with
**no scope in it**. The operator uses that string, alone, for two
identities:

**1. The `ImagingSession` CR name.** `sessionclose.go:171` calls
`sessionCRName(sessionID)` (`:360`), which takes only the session id.
Two scopes shooting the same target on the same night produce **one CR**,
and the second scope's close silently updates the first's object.

**2. The quiescence tracker key.** `activity.go:39-47`:

```go
s, ok := t.sessions[sessionID]
if !ok {
    s = &trackedSession{SourceID: sourceID, SessionID: sessionID}
    t.sessions[sessionID] = s
}
```

Keyed by `sessionID` alone — while *storing* `SourceID` in the struct.
So the second scope's activity updates the first scope's entry, sub
counts from both telescopes are summed under one, and `SourceID` stays
whichever arrived first. The struct field records an ownership the map
key does not enforce.

## The good news

**The operator already has the source id everywhere it needs it.** It
validates its presence (`sessionclose.go:115-116`, *"missing source_id"*
is a hard error), passes it to `closeSession` (`:133`), hands it to
`RecordActivity` (`:135`), and puts it on the CR spec (`:197`). This is
threading an argument you already hold into two naming decisions — not
new plumbing.

**And the pattern already exists in this repo.** `TargetMaster` names
itself `master-seestar-1-m-13` — source, then target. Live proof:

```
NAME                    SOURCE      TARGET
master-seestar-1-m-13   seestar-1   m-13
```

`targetMasterCRName` (`master_trigger.go:29`) is the convention to
follow. Do not invent a second one.

## What to build

### 1. `sessionCRName` includes the source

Same DNS-label-safe treatment, same 253-char clamp, same `unknown`
fallback — with the source id in the name. Match `targetMasterCRName`'s
shape so the two read alike.

Mind the clamp: truncating must not make two different
`(source, session)` pairs collide. Say in PR.md what you did about long
names, and test it.

### 2. The tracker keys on both

`t.sessions` becomes keyed by the pair. Every method that reads or
writes it follows. Keep `SourceID` on the struct — but it must now agree
with the key by construction rather than by hope.

### 3. Existing CRs: decide deliberately and say so

There are **8 live `ImagingSession` CRs**, all owned by `seestar-1`, all
named by the old scheme — including `m-13-2026-07-18/27/29`, whose
frames are in the M13 masters on the public site:

```
68-herculis-2026-07-15   m-13-2026-07-18   m-13-2026-07-27
m-13-2026-07-29   nu-coronae-borealis-2026-07-27
pi-herculis-2026-07-17   rho-herculis-2026-07-15   rho-herculis-2026-07-17
```

Renaming means the operator stops recognising them and creates new
objects alongside — orphaning eight records of real observing history,
five of them `Done` with completed stacks.

Decide and justify in PR.md. Options, not exhaustive:
- accept the orphans and document what an operator should do with them
- look up by a label or spec field rather than by name, so existing CRs
  are still found
- provide a one-shot migration the operator runs by hand

**Do not silently orphan them.** Whatever you choose, say what happens
to those eight objects and what a human has to do about it.

### 4. Do not change what the operator does, only how it names

Reconcile logic, phases, combine triggering, event payloads and the
`TargetMaster` path are all unchanged. This loop changes identity, not
behaviour.

## Tests

- [ ] Two sources with the **same session id on the same night** produce
  two distinct CR names and two distinct tracker entries, each with the
  right sub counts. This is the whole point.
- [ ] The tracker's `SourceID` field can no longer disagree with its
  key — assert it rather than trusting it.
- [ ] Quiescence still fires correctly for a single source (the existing
  behaviour must be untouched).
- [ ] Long source/session combinations still yield valid, distinct,
  DNS-safe names.
- [ ] `operator/fullloop_test.go` — note that it constructs
  `CombineJobReconciler` **without `Scheme`**, which trips an early
  `return nil` and silently disables the master and fleet-master spawn
  paths. If your change touches anything those paths reach, that test
  will not tell you. Say in PR.md whether you fixed it or worked around
  it; do not assume it covers you.

## Warts / traps

- Do not touch `gateway/` or `agent/` — the sibling loop owns the
  schema, and the agent's `SessionID` is deliberately unchanged.
- The operator does not read Postgres; it is event- and CRD-driven. You
  do not need the schema change to land first.
- `docs/adr/**` is a record, not a scratchpad.

Finish: `/workspace/PR.md` with the new naming scheme beside
`targetMasterCRName` for comparison, your decision on the eight existing
CRs and what a human must do, and the two-scopes-one-night test.
