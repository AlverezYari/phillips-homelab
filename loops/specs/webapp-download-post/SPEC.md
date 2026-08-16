# SPEC — webapp-download-post: config downloads become POST forms

Repo: `loop-bot/tychofleet`. Gate: `make build test lint`.

## Why

Founder-approved follow-up to loop `webapp-download-prefetch` (PR #86,
merged): its decision file 001 compared destroy-on-redemption, POST
forms, and status quo — the founder approved the recommendation,
**option (b): POST forms**, on 2026-08-16.

PR #86 closed the hover-prefetch vector, but the root flaw remains: the
five config-download endpoints are GETs with destructive side effects
(destroy-on-read of a single-use key). Anything that fires a GET the
user never clicked — AV/security scanners, corporate link-rewriting
proxies, link-preview bots, some browser accessibility tooling — can
still silently consume a member's one config download. The rest of this
codebase is already form-POST-only for side-effectful actions (see the
re-enrol page's "Generate new code" form); downloads join that idiom.

## What to build

### 1. The five download controls become POST forms

The five places PR #86 tagged with `data-astro-prefetch="false"`:

| control | route |
|---|---|
| `src/pages/scopes/[scopeId]/setup.astro` (tycho.yaml button) | `/api/scopes/<id>/tycho-yaml` |
| `src/components/deck/ScopesPanel.astro` | `/api/profile/tycho-conf` |
| `src/pages/profile/index.astro` | `/api/profile/tycho-conf` |
| `src/pages/admin/approved/[token].astro` | `/api/members/<token>/tycho-conf` |
| `src/pages/m/[token].astro` | `/api/members/<token>/tycho-conf` |

Each becomes a `<form method="POST">` with a submit button styled as
the control is today; query-string inputs (`code`, `expires` on the
tycho-yaml route) move to hidden fields. Browser-native form submission
— no client JS. A POSTed response with `content-disposition:
attachment` downloads exactly as the GET did; the filename must not
change.

### 2. The routes serve on POST; GET must never consume

Each route gains a `POST` handler with the exact current logic —
auth/ownership gates, single-use destroy-on-read, refusal paths, log
lines all unchanged, just triggered by POST.

`GET` on these routes must return **405** and — the property this whole
SPEC exists for — **must not touch the pending key / authkey state**.
No consume, no delete, no side effect of any kind on GET.

### 3. Retire the now-moot prefetch attributes and their tests

With no anchors left, `data-astro-prefetch="false"` on these controls
disappears with them. Replace `src/tests/pages/download-prefetch.test.ts`
(which asserts those anchors) rather than deleting coverage — see Tests.
Keep the `prefetchAll: false` pin in `astro.config.mjs` and its test:
that's site policy, not part of this change.

## Tests

- [ ] Red first, per route: GET returns 405 **and** a pending key
  stashed before the GET is still redeemable by a subsequent POST — the
  never-consume property, asserted directly.
- [ ] POST serves the config once (body, content-type,
  content-disposition filename asserted) and a second POST gets the
  same refusal the second GET used to get.
- [ ] Auth/ownership behavior identical under POST: session-gated
  routes still 401 without a session; the token routes (`/api/members/
  <token>/…`) still work token-only; the scopeId-mismatch refusal still
  refuses without consuming.
- [ ] Source-based replacement for `download-prefetch.test.ts`: no
  `<a>` in the repo targets any of the three routes; the five controls
  are forms with `method="POST"`.
- [ ] `astro.config.mjs` `prefetchAll: false` assertion stays.

## Warts / traps

- Do NOT change `pending-keys.ts` / `tycho-conf-delivery.ts` internals
  — destroy-on-read stays; only the HTTP method guarding it changes.
  (Option (a), destroy-on-redemption, was considered and not chosen.)
- The `m/[token]` and `admin/approved/[token]` pages are deliberately
  session-less (invite-token auth). Do not add session gates while
  converting.
- The tycho-yaml route's `code`/`expires` currently ride the query
  string by design ("never persists a code anywhere"). As hidden form
  fields they keep that property; do not start persisting them.
- Update SPEC `webapp-tailscale-minting`'s "destroy on handoff" note
  where it implies GET delivery, referencing decision 001 — do not
  otherwise edit shipped specs.
- Commit decision file `decisions/001-destroy-on-read-vs-destroy-on-
  redemption.json` to the repo this time (PR #86 left it sandbox-only),
  marked approved/option-b.
- `docs/design/**` is read-only law.

Finish: `/workspace/PR.md` with before/after of one control, the
five-conversion table, and the GET-never-consumes test named as the
headline property.
