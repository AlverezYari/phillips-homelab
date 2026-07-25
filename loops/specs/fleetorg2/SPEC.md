# SPEC — fleetorg2: hands-on-test feedback round (targets, Fleet Zero, membership chain, email)

Repo: `loop-bot/tychofleet`. Gate: `make build test lint`. Run
`pnpm install --frozen-lockfile` once at start; `pnpm biome check
--write .` before every commit. Same rig as the fleetorg loop — its
work (programs/enrollments/admin/member pages, docs/domain-model.md)
is on main; read it before building on it.

Context: Casey drove the whole flow by hand (waitlist → approve →
program+target → enroll → tycho.conf) and it works. This SPEC is his
punch list, verbatim intent, one item per iteration.

## Work items (one per iteration, in order)

- [ ] **Edit/remove targets.** Admin can edit a program target's
  name/designation/RA/Dec/match-radius and remove a target from a
  program (server-rendered forms + `api/admin/` endpoints, same
  patterns as programs-create/add-target). Lib-layer tests. Removing
  a target that has attributed observations is out of scope (nothing
  attributes yet) — a plain delete is fine today.
- [ ] **Target catalog typeahead.** Nobody remembers coordinates.
  Vendor a static deep-sky-object catalog as JSON at
  `src/data/dso-catalog.json`: every Messier object (M1–M110) with
  common name, designation, aliases, ICRS RA/Dec in degrees — you
  know these; generate them accurately — plus a checked-in
  `scripts/fetch-catalog.mjs` that regenerates/extends the JSON from
  OpenNGC (https://github.com/mattiaverga/OpenNGC, CC-BY-SA-4.0 —
  include attribution in the JSON header and docs) for the full
  NGC/IC set later; the script needs network so it is run by humans,
  NEVER by the gate. Admin add-target gets a search box over the
  vendored JSON (name/designation/alias substring, server-rendered or
  minimal progressive JS consistent with house no-bloat style) that
  autofills name/designation/RA/Dec on pick. Manual coordinate entry
  stays for objects not in the list.
- [ ] **Fleet Zero.** Rename the seed fleet: slug `fleet-zero`, name
  "Fleet Zero" (Casey: "which is cooler"). Idempotent migration
  updates the existing `fleet-1` row in deployed DBs; seed.ts +
  scripts/migrate.mjs mirror + FLEET_ONE_SLUG constant (rename it) +
  fleet page references/tests all follow. seed.test.ts guards the
  mirror sync — it will catch you if you miss one side.
- [ ] **Membership chain, wired for real.** Today approve dumps every
  member into the seed fleet via members.fleetId's default — Casey
  wants membership to flow member → team → fleet. Admin gets minimal
  team management: create team, add/remove a member, attach/detach a
  team to a fleet (a `fleet_members` row with principal_type=team).
  Approve stops implying fleet membership by itself: it creates the
  member only; the member page resolves visible programs through the
  chain (direct member `fleet_members` row OR team membership →
  team's `fleet_members` row), and shows "not yet assigned to a
  fleet" state honestly when the chain is empty. `members.fleetId`
  column stays (schema comment already calls it the v1 coexisting
  link) but display/enrollment logic must use the chain. Update
  docs/domain-model.md to describe the wired reality.
- [ ] **Email, log-only by default.** Approval currently surfaces the
  member link only in the admin UI. Add outbound email (nodemailer or
  equivalent minimal dep): on approve, send the member their link.
  Env contract: SMTP_HOST/SMTP_PORT/SMTP_USER/SMTP_PASS/SMTP_FROM —
  ALL optional; any missing → log-only mode (email rendered to the
  server log, nothing sent, flow unchanged) so prod stays safe until
  credentials exist. Never block or fail approve on send failure —
  log and continue; the admin UI keeps showing the link either way.
  Tests exercise log-only mode + a fake transport; no network in
  tests. Document local testing with Mailpit
  (`docker run -d -p 1025:1025 -p 8025:8025 axllent/mailpit`,
  SMTP_HOST=localhost SMTP_PORT=1025, UI at :8025) and the intended
  prod path (Fastmail SMTP submission, creds via ESO — pointer only,
  no secrets, DNS/SPF/DKIM is dashboard work outside this repo).

## Warts / traps

- migration.test.ts's pre-fleets fixture filter (`tag < "0003_"`) is
  correct — don't touch it when adding migrations.
- Schema changes via `pnpm drizzle-kit generate` only; seed changes
  must be mirrored in scripts/migrate.mjs (guard test enforces).
- The Fleet Zero rename migration runs against a REAL deployed DB —
  make it idempotent and safe on both a fresh DB and one where
  fleet-1 exists with members attached.
- No secrets, no trackers, no client-side bloat; repo goes public.
- Biome format before every gate run.

Finish: /workspace/PR.md — call out the membership-chain behavior
change (approve no longer implies fleet membership) prominently; it
changes what admins must do after approving someone.
