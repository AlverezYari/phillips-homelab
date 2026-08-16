# SPEC — webapp-download-prefetch: hover-prefetch destroys single-use config downloads

Repo: `loop-bot/tychofleet`. Gate: `make build test lint`.

## The failure

Founder re-enrolled a scope (2026-08-16), reached the setup screen with
a fresh code, clicked the `tycho.yaml` download button, and got a failed
download — "file not found." Reproduced live, deterministically: **hover
the button, then click, and the click always fails.** Site log at the
moment of each failed click:

```
tycho-yaml: no tailnet key waiting for this code -- refusing to serve a config
```

Four of those in last night's onboarding window (01:21–01:23Z), zero
matching consume errors — because the consumes were silent.

## The mechanism

Three facts compose:

1. `astro.config.mjs` sets no `prefetch` option, and Starlight fills
   the gap site-wide: `@astrojs/starlight/index.ts:139-140` —
   *"If not already configured, default to prefetching all links on
   hover"* → `prefetch: { prefetchAll: true }`. This applies to every
   `<a>` on every page of the site, not just docs.
2. The setup screen's download button is a plain anchor GET
   (`src/pages/scopes/[scopeId]/setup.astro:183-188`):
   `<a href="/api/scopes/<id>/tycho-yaml?code=...&expires=...">`.
3. That route destroys its own key on read
   (`src/lib/tsmint/pending-keys.ts`, `pendingScopeKey` — the row is
   deleted the moment a matching read happens).

So: mouse hovers the button on its way to clicking → Astro's prefetch
script fires a real GET → route serves the config into the prefetch
cache (a 200, logged nowhere) and destroys the single-use key → the
user's actual click is a second GET → row gone → 503 → failed download.
Whether the click instead reuses the browser's prefetch-cache entry is
a timing lottery, which is why the flow occasionally succeeds and
mostly doesn't.

**This is not one link.** The member-config route has the same
destroy-on-read semantics (`src/lib/tycho-conf-delivery.ts`, nulls
`members.authkey` after building the body) and is linked by plain
anchors from at least three places:

| anchor | route |
|---|---|
| `src/pages/scopes/[scopeId]/setup.astro:183` | `/api/scopes/<id>/tycho-yaml` |
| `src/components/deck/ScopesPanel.astro:101` | `/api/profile/tycho-conf` |
| `src/pages/admin/approved/[token].astro:81` | `/api/members/<token>/tycho-conf` |
| `src/pages/m/[token].astro:225` | `/api/members/<token>/tycho-conf` |

Member onboarding has been rolling the same dice.

## What to build

### 1. Opt every side-effectful download anchor out of prefetch

`data-astro-prefetch="false"` on each of the four anchors above. Astro
honors per-link opt-out even under `prefetchAll`.

### 2. Pin the site-wide prefetch policy explicitly

Set `prefetch: { prefetchAll: false }` in `astro.config.mjs`, with a
comment naming this incident, so Starlight's default can never silently
re-arm the behavior when the config is next touched. Docs links lose
hover-prefetch; if you judge that worth preserving, justify the
alternative in PR.md — but the default posture is safety.

### 3. Audit, and make the audit the deliverable

Enumerate **every** `<a href>` in the repo (`.astro` templates and any
client `<script>`-built links) that targets an `/api/` route, and for
each: does a GET have side effects (consume, delete, null, mark, mint)?
Table in PR.md — route, side effect, anchor locations, prefetch-opt-out
applied or why not needed. This is the same "a fact re-derived in many
places" shape as SPEC `webapp-setup-in-progress`; the audit is what
keeps a fifth instance from shipping.

### 4. File the durable fix as a decision — do not implement it here

The root design flaw is a GET with destructive side effects: browsers,
AV scanners and link previewers all fire GETs the user never clicked.
The durable fix is idempotent download within the code's TTL (destroy
the pending key on gateway *redemption* or expiry, not on read) or a
POST-form download button. Both revise SPEC "webapp-tailscale-minting"'s
"destroy on handoff" posture, so: write it up as a decision file for
founder approval, with the trade-offs, and leave the implementation out
of this loop.

## Tests

- [ ] Red first: rendered setup screen's `tycho.yaml` anchor carries
  `data-astro-prefetch="false"`. This is the founder's failed download
  and the test should say so.
- [ ] Red first: same assertion for the three `tycho-conf` anchors.
- [ ] `astro.config.mjs` explicitly sets `prefetch.prefetchAll: false`
  (config-level assertion or lint grep — pick one and justify).
- [ ] Existing download-route behavior tests unchanged and green: the
  routes themselves are correct; only the anchors and site config move.

## Warts / traps

- Do NOT change `pending-keys.ts` or `tycho-conf-delivery.ts`
  destroy-on-read semantics in this loop — that is the decision-gated
  item 4. The fix here is entirely "stop firing GETs the user didn't
  click."
- Do not disable the prefetch integration wholesale by removing
  Starlight config — docs still want their sidebar; only the
  `prefetch` default changes.
- The four anchors are load-bearing for three different flows
  (scope setup/re-enrol, member self-service, admin approval). Touch
  the `data-astro-prefetch` attribute only; no copy, layout, or route
  changes.
- `docs/design/**` is read-only law.

Finish: `/workspace/PR.md` with the audit table (item 3), before/after
of each anchor, the incident narrative (hover → silent consume → 503),
and the decision file from item 4.
