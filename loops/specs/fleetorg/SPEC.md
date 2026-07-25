# SPEC — fleetorg: document + activate the fleet-organization model

Repo: `loop-bot/tychofleet` (Astro 5 SSR + SQLite/Drizzle + Vitest +
Biome, pnpm). Gate: `make build test lint` — hermetic, no network, no
gh/tea auth. Run `pnpm install --frozen-lockfile` once at start;
`pnpm biome check --write .` before every commit or the lint gate
fails on formatting.

## Context (read first, don't re-derive)

Migration `drizzle/0004_fleet-org-programs.sql` (schema in
`src/lib/schema.ts`, shape tests in `src/lib/migration.test.ts`)
just landed the domain skeleton:

- `teams` / `team_members` — members form teams.
- `fleet_members` — polymorphic principal (`member|team|service_account`)
  joins any of the three to a fleet. `members.fleetId` is the v1 direct
  link; they coexist deliberately.
- `programs` (inside campaigns) — an observing tasking. `mode` is
  `opportunistic|directed`; **only opportunistic is real today**.
  directed maps to the tycho operator's reserved `CaptureProgram` CRD
  and is gated upstream (operator-as-client unbuilt, dispatch
  DISPATCH_ENABLED-gated) — build NOTHING that executes directed mode.
- `program_targets` — 1..N per program, RA/Dec REQUIRED: frames are
  attributed by RA/Dec cone match against the tycho catalog, never by
  name-string.
- `enrollments` — member (+ optional `sourceId`; null = all their
  scopes) opted into a program. The member's `tycho.conf` is the
  intended delivery vehicle for enrollment, same as grants.

The comments in `schema.ts` carry the rationale — treat them as the
authority and don't contradict them in docs.

## Work items (one per iteration, in order)

- [ ] `docs/domain-model.md` — describe the model AS SHIPPED: each
  table's role, the two participation modes and why they're
  architecturally different, RA/Dec cone matching (and why names are
  display-only), the site↔operator contract (site `program` row ⇄
  future `CaptureProgram` CR, `enrollments` ⇄ future `Observation`),
  and what is deliberately inactive (directed mode, real user
  accounts). Written for strangers — repo goes public eventually.
- [ ] `docs/NORTHSTAR.md` — the product trajectory in civilian words:
  headless fleet-native observing orchestration; wrap Seestar first,
  then the family, then serious hobbyist rigs via INDI/ASCOM Alpaca as
  a second southbound driver (never per-device drivers); owners donate
  scope time under stewardship grants (tycho ADR 0004) — "your scope
  stays yours" is the differentiator. Passive/opportunistic now, mock
  directed fleets next, real directed capture later. Link
  domain-model.md. Match the voice in BRIEF.md (honest, warm, a little
  wonder-struck; no startup-speak).
- [ ] Admin: program management on the existing admin page (pattern:
  `src/pages/admin/index.astro` + `src/pages/api/admin/*.ts`, reuse
  `admin-auth`). Create a program under a campaign; add targets with
  name/designation/RA/Dec (validate ranges: RA 0–360, Dec −90–90);
  activate/complete it. Server-rendered forms, no client JS, matching
  how the approve flow works today. Tests at the lib layer like
  `fleet.test.ts` does.
- [ ] Member enrollment: on the member status page (`m/[token]`) list
  active programs for the member's fleet with enroll/leave actions
  (API under `src/pages/api/members/[token]/`). Respect the
  all-scopes-vs-per-scope rule documented on `enrollments` in
  schema.ts (the NULL-sourceId uniqueness caveat is in a comment
  there — handle it in the enroll path).
- [ ] `tycho.conf` enrollment stanza: extend `src/lib/tycho-conf.ts`
  to emit the member's active enrollments (program slug/id + target
  coordinates) in the generated conf. Add a `docs/` note documenting
  the emitted format as the contract the tycho agent's `fieldconf`
  parser will adopt — the agent side is NOT in this repo and NOT this
  loop's job; emitting + documenting is the whole deliverable. Keep
  the stanza additive/optional so existing confs stay valid.

## Warts / traps

- `migration.test.ts` builds a pre-fleets fixture by filtering journal
  tags `< "0003_"` — if you add migration 0005, don't touch that
  filter; it's correct as written.
- Schema changes go through `pnpm drizzle-kit generate` (never
  hand-write migration SQL); if you change the SEED, mirror it in
  `scripts/migrate.mjs` — `seed.test.ts` guards the sync and will fail
  you if you forget.
- Biome formats aggressively; `pnpm biome check --write .` before the
  gate, every time.
- No secrets in anything, ever — repo goes public ("dark mode" now).
- Prefer the simplest reading of the repo's existing patterns over
  filing decisions; file a decision only if two work items genuinely
  conflict.

Finish: write `/workspace/PR.md` (reviewer-facing summary of what
landed and what a reviewer should look hardest at).
