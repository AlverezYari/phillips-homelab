# SPEC — gate-postgres-ci: the auth resolver has never been executed by a test

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

## The failure

Eight tests in `gateway/internal/catalog` skip unless
`TYCHO_TEST_DATABASE_URL` is set. **Nothing sets it** — not the
Makefile, not `ci/main.go`, not `.forgejo/workflows/ci.yml`. So they
have never run anywhere, and a green gate says nothing about them.

Worse, six `Postgres` methods are not covered **even by those skipped
tests** — they have no test at all, in any configuration:

| method | `postgres.go` | what it is |
|---|---|---|
| **`ResolveCredential`** | `:252` | **authorises every authenticated request in the system** |
| **`RevokeScope`** | `:142` | the "a revoked credential is refused everywhere" guarantee |
| `ListScopes` | `:94` | the deck's read path |
| `UpdateScopeLabel` | `:125` | |
| `Heartbeat` | `:267` | |
| `SetSessionTarget` | `:378` | manifest → session target |

`main.go:227-230` passes `pg` as the `CredentialResolver` to upload,
source **and** devicekey. The query behind every authorisation decision
in Tycho has never been executed by a test.

And the enrolment→authentication contract is untested end to end. The
SHA-256 digest is implemented **three times** — `scope/credential.go:110`
(`HashToken`), `authmw/authmw.go:123` (deliberately not shared, per its
own comment), and again in `authmw_test.go:76`. **No test feeds
`scope.Redeem`'s returned secret into `authmw.ScopeSecret`.** What makes
a freshly enrolled scope able to authenticate at all is held together by
a comment explaining why the duplication is safe.

`storage/s3.go` (226 lines) and `eventbus/nats.go` have **no test file
at all**.

## Why now

Yesterday's session-namespacing migration had to be verified by hand
against a dump of production, three times, because CI cannot run a
migration. That is not repeatable and it does not scale. Every future
schema change has the same problem.

## What to build

### 1. Postgres in CI

Add a Postgres service to the CI pipeline and set
`TYCHO_TEST_DATABASE_URL` so the eight skip-gated tests actually run.

`ci/main.go` builds with Dagger; `.forgejo/workflows/ci.yml` drives it.
Work out where the service belongs and say why in PR.md. If the runner
genuinely cannot host a service container, say so explicitly with what
you tried — do not quietly leave the skips in place.

`make test` should also use it when a database is available, and skip
loudly (not silently) when not. The existing python legs already have a
"loud skip" convention — follow it.

### 2. Tests for the six uncovered methods

Real tests against a real Postgres. `ResolveCredential` and
`RevokeScope` are the ones that matter:

- [ ] `ResolveCredential` resolves a valid credential to the right
  scope, and returns nothing for an unknown one.
- [ ] A **revoked** scope's credential resolves to nothing — the
  property the whole revocation story rests on.
- [ ] `RevokeScope` is idempotent, and does not touch sessions, subs or
  results.

### 3. The contract test that does not exist

- [ ] **Redeem a code via `scope.Redeem`, then authenticate with the
  returned secret via `authmw.ScopeSecret`.** Roughly twenty lines. It
  is the only thing that proves a newly enrolled scope can actually
  authenticate, across two independent implementations of the same
  hash.

### 4. Do not paper over what you cannot fix

If Postgres in CI proves impossible on this runner, the fallback is to
make the skips **loud and counted** — a failing gate under `STRICT=1`,
not a silent pass — and to say plainly in `docs/dev/testing.md` and
`docs/MATURITY.md` what is unverified.

Note `MATURITY.md:37` currently says "three Go tests skip". It is
**eight**, across six files. And `docs/dev/testing.md` — the document
whose entire job is enumerating the gate's blind spots — **never
mentions Postgres at all.** Fix both regardless of the outcome.

## Warts / traps

- Do not change production code to make it testable in ways that alter
  behaviour. If a method resists testing, say so.
- Do not touch `agent/` or the enrolment flow — shipped and verified
  against real hardware.
- The gate now runs `-race -count=1` by default. Keep it.
- Migration `0008` rekeyed `session` to `(source_id, id)` and added
  `sub.source_id`. Any fixture you build must match current schema, not
  the old one.
- `docs/adr/**` is a record, not a scratchpad.

Finish: `/workspace/PR.md` with the eight tests actually running (paste
the output), the new coverage numbers for `postgres.go`, the
redeem→authenticate contract test, and the corrected blind-spot docs.
