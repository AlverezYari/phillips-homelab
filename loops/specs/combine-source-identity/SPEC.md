# SPEC — combine-source-identity: two members imaging the same target on the same night must get distinct combine Jobs and correct master bookkeeping

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Found by an external adversarial review (2026-08-09), verified line-by-line
in code before this SPEC was written. This is the alpha's primary scenario:
~5 members pointing S30s at the same shared monthly target. Two of them
imaging it on the same night is not an edge case — it is the intended use.

## The problem, proven

`SessionID` is `slug(target)-YYYY-MM-DD` — target + observing night, **no
source** (`agent/internal/uploader/session.go:30`). That is by design;
per-source identity was supposed to come from the CR name, which IS
source-qualified (`SessionCRName(sourceID, sessionID)`). But three places
still key on the bare sessionID:

1. **Combine Job names.** `ensureCombineJob` does
   `combinejob.Name(session.Spec.SessionID, revision)`
   (`operator/internal/sessionclose/sessionclose.go:437`). Two sources
   sharing a session id collide on the Job name. The repo already admits
   this — `operator/internal/sessionclose/sessionclose_test.go:345`:
   *"combinejob.Name is keyed on sessionID alone, so two sources sharing a
   session id still collide on the Job name; that is a separate, unfixed
   gap this test does not cover."* This SPEC is that fix.

2. **Existing-Job adoption is unconditional.** The Get-by-name /
   Create-hits-AlreadyExists path (`sessionclose.go:462` area) treats any
   existing Job with the expected name as "ours". So the second member's
   session adopts the first member's Job: it either sits `Combining`
   forever (its own Job never spawns) or `markDone` records a result key
   for its source that the adopted Job never wrote
   (`operator/internal/controller/combine_controller.go:192`).

3. **Master bookkeeping collapses sources.** `SessionRevision` is
   `{SessionID, Revision}` with no source
   (`operator/api/v1alpha1/targetmaster_types.go:52`), and
   `sameSessionRevisionSet` compares via a map keyed on SessionID alone
   (`operator/internal/controller/master_trigger.go:48`). Two sources with
   the same session id overwrite each other's map entry, so when their
   revisions differ the recorded set can NEVER compare equal to the
   candidate set — every completed master combine immediately looks stale
   and respawns. Endless rebuild loop on exactly the pooled-target shape
   the alpha exists to test. Construction sites:
   `operator/internal/controller/combine_trigger.go:155`,
   `master_trigger.go` (verify all of them, including master/fleet Job
   naming — the review claims `master-<target>` Jobs are also
   source-unqualified where they need not be; confirm from code which
   master types are per-source vs fleet-wide and qualify accordingly).

## What to build

1. **Source-qualified Job names everywhere.** Derive every combine Job
   name from the owning CR's already-source-qualified name plus revision,
   not from the bare sessionID. Respect the k8s 63-char limit the same way
   `SessionCRName` does (verify how it truncates/hashes and reuse that
   mechanism, don't invent a second one). Session combines, per-source
   master combines, and fleet combines each get names that cannot collide
   across sources.

2. **Owner-verified adoption.** Before treating an existing Job as "ours"
   (the idempotent-retry path — which is legitimate and must keep
   working), verify its owner reference points at the requesting CR (UID
   match), not just that the name matches. A mismatch is a loud error, not
   an adoption. With fix 1 this should be unreachable; it stays as defense
   in depth because the retry path's correctness currently rests entirely
   on the name.

3. **Contribution identity = (sourceID, sessionID, revision).** Add
   `SourceID` to `SessionRevision` (optional field — existing stored
   statuses must keep deserializing), thread it through every construction
   site, and key `sameSessionRevisionSet` on (SourceID, SessionID).
   Legacy status entries without a SourceID compare as stale — "rebuild
   once, then track correctly", exactly the rule the existing nil-set
   comment in `master_trigger.go:39` already established. Regenerate CRD
   manifests (`make manifests` or repo equivalent) — an additive optional
   status field is backward-compatible.

## Tests — red-first, the admitted gap becomes the assertion

- Turn `sessionclose_test.go:345`'s "NOT asserted here" comment into the
  assertion: two sources, same target, same night → **two distinct combine
  Jobs**, each owner-referenced to its own ImagingSession CR. Write it
  first, watch it fail on main's behavior, then fix.
- Adoption test: a Job bearing the expected name but a different owner UID
  is refused, and the idempotent-retry case (same owner, second call) is
  still accepted uncapped.
- Master stability test: two sources sharing a session id at UNEQUAL
  revisions → `sameSessionRevisionSet` compares correctly, exactly one
  master rebuild when a revision actually moves, and — the regression that
  matters — **zero** rebuilds when nothing changed (assert no respawn
  across a reconcile of an up-to-date master).
- Legacy-status test: a stored SessionRevision list without SourceIDs
  triggers exactly one rebuild, then tracks correctly.

## Out of scope

- Reopen/retention manifest sub_count loss, permanent-rejection upload
  workers, Job watchdog/activeDeadlineSeconds, event dead-lettering,
  gateway health — real findings from the same review, separate loops.
- No behavior change to #214's v1-sub path or #210's resilience fixes.
- No change to `SessionID`'s wire format itself — clients in the field
  compute it; identity is fixed operator-side.

## Definition of done

Gate green with real test output pasted into PR.md (venv tests on the
combine venv where applicable — no fixture-gated fake-green). PR.md states
what changed, how it was verified, and the upgrade note: in-flight Jobs
under old-style names are treated as stale after deploy, so the image
bump should land at a quiet moment (before alpha onboarding this is
free). A reviewer who has read the external review's finding 1 and 4
should be able to check each cited line and find it fixed.
