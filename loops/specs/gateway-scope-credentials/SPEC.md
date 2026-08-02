# SPEC — gateway-scope-credentials: the gateway owns scope identity

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Implements **ADR 0009** (`docs/adr/0009-scope-credentials.md` — read it
first) on the gateway side. Two sibling loops are building the client
(`scopetui-enrolment`) and the web UI (`webapp-scope-management`)
against the same contract **at the same time as you**. The contract
below is law.

**Stay out of `agent/` and `scopetui`.** The sibling loop owns that
tree and you will collide.

---

## THE WIRE CONTRACT (identical in all three specs — do not improvise)

### Identity

Scope ids are **server-issued**, opaque: `scp_` + 8 lowercase hex, e.g.
`scp_7f3a91c4`. Owners never type or choose one. The human label is a
separate, editable, purely cosmetic field.

### Catalog (Postgres, gateway-owned)

`source` gains: `owner_member_id TEXT`, `label TEXT`,
`credential_hash TEXT`, `credential_issued_at TIMESTAMPTZ`,
`revoked_at TIMESTAMPTZ`.

New table `enrolment_code`: `code_hash TEXT PRIMARY KEY`,
`scope_id TEXT NOT NULL REFERENCES source(id)`, `created_at`,
`expires_at`, `redeemed_at`.

Codes and secrets are stored **SHA-256 hashed, hex**, never plaintext.

### Codes and secrets

- **Setup code:** 12 chars from `23456789ABCDEFGHJKMNPQRSTUVWXYZ`
  (no `0/O/1/I/L`), formatted `XXXX-XXXX-XXXX`. TTL **30 minutes**.
  Single use.
- **Scope secret:** 32 random bytes, base64url, unpadded. Returned
  exactly once, at redemption, and never retrievable again.

### Gateway HTTP API

Site → gateway, `Authorization: Bearer $SITE_API_TOKEN`:

```
POST   /v1/scopes                            {owner_member_id, label}
                                             -> 201 {scope_id}
GET    /v1/scopes?owner_member_id=...
       -> 200 {scopes:[{scope_id, label, model, make, serial,
                        firmware_version, attested_at,
                        last_heartbeat_at, revoked_at, enrolled}]}
PATCH  /v1/scopes/{scope_id}                 {label}   -> 204
DELETE /v1/scopes/{scope_id}                           -> 204
POST   /v1/scopes/{scope_id}/enrolment-code
       -> 201 {code, expires_at}
```

Agent → gateway, **unauthenticated** (the code *is* the credential):

```
POST /v1/enrol   {code}   -> 200 {scope_id, secret}
                          -> 410 expired / already redeemed / unknown
```

Agent → gateway, `Authorization: Bearer <scope secret>`:

```
POST /v1/sources/{scope_id}/register     (existing shape + attestation)
POST /v1/sources/{scope_id}/heartbeat
PUT  /v1/uploads/...                     (existing upload path)
```

`SOURCE_AUTH_TOKEN` is retired.

---

## What to build

### 1. Close the upload path — this is the point of the whole ADR

`upload.Service`'s own doc comment says it: *"this endpoint currently
has no notion of caller identity beyond 'an agent' (authmw isn't wired
onto the upload path)"*. Frames can be written under any source id, by
anyone who can reach the gateway, with no token at all.

- Every authenticated request carries a scope secret. Resolve it to a
  scope id by hash.
- **Reject 403 if the credential's scope id is not the `{scope_id}` in
  the path**, and reject 403 if an upload's object key prefix is not
  `tycho-source-<scope_id>/`.
- A revoked credential (`revoked_at` non-null) is refused everywhere.

Do not skip the object-key check because the path check exists. The
object key is what decides where bytes land and whose attribution they
join; it is the one that matters.

### 2. Enrolment

