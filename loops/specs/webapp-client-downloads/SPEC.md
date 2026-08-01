# SPEC — webapp-client-downloads: the client has to be downloadable

Repo: `loop-bot/tychofleet`. Gate: `make build test lint`.

## The failure

Setup screen 3 (`/scopes/{id}/setup`, shipped in PR #44) says
"Download scopeTUI" and links at Forgejo release assets. `loop-bot/tycho`
is a **private repo**, so a signed-out browser gets:

```
GET .../releases/download/scopetui-v0.3.0/...windows-amd64.zip
  HTTP 404
```

Not the listing — the **binary itself**. A real user cannot obtain the
client at all, which means step 1 of onboarding is a dead end and every
screen after it is unreachable.

`src/lib/gateway/releases.ts` currently calls Forgejo's API. It already
degrades honestly (`unreachable` / `not-available`, never a broken
link), which is why the page doesn't lie today. That module is what
this loop replaces.

## The fix: serve the client from Garage, through the site

Release assets are published into the Garage bucket the site already
reads, under a `clients/` prefix:

```
clients/<tag>/<asset-filename>
e.g. clients/scopetui-v0.3.0/tycho-...-windows-amd64.zip
```

**No new credential.** The site already holds
`GARAGE_ACCESS_KEY_ID`/`GARAGE_SECRET_ACCESS_KEY` and already streams
Garage objects for master previews — reuse that path.

- A **signed-in member** can download. Signed-out gets the same
  treatment as any other member surface (redirect to login), not a 403
  blob and not a silent empty page.
- Reuse `/fleet/[slug]/master-preview.jpg`'s safety property exactly:
  **never stream an arbitrary key taken from a URL.** The route accepts
  a platform (and optionally a version), resolves it to a key against
  what actually exists, and streams only that. A caller must not be able
  to name a key and have it served.
- Stream it; do not buffer a 20 MB archive in memory to hand it back.

## Discovering what exists

The site must not hardcode filenames — they carry a version string that
changes every release, and today's are ugly for reasons unrelated to
this loop (`tycho-list-25-gdffbc71-windows-amd64.zip`; a stale git tag
pollutes `git describe`). Resolve by **listing the `clients/` prefix**
and matching on platform substring, the way `releases.ts` already does:

```
macos   -> "macos", "darwin"
linux   -> "linux"
windows -> "windows", ".exe"
```

Pick the newest tag present. Say in PR.md how you decide "newest" and
what happens when two assets match one platform (there are two macOS
builds — `darwin-amd64` and `darwin-arm64` — and a member on Apple
silicon must not be handed the Intel one; decide deliberately, and if
you offer both, label them in words a person understands rather than
`amd64`/`arm64` alone).

## The states, all of which must read honestly

| state | what the page says |
|---|---|
| asset found | a real download link |
| Garage reachable, no asset for this platform | plainly: no build for this platform yet |
| Garage unreachable | "couldn't check right now" — never a dead link |

A blank panel or a link that 404s is worse than an honest "not
available". This repo has shipped plausible-looking emptiness before;
do not add another.

## Tests

- [ ] A signed-out request to the download route does not stream bytes.
- [ ] A member downloading gets the asset for the platform they asked
  for, and **cannot** obtain a different object by manipulating the URL
  — assert an attempt to name an arbitrary key is refused.
- [ ] Each of the three states above renders its own distinct text.
- [ ] Listing finds the newest tag when several are present.
- [ ] No Forgejo call remains on the setup path — grep for it.

## Warts / traps

- Do not add a Forgejo token to this repo. The whole point is that the
  client is obtainable without one.
- Do not change the enrolment flow, the setup code, or the scope API —
  they work and were verified against the live gateway today.
- The 88 MB FITS download rule still stands elsewhere: streamed, never
  buffered. Same discipline here.
- `docs/design/**` is read-only law.

Finish: `/workspace/PR.md` with the resolved key for each platform, the
arm64-vs-amd64 decision, an ASCII render of screen 3 in all three
states, and proof that a URL naming an arbitrary object is refused.
