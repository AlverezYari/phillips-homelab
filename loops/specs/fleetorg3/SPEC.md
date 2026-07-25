# SPEC — fleetorg3: admin hierarchy, magic-link sessions, /profile

Repo: `loop-bot/tychofleet`. Gate: `make build test lint`.
`pnpm install --frozen-lockfile` once at start; `pnpm biome check
--write .` before every commit. Builds on the fleetorg/fleetorg2 work
already on main (programs, enrollments, membership chain, catalog
typeahead, email-with-log-only-default).

Context from Casey's second hands-on test: admin jumps straight to
programs with no way to create fleets or campaigns (both are
seed-only); there is no login/logout or notion of "who am I" — members
exist only as token URLs; nothing explains what a Program IS.

## Work items (one per iteration, in order)

- [ ] **Admin hierarchy.** Create fleet; create campaign under a
  fleet; programs listed/created nested under their campaign, with
  Fleet → Campaign → Program breadcrumbs everywhere in admin. Each
  level gets ONE line of inline help copy, verbatim intent:
  fleet = "whose scopes count"; campaign = "the story — a shared
  effort's umbrella, gallery, and goal"; program = "a standing
  instruction: these targets, these scopes, this window. Today it
  decides which frames pool into the fleet's shared master; when
  directed capture arrives it becomes the tasking the operator
  executes." Lib-layer tests per house pattern.
- [ ] **Magic-link sessions.** Passwordless member login: enter email
  → one-time, short-lived (15 min), single-use signed token emailed
  via the existing email path (log-only/Mailpit locally) → exchanging
  it sets an HttpOnly SameSite=Lax session cookie (sessions table:
  member, expiry ~30 days, revocable); logout clears it. Reuse
  src/lib/rate-limit.ts on the request-link endpoint. Never reveal
  whether an email is a member (uniform response). SESSION_SECRET env
  for signing; in dev, absent → derive an ephemeral one and log a
  loud warning (never a hardcoded default).
- [ ] **/profile.** For the logged-in member: email + editable display
  name, teams, fleets (resolved through the membership chain),
  enrollments with their sourceIds, and the tycho.conf download.
  Honest empty states ("not on a team yet", "not assigned to a
  fleet") — same spirit as the member page's unassigned state.
- [ ] **Session-aware member flows.** Enroll/leave and the member page
  work from a session, not only the token URL. Token links keep
  working (they're the invite bootstrap — a fresh invitee has no
  session yet); visiting one while logged out offers the magic-link
  login for next time. No token in any URL the profile links to.
- [ ] **Copy/consistency sweep.** Fleet Zero naming everywhere, admin
  section headers reflect the hierarchy, and docs/domain-model.md
  gains the site→operator mapping table (Program → decides
  FleetMaster inputs today / compiles to CaptureProgram later;
  enrollment → future Observation). Update RUNBOOK env-var list
  (SESSION_SECRET, SMTP_*).

## Warts / traps

- Session cookies: HttpOnly, SameSite=Lax, Secure when the request is
  https — the pod sits behind Cloudflare Tunnel in prod, plain http in
  dev, so key Secure off `Astro.request` protocol, not an env guess.
- migration.test.ts's `tag < "0003_"` fixture filter stays as-is.
- drizzle-kit generate for schema (sessions table etc.); seed changes
  mirror into scripts/migrate.mjs (guard test enforces).
- No client-side JS beyond what the typeahead already established;
  no trackers; no secrets; repo goes public.
- Biome --write before every gate.

Finish: /workspace/PR.md — call out the auth model (magic-link,
session lifetime, what SESSION_SECRET does) and any place token-URL
and session identity could disagree, for the reviewer.
