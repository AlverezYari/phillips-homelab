# SPEC — webapp-setup-in-progress: one predicate, not four opinions

Repo: `loop-bot/tychofleet`. Gate: `make build test lint`.

## The failure

The founder re-enrolled a scope, reached the setup screen (which
correctly offered a fresh code), clicked download, and got **410 Gone**.

`src/pages/api/scopes/[scopeId]/tycho-yaml.ts:34`:

```ts
if (lookup.scope.enrolled) return new Response(null, { status: 410 });
```

`seestar-1` has been `enrolled` since an earlier code was redeemed, so
the download refuses. Its comment explains that a redeemed code must
never be handed out again — correct for first-time setup, wrong for
re-enrolment, which is *precisely* the case where a scope is enrolled
**and** a new code is live.

## Why this is the third time

An earlier loop fixed `resolveSetupMode` (`scope-deck.ts:158`) to
consult `pendingCode` before `enrolled`. That fix was correct and its
reasoning is written out well. But **"is this scope mid-setup?" is
decided independently in four places**, and only one was taught the new
fact:

| site | reads | state today |
|---|---|---|
| `scope-deck.ts:158` `resolveSetupMode` | `pendingCode` → `enrolled` → `attestedAt` | **fixed** |
| `scope-deck.ts:58` `resolveScopeCardState` | `enrolled` only | a re-enrolling scope still reads `● online` |
| `tycho-yaml.ts:34` | `enrolled` only | **the 410** |
| `status.ts:27` | returns all three to the client | fine, but the client re-decides |

This is the same shape as two other bugs shipped in the last 24 hours —
a fact that exists in one place and is re-derived, differently,
somewhere else. Fixing the fourth site individually would leave a fifth.

## What to build

### 1. One predicate, exported, used everywhere

A single function — `setupInProgress(scope)` or similar — that answers
"is this scope part-way through enrolment right now?" Every consumer
calls it. No route, page or component may re-derive this from
`enrolled`/`attestedAt`/`pendingCode` on its own.

Say in PR.md what it returns for each of the four combinations of
`enrolled` × `pendingCode`, and why.

### 2. The download route serves during re-enrolment

`tycho-yaml.ts` must serve a config when a code is genuinely live.
`410` is correct **only** when there is no pending code *and* the scope
is already enrolled — i.e. someone is fishing for a spent code.

Do not weaken anything else about that route: it stays session-gated,
stays owner-checked via `findOwnedScope`, and still must never serve a
config missing its gateway URL or tailnet key.

### 3. The deck must not call a re-enrolling scope online

`resolveScopeCardState` should report a scope with a live code as
in-setup, linking to the setup screen — not `● online` because a stale
credential and a stale attestation both still exist. Reuse
`setup-not-finished` or add a state; justify the choice.

### 4. Audit, and make the audit the deliverable

Enumerate **every** place in the repo that reads `enrolled`,
`attestedAt` or `pendingCode` outside the new predicate — including
`.astro` templates and client-side `<script>` blocks, which the linter
does not currently cover. For each: what it decides, and what it reads
after this loop. Put that table in PR.md.

`profile/index.astro`'s `row.enrolled` is **campaign enrolment**, an
unrelated concept with the same word. Note it in the table and leave it
alone — that collision is itself worth recording.

## Tests

- [ ] A scope that is `enrolled` **and** has a live code serves its
  config. This is the founder's 410 and it needs a test that names it.
- [ ] A scope that is `enrolled` with **no** pending code still gets
  410 — the anti-fishing property must not regress.
- [ ] A scope with a live code does not render `● online` on the deck.
- [ ] First-time setup is unchanged, asserted, since this touches the
  shared path.
- [ ] The predicate has its own table-driven test over all four
  `enrolled` × `pendingCode` combinations.

## Warts / traps

- Do not change the gateway. `pending_code` is already reported and
  correct.
- Do not change enrolment, key minting, the session gate, or ownership
  checks — all shipped and verified against the live gateway.
- Keep the good reasoning already written at `scope-deck.ts:150-157`;
  move it to the new predicate rather than deleting or duplicating it.
- `docs/design/**` is read-only law.

Finish: `/workspace/PR.md` with the predicate's truth table, the full
audit of every reader, and an ASCII render of the deck card for a scope
mid-re-enrolment.
