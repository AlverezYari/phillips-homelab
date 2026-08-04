# SPEC — delivery-filesource: the catalog is the source of truth for what ships

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Completes the deliberate gap left by PR #166: `FileSource` has an
interface and a test double, and no production implementation. Read
ADR 0010 and `docs/design/crowdsky-delivery-guards.md` first.

## The decision, already made

**Read the catalog, do not list S3.** Casey's call, and the reasons
are worth stating because they shape the implementation:

The `sub` table already holds everything a delivery needs, per row:

| column | why delivery needs it |
|---|---|
| `object_key` | where the bytes are |
| `checksum_sha256` | **G8's content hash, already computed** |
| `size_bytes` | admission can total the transfer *before* moving a byte |
| `status`, `reject_reason` | which frames the device itself rejected |
| `captured_at` | the far end's chunk key derives from `DATE-OBS` |
| `target_ra_deg`, `target_dec_deg` | chunk key's sky component |
| `frame_kind` | raw sub vs stack — the artifact class |

Three of those are decisive:

1. **`checksum_sha256` already exists.** Re-hashing every 16 MB sub to
   satisfy G8 would be pure waste, and a second hash computed a second
   way is a second thing that can disagree.
2. **`size_bytes` makes admission honest.** ADR 0010 §4 requires a
   refusal *before a byte moves*. Listing S3 could give this too, but
   the catalog gives it in one query alongside everything else.
3. **`status`/`reject_reason` are what make G4 real.** The catalog
   already records `device_marked_failed` for frames the scope itself
   rejected — 21 of 21 for `nu-coronae-borealis-2026-07-27`. Those must
   never ship. Shipping frames the device rejected wastes the far end's
   worker on data we already know is bad, and it is the sort of thing
   that gets an uploader distrusted.

S3 still supplies the **bytes**. The catalog supplies the **list and
the facts about it**. Do not re-derive from object storage anything the
catalog already knows.

## What to build

### 1. A catalog-backed `FileSource`

Implements the existing interface. Given a session and an artifact
class, returns the files to send with their content hashes and sizes.

**Excludes anything the catalog marks rejected.** A rejected frame is
not an error and not a silent drop — it is a *reported* skip, visible
on the `Delivery` so a member can see "412 sent, 21 skipped: device
marked failed" rather than wondering where 21 frames went.

### 2. Artifact class selection

`raw_subs` and `stacks` are distinguishable in the catalog
(`frame_kind`). Map the artifact class to a query, and reject a request
for a class the session has none of, rather than delivering zero files
and reporting success.

### 3. Wire the operator's access

The operator manager process **must not** query Postgres directly if
that breaks the repo's existing convention — check
`combinejob.Config`'s and `targetmaster/query.go`'s doc comments, which
PR #166 cited as saying the manager never touches object storage, and
work out what the equivalent rule is for the catalog. Follow whatever
the established pattern is; if there is genuine ambiguity, say so in
PR.md and pick the option that keeps the manager thinnest.

### 4. Admission uses real sizes

Now that `size_bytes` is available before transfer, the admission check
in the controller should total the actual bytes a delivery would move
and refuse against the member's allowance, rather than any placeholder
PR #166 may have used. A refusal names the limit and the total.

## Tests

- [ ] A session with device-rejected frames delivers only the accepted
  ones, and the skip count with its reason is visible on the Delivery
  status.
- [ ] Content hashes come from `checksum_sha256` and are not recomputed
  — assert that no read of object bytes happens during listing.
- [ ] An artifact class the session has no frames for is refused, not
  reported as a successful empty delivery.
- [ ] Admission totals real sizes and refuses over-allowance before any
  file is sent — the fake adapter receives nothing.
- [ ] Postgres-backed tests run against the real catalog leg, not a
  mock. This is a query-layer change; a mocked query proves nothing.
- [ ] Full gate green including `-race`, Postgres and S3 legs, 0 skips.

## Warts / traps

- **No network to any third party.** Still framework-only; the fake
  adapter remains the only adapter.
- `grep -ri crowdsky operator/` must still return nothing.
- Do not change the guard mechanism (`Guarded`/`Binder`) landed in
  #168, the CRDs, or the ledger semantics.
- The `sub` table is written by the gateway. Delivery **reads** it. Do
  not add delivery-specific columns to it in this loop; if you find you
  need one, say so in PR.md rather than adding it.
- A session's frames can be large and numerous (359 subs is a real
  session in this archive). Listing must not load bytes.

Finish: `/workspace/PR.md` with the query, how rejected frames surface
to the member, proof that hashes are read rather than recomputed, a
worked admission refusal with real numbers, and confirmation the
Postgres leg actually ran.
