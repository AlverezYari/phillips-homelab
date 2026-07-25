# SPEC — fleetorg4: flatten Program into Campaign

Repo: `loop-bot/tychofleet`. Gate: `make build test lint`.
`pnpm install --frozen-lockfile` once at start; `pnpm biome check
--write .` before every commit.

## Context — a deliberate reversal, don't second-guess it

Three rounds of founder hands-on testing produced a verdict: the
Campaign → Program two-level split is a failed abstraction. Casey's
mental model (and now the canon): **a campaign IS the tasking** — one
fleet decides to observe target(s) over a time period. There is no
separate "program" object a human manages. Cross-fleet campaigns are a
future *type* of campaign (campaigns.fleetId stays single-fleet today,
correctly). The word "program" survives in exactly one place: docs
describing the future operator compile step (an active campaign
compiles to a tycho `CaptureProgram` CR when directed capture arrives).

## Work items (one per iteration, in order)

- [ ] **Schema flatten.** Migration: `campaign_targets` replaces
  `program_targets` (same columns, keyed to campaignId);
  `enrollments.programId` → `campaignId`; campaigns gain nullable
  `startsAt`/`endsAt` (the window that lived on programs); `programs`
  and `program_targets` tables dropped after data moves up (any
  existing program's targets/enrollments reattach to its campaign).
  Precedent for data-moving SQL inside a generated migration file:
  drizzle/0003 (the fleet_id backfill) — DDL via drizzle-kit generate,
  hand-added data movement in the same file, idempotent and safe on a
  DB with real rows AND on a fresh empty one. migration.test.ts gets a
  flatten-scenario case in the style of the 0003 backfill test.
- [ ] **Admin de-clunk.** Remove the program level from admin
  entirely: a campaign's page manages its targets (catalog typeahead
  intact), window, and activate/complete directly. Two levels of
  breadcrumb (Fleet → Campaign), not three. Founder's words: current
  managing is "clunky as fuck" — fewer pages, fewer clicks; creating a
  fleet+campaign+target should feel like one short errand, not a form
  safari.
- [ ] **Member surfaces re-key.** /profile, member page, enroll/leave
  APIs, and the tycho.conf enrollment stanza all speak campaigns now.
  Update docs/tycho-conf-enrollments.md and mark the stanza change
  prominently as BREAKING vs the previous shape — permitted freely
  today because nothing on the agent side consumes it yet; after an
  agent-side parser exists this doc becomes a versioned contract.
- [ ] **Docs truth pass.** docs/domain-model.md: campaign = the
  tasking (fleet + targets + window + enrollments); the site→operator
  table maps *campaign* → future CaptureProgram compile, enrollment →
  future Observation; cross-fleet campaigns noted as a future campaign
  type. Also add a "Known gaps" section recording (do NOT build): admin
  identity is basic-auth while members have real sessions — the two
  coexist in one browser with no way to see or switch identity; fine
  solo, must become a proper admin session/role before a second admin
  exists.

## Warts / traps

- migration.test.ts pre-fleets fixture filter (`tag < "0003_"`) stays.
- Seed changes mirror into scripts/migrate.mjs (guard test enforces).
- The flatten migration will run against the deployed prod DB
  eventually — treat "safe on non-empty DB" as a hard requirement,
  same bar the Fleet Zero rename met.
- No new dependencies; no client-JS growth; repo goes public.

Finish: /workspace/PR.md — lead with the schema flatten and the
BREAKING tycho.conf stanza change.