- `POST /v1/enrol` is the only unauthenticated write endpoint in the
  gateway. Treat it accordingly: constant-time code comparison, and a
  redemption that is **atomic** — two simultaneous redemptions of one
  code must not both succeed. You have a pattern for this already:
  `RegisterSource` on the parked `loop/enforce` branch used
  `SELECT ... FOR UPDATE` in a transaction. Same shape.
- Redemption returns the secret **once**. It is hashed on write and
  there is no endpoint that reads it back. Say in PR.md what happens if
  the agent loses the response (answer: the owner issues a new code).
- Issuing a new code for a scope **invalidates any unredeemed code** for
  that scope. Otherwise "generate again because the first didn't arrive"
  quietly leaves two live codes.
- An expired, unknown, or already-redeemed code all return **410 with
  the same body**. Do not tell an unauthenticated caller which of the
  three it was.

### 3. Scope CRUD for the site

`DELETE` **revokes the credential and soft-deletes the scope. It never
deletes frames.** Someone removing a scope from their deck is saying
"this device is no longer mine", not "erase three months of my data" —
and `session.source_id` has a foreign key onto `source` anyway. Say in
PR.md what a removed scope's existing frames and masters look like
afterwards.

`PATCH` changes only the label. A label is not identity and carries no
authority; two scopes may share one.

`GET` drives the deck. `enrolled` is true once a credential exists.
Distinguish, in the response, a scope that has **never enrolled**, one
enrolled but **never attested** (device was off), and one **attested** —
the three states ADR 0008 called for. The web loop renders exactly
these; if you collapse them it cannot.

### 4. Migrate the live deployment

`seestar-1` exists now, attested, with real frames and a foreign key
from `session`. It must keep working.

- Its id stays `seestar-1` — do not rewrite ids that other tables
  reference. Server-issued ids apply to scopes created from here on.
- Give it a path to a credential without a web UI: document it, and
  provide whatever one-shot command or SQL the operator runs. Its
  existing attestation carries across; it does not re-attest from
  scratch.
- Say in PR.md, precisely, the steps to migrate the running deployment,
  in order, including what breaks if they are done out of order.

### 5. `SITE_API_TOKEN`

A new required env var, distinct from every other. Follow the precedent
the parked branch set: **fail to start if it is missing, and fail to
start if it equals any other configured token.** A documented invariant
nobody checks is how this project keeps getting hurt.

## Tests

- [ ] An upload whose object key prefix does not match its credential's
  scope is refused, and **nothing is written to Garage** — assert the
  storage call did not happen, not just the status code.
- [ ] A request authenticated as scope A against scope B's path is 403.
- [ ] Redeeming a code twice: exactly one caller gets a secret.
  Concurrent, not sequential.
- [ ] An expired code and an unknown code are indistinguishable to the
  caller.
- [ ] A revoked scope cannot register, heartbeat, or upload.
- [ ] `seestar-1` with its current row shape survives the migration and
  can still register — this is the test that stops you breaking the only
  real scope in the fleet.
- [ ] Postgres-backed tests: note that they **skip** unless
  `TYCHO_TEST_DATABASE_URL` is set, so a green gate does not mean they
  ran. Write them anyway, and say in PR.md that they are skip-gated.

## Warts / traps

- Secrets and codes never appear in a log line, an error message, an
  event payload, or a FITS header. Check your error wrapping.
- Do not touch `agent/`, `agent/cmd/scopetui`, or
  `agent/internal/uploader` — the sibling loop owns them and is
  editing them right now.
- Do not change `DescribeDevice`, the keys allowlist, or
  `agent/internal/zwo`: shipped and working against real hardware.
- Migration numbering: next after the highest in
  `gateway/internal/catalog/migrations/` (0006 is taken).
- `docs/adr/**` is a record, not a scratchpad.

Finish: `/workspace/PR.md` with the migration runbook for `seestar-1`,
what a removed scope's frames look like, the three enrolment states and
how the site tells them apart, and proof the upload path now refuses a
mismatched key.
