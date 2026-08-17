# SPEC — operator-unknown-target-quarantine: no-target frames must not become targets

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

## The failure (real member, 2026-08-17)

Member Glen's Seestar carried July frames shot without a named target
— the firmware names these `Light_Unknown_...` with OBJECT "Unknown".
The client uploaded them (correct: archive everything), the gateway
accepted them into sessions `unknown-2026-07-21` / `unknown-2026-07-23`
(correct), the session stacker stacked them (acceptable) — and then
the master trigger treated **"unknown" as a target identity**:
TargetMaster `master-scp-97358c6b-unknown` pooled BOTH nights (almost
certainly different sky coordinates), spawned five master combine
Jobs, all Failed, retry budget exhausted (Attempts=5). The m-13
quota-churn incident's shape, reborn via a garbage target name — and
had a second member shot untargeted frames, the FleetMaster layer
would pool "unknown" ACROSS members.

## What to build

### 1. Quarantine placeholder target identities at the master triggers

A single predicate (e.g. `targetmaster.IsPlaceholderTarget(slug)`)
true for "unknown" (case-insensitive, the firmware's placeholder) and
empty/whitespace slugs. Both the per-source master trigger
(`operator/internal/controller/master_trigger.go`,
ensureMasterCombineForKey's key.Target guard is the natural seat —
it already skips empty) and the FleetMaster trigger path skip
placeholder targets: no TargetMaster/FleetMaster CR creation, no
master combine spawn. Log once per session at INFO with a reason,
not silently.

Session-level behavior is unchanged: unknown-target subs still
archive, still session-stack (harmless, per-night, single-coordinate
in practice), still count in per-source storage. This quarantine is
about cross-night/cross-member POOLING identity only.

### 2. Existing garbage goes terminal, honestly

Placeholder-target TargetMaster/FleetMaster CRs that already exist
(e.g. `master-scp-97358c6b-unknown`, Failed, Attempts=5) must not
revive: the trigger skip covers new spawns, and the retrier/periodic
paths must also skip placeholder-target CRs so growth events can
never re-arm them. Document (PR.md) the one-time operator cleanup for
the CRs + failed Jobs (delete commands), rather than automating
deletion in this loop.

### 3. File the real design as a decision, don't build it

The correct long-term identity for pooling is COORDINATES, not names
(the alpha-readiness audit's own conclusion): frames/sessions pooled
by sky position with named targets as labels. That is a design change
touching session naming, master keying, and fleet pooling — write it
as a `decisions/` file with options (coordinate-clustered target
keys; name-with-coordinate-verification; status quo + quarantine) and
a recommendation, for founder sign-off. This loop ships only the
quarantine.

### 4. Bounded secondary: the zero-input session result

`stack-scp-97358c6b-m-31-2026-07-23` recorded a session result with
`inputs: 0` and WARN "no completion report at combine time". Diagnose
why a combine produced/uploaded a result with no recorded inputs
(likely a device-stack-only session shape). If the behavior is
intended, assert it with a test + comment; if it is a bug with a
small fix, fix it; if large, write the finding in PR.md and stop.

## Tests

- [ ] Red first: a session close for target "Unknown" today reaches
  the master trigger and creates the CR/Job — assert the current
  broken behavior, then the skip.
- [ ] Predicate: "unknown"/"Unknown"/""/whitespace are placeholders;
  real slugs (m-31, sh2-157, c-20) are not.
- [ ] Both triggers (source master + fleet master) and the
  retrier/periodic paths skip placeholder targets; a growth event on
  an existing placeholder CR does not respawn.
- [ ] Session-level pipeline for unknown-target subs unchanged
  (stack job still spawns).
- [ ] The zero-input result behavior asserted per its diagnosis.

## Warts / traps

- Do NOT touch the combine engine (combine/), the fingerprint/GC
  work, or delivery. Operator trigger logic + the predicate only.
- Do not conflict with in-flight agent-side loops: nothing under
  agent/ should change here.
- The gateway accepting unknown-target uploads is CORRECT (archive
  everything) — do not add gateway-side rejection.
- `docs/design/**` is read-only law.

Finish: `/workspace/PR.md` with the trigger-path audit (every place a
target slug becomes a pooling identity), the one-time cleanup
commands, the coordinate-pooling decision file, and the zero-input
diagnosis.
