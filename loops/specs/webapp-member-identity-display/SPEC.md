# SPEC — webapp-member-identity-display: contributing members shown as nameless/scopeless

Repo: `loop-bot/tychofleet`. Gate: `make build test lint`.

## The failure (real member, 2026-08-17)

Member Glen: scope registered via the modern deck flow, online, in
fleet-zero, actively pushing frames (catalog counts his contributions).
But the site shows:

1. The fleet-zero page does not show his CHANGED display name.
2. The Lobster Claw campaign page lists him as contributing but his
   row reads **"no scope id on file"**.

## Evidence from triage (verify, then fix)

**Bug 2 root cause (pinned):** the campaign/fleet pages resolve a
member's scope as `enrollment.sourceId ?? member.scopeId`
(`src/lib/campaign-page.ts` ~line 81, `src/pages/fleet/[slug]/ops.astro:180`,
`src/pages/campaign/[id]/index.astro` ~line 300). Both legs are dead
for modern members: v1 enrolment only ever writes null-sourceId
"all my scopes" rows (see `deck.ts` scopeIdsForMember's own doc), and
`members.scopeId` is a legacy column the modern gateway/deck
registration flow never writes. Related: `getFleetRoster`'s
`scopeCountFor` (`src/lib/fleet.ts` ~246) counts only non-null
enrollment sourceIds, so contributing members also read as 0 scopes.

**Bug 1 (not yet pinned — reproduce first):** the rendering helpers
look correct (`publicMemberLabel` prefers displayName;
`ops.astro:178` uses `member.displayName ?? member.email`). So the
defect is upstream: either (a) the profile display-name save path
does not persist to `members.displayName`, or (b) some fleet-zero
surface renders a name from a source that bypasses these helpers
(team name, denormalized snapshot, catalog label). Write the failing
test FIRST from the reproduced cause; do not guess-fix rendering.

## What to build

### 1. One member→scopes resolution seam

A single function answering "which scope/source ids belong to this
member" that consults, in order: explicit per-scope enrollment
sourceIds, THEN the member's registered scopes from the catalog/
gateway seam the scope deck and observer pages already use (that is
the source that actually knows Glen's scope), THEN legacy
`members.scopeId` for old rows. Every current consumer of
`enrollment.sourceId ?? member.scopeId` migrates onto it — audit the
repo for that pattern and table the call sites in PR.md (campaign
page, fleet ops, roster scopeCount, join page, anywhere else).
"no scope id on file" should become an honest rarity (a member with
genuinely no registered scope), not the default for modern members.

### 2. Fix the display-name defect at its reproduced root

Whichever of (a)/(b) reproduces: fix the save path or migrate the
bypassing surface onto `publicMemberLabel`. Respect the existing
privacy posture — `publicMemberLabel`'s email fallback only where
`allowEmail` is already true today; public pages keep the
`Observer <id>` stand-in for members with no display name.

### 3. Red-first tests

- [ ] A member shaped like Glen (gateway-registered scope, null
  enrollment sourceId, null members.scopeId, changed displayName):
  campaign pooling row shows the scope id (linked), fleet ops row
  shows scope id, roster scopeCount ≥ 1, and every fleet-zero surface
  shows the CURRENT display name. These fail on main today.
- [ ] Legacy member (members.scopeId set, no catalog scopes) still
  resolves — no regression.
- [ ] Member with genuinely no scope still reads "no scope id on
  file" / "No scope id on file yet." where those strings live.
- [ ] Display-name change propagates: save, re-render, assert — at
  the reproduced defect layer, not just the helper.

## Warts / traps

- The catalog seam degrades when the gateway is unreachable
  (CATALOG_DEGRADED_NOTE pattern) — the resolution seam must degrade
  the same honest way, never render a modern member as scopeless
  because one request failed. State the degraded rendering.
- Do not build per-scope enrollment UI (deck.ts's documented
  deferral) — this is display resolution, not enrollment redesign.
- Do not touch the download/enrolment flows shipped this week
  (prefetch/POST-form work).
- PR.md carries before/after renders (ASCII or textual DOM excerpts)
  of the campaign pooling row and fleet ops row for the Glen-shaped
  fixture — experience-layer evidence, not just green tests.
- `docs/design/**` is read-only law.

Finish: `/workspace/PR.md` with the consumer audit table, the
reproduced root cause of bug 1 stated plainly, before/after renders,
and the degraded-catalog rendering note.
