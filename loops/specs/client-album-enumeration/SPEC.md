# SPEC — client-album-enumeration: discover every frame, not one per album

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Fixes issue **#178**. Read that issue first — especially the two
comments recording the root cause and the firmware probe. The probe
numbers below were measured live against Casey's scope on 2026-08-04
and are ground truth, not inference.

## The bug

`fetch.Discover` emits **one Item per album**, not per frame. Roughly
**920 of 1658** M13 frames have never been uploaded, and no code path
exists that could fetch them.

```
get_albums                              ->  1,019 bytes, 7 entries
  each entry is an ALBUM: {name, thn, count, type}
  e.g. name="M 13_sub"  count=1658
```

`Discover` walks those seven and derives a stem from each album's
single `thn`. So the client only ever sees an album's **current
representative file**.

During live capture that works — each new frame becomes the
representative and is picked up within the 30 s tick. That is exactly
how the 738 frames we do hold arrived, one at a time. Anything not
caught live is invisible forever: frames captured while the client was
down, or during the 2.5 h the file port was unreachable.

## What actually works (measured)

`get_albums` accepts a **`name` parameter, fully qualified**:

```json
{"method":"get_albums","params":{"name":"MyWorks/M 13_sub"}}
```
```
path="MyWorks/M 13_sub"   entries=6   files=1658   (279,547 bytes)
   Light_M 13_20.0s_IRCUT_20260803-235408.fit
   Light_M 13_20.0s_IRCUT_20260803-235326.fit
   ...
```

**The file list spans 6 entries — flatten `list[]`, do not read
`list[0]`.**

### The failure modes are silent, and that is the point

| params | result |
|---|---|
| `{"name":"MyWorks/M 13_sub"}` | **1658 files** |
| `{"name":"M 13_sub"}` (no prefix) | echoes `path`, **0 entries** |
| `{"path":"MyWorks/M 13_sub"}` | key ignored, returns **root listing** |
| `{"name":...,"start":0,"count":50}` | 0 entries — no pagination found |

An unrecognised key is ignored and you get the root listing; a
recognised key with a bad value returns zero entries. **Neither is an
error.** Every wrong call returns something that looks valid — which is
how this survived. Your code must be able to tell "this album is empty"
from "I asked wrongly": if a per-album call returns 0 files for an
album whose root `count` is non-zero, that is a **bug, not an empty
album**, and must be loud.

## What to build

### 1. Two-level discovery

Root listing per tick to learn album names and counts; per-album
enumeration to get real files. Emit one Item per actual frame.

### 2. `count` drives both the trigger and the alarm

The root listing carries the authoritative per-album total on every
poll, for free.

- **Trigger**: only re-enumerate an album whose `count` has changed
  since last seen. The per-album response is **279 KB against 1 KB** —
  enumerating everything every 30 s is ~1.4 MB/min of RPC for data that
  rarely changes. Do not do that.
- **Alarm**: compare `count` against what has been delivered for that
  album. A persistent shortfall is the condition that went unnoticed
  for weeks. Surface it — a number in the client's own view, and
  something the JSON-lines path emits. `AlbumFile.Count` is currently
  declared and **never read anywhere in the codebase**; that is the
  whole issue in one line.

### 3. Backfill

A deliberate, resumable pass that enumerates every album and fetches
everything not already delivered. Roughly 920 M13 frames plus smaller
gaps (rho-herculis 36 held/81 on scope, nu-coronae-borealis 21/28).

It must be **restartable without re-fetching** what already landed, and
must respect the existing buffer backpressure — this is ~40 GB of
frames, not a burst to fire at the gateway unthrottled.

Whether it runs automatically or behind a flag is your call: justify it
in PR.md. Automatic is friendlier; explicit is safer given the volume.

### 4. Device-rejected frames still skip

`deviceRejected` (the `_failed_` marker) already gates fetching. Keep
it. The enumeration will surface many `..._failed_...fit` names — the
oldest frame I fetched by hand was one. They must not ship.

## Tests

- [ ] Discovery of an album with N files yields **N Items**, not one.
      Cover the multi-entry shape: files spread across `list[]` entries
      must all be found.
- [ ] An album whose root `count` is non-zero but which enumerates to 0
      files is reported as an **error**, not silently treated as empty.
- [ ] An album whose `count` is unchanged is **not** re-enumerated —
      assert on the number of RPC calls, not on timing.
- [ ] An album whose `count` grew **is** re-enumerated.
- [ ] The shortfall (`count` vs delivered) is computed and exposed.
- [ ] Backfill is resumable: interrupt it, restart, and already-fetched
      frames are not re-fetched.
- [ ] `_failed_`-marked frames are still skipped.
- [ ] Full gate green including `-race`, 0 skips from anything touched.

## Warts / traps

- **Nothing in this loop talks to a real scope.** Extend
  `agent/internal/fakescope` to serve the two-level shape, including
  the multi-entry file list and the silent-failure cases above.
- The scope caps concurrent verified clients — the fleet reaches it
  through `seestar-proxy`, never directly. Do not add code that dials
  the scope's own address.
- Do not change the uploader, the gateway, or the combine path.
- `AlbumFile.Type` arrives as a JSON number in some firmware and a
  string in others (`docs/seestar-fleet-context.md` §136) — the
  existing `Scalar` type handles it. Do not regress that.

Finish: `/workspace/PR.md` with the two-level flow, the RPC-call-count
evidence that unchanged albums are not re-enumerated, how a shortfall
surfaces, the backfill's resumability proof, and the
automatic-vs-explicit decision with its reasoning.
