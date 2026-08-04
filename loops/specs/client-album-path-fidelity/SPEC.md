# SPEC — client-album-path-fidelity: the fake must match the device

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Fixes a regression shipped in **tycho-client v0.9.0** (PR #179, issue
#178). **v0.9.0 fetches nothing at all** — every frame 404s, live
capture included. It is worse than v0.8.0 and must not be run.

The previous SPEC was wrong, and this one says how, because the same
mistake is what made a green gate meaningless.

## What v0.9.0 does

Two-level discovery landed and works: the client enumerates all 1658
frames. Then every fetch 404s, silently — `Fetch` logs a warning and
the loop continues, so the client discovers everything and downloads
nothing.

## The cause, measured on the live device

The **root** listing returns album-relative `thn`:

```
thn = "M 13_sub/Light_M 13_..._thn.jpg"
```

A **per-album** call returns a **bare filename**, because the album was
already in the request:

```
{"method":"get_albums","params":{"name":"MyWorks/M 13_sub"}}
  -> thn = "Light_M 13_20.0s_IRCUT_20260803-235408_thn.jpg"
```

`itemsFromFiles` derives `Item.Stem` from `thn` unchanged, so the fetch
URL loses its directory segment. Proven on the wire, same frame:

```
GET /MyWorks/Light_M 13_20.0s_IRCUT_20260803-235408.fit            -> 404
GET /MyWorks/M 13_sub/Light_M 13_20.0s_IRCUT_20260803-235408.fit   -> 200, 16,594,560 b
```

## Why every test passed anyway — read this part

`fakescope` serves its HTTP files **flat**, at `/MyWorks/<stem>.fit`,
keyed by stem. The real device nests them at
`/MyWorks/<album>/<file>.fit`.

So the fake matched the previous SPEC's description rather than the
device. Every test in #179 passed — including the ones written
specifically to catch discovery bugs — because they all measured
against a wrong model. **A green gate against an unfaithful fake is
exactly as useful as no gate.**

That is the actual defect to fix here. The stem prefix is three lines.

## What to build

### 1. Make the fake nest files the way the device does

`fakescope`'s HTTP file server must serve at
`/MyWorks/<album>/<file>.fit`, and its per-album `get_albums` must
return **bare** `thn` values while the root listing returns
album-relative ones. That asymmetry is the device's real behaviour and
the fake must reproduce it.

This will break existing tests. **They are broken already** — they
assert against a shape the device does not have. Fix them to the real
shape; do not adjust the fake to keep them passing.

### 2. Prefix the album onto bare stems

In `itemsFromFiles`, when the caller enumerated a specific album and the
stem carries no `/`, prefix the album. Root-listing stems already carry
their album and must not be double-prefixed.

Both call paths need it: `Enumerator.Poll` and `Backfill`.

### 3. A fakescope fidelity test, pinned to the live probe

The durable fix. A test asserting the fake's shape matches what the
device actually returned, recorded 2026-08-04 against the scope:

- root `get_albums` (no params): 7 entries across 2 `list` elements;
  each is an **album** `{name, thn, count, type}`, `count` is the frame
  total (`M 13_sub` = 1658), `thn` is **album-relative**
- per-album `{"name":"MyWorks/M 13_sub"}`: 1658 files spread across
  **6** `list` entries, `thn` **bare**, `count` absent per file
- `{"name":"M 13_sub"}` (unqualified): echoes `path`, **0 entries**, no
  error
- `{"path":"MyWorks/M 13_sub"}`: key ignored, returns the **root**
  listing
- `{"name":...,"start":0,"count":50}`: 0 entries — no pagination

If the fake ever stops modelling any of these, that test goes red.
Write it so a reader can see it is a record of observed device
behaviour, not an invention.

### 4. An end-to-end test that would have caught the 404

A test that drives discovery through fetch against the fake and asserts
the **bytes actually land** for a frame in a nested album. The existing
e2e tests pass with a flat fake; one that mirrors the device's nesting
is what fails on an unprefixed stem.

## Tests

- [ ] Per-album bare stems are prefixed; root stems are not
  double-prefixed.
- [ ] The fidelity test above, covering all five observed behaviours.
- [ ] End-to-end: a frame in a nested album is discovered **and its
  bytes land**. Verify it fails without the prefix — show the failure
  in PR.md.
- [ ] `Backfill` fetches from nested albums too.
- [ ] The existing `-race` e2e suite passes against the corrected fake.
- [ ] Full gate green, 0 skips from anything touched.

## Warts / traps

- **Do not weaken the fake to keep old tests green.** If a test fails
  against the faithful fake, that test was wrong.
- No live device access. Everything above is recorded observation; the
  probe numbers are ground truth.
- The scope caps concurrent verified clients and the fleet reaches it
  through `seestar-proxy` — no code may dial the scope directly.
- Do not change the uploader, gateway, or combine path.
- v0.9.0 is released and broken. Say plainly in PR.md that a new client
  release is required, and that v0.9.0 should not be run.

Finish: `/workspace/PR.md` with the failing-without-the-prefix e2e
output, the fidelity test's mapping to each observed behaviour, and
what changed in the fake.
