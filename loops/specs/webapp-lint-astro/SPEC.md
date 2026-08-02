# SPEC — webapp-lint-astro: the linter cannot see half the codebase

Repo: `loop-bot/tychofleet`. Gate: `make build test lint`.

## The failure

`biome.json:11` excludes every `.astro` file:

```json
"includes": [..., "!**/*.astro"]
```

`pnpm lint` reports *"Checked 233 files."* Run it against
`src/pages/scopes/index.astro` and it reports **"Checked 0 files."**

That is ~50 pages, components and layouts — including **every
client-side `<script>` block** — never linted. And `pnpm lint` runs
`tsc --noEmit` but **not** `astro check`, so `.astro` template types are
only ever checked inside `make build`.

Real consequences already in the tree, none reachable by the linter:

- `ScopeDeckCards.astro` — a `card.querySelector("span.font-sans")` DOM
  coupling that breaks on any class change
- the same file's rename handler: `catch {}` swallowing a 400 and a 503
  identically, silently reverting with no message
- `setup.astro` — a `setInterval` poll that is never cleared, has no
  backoff or cap, and does not stop on 401

## What to build

### 1. Lint `.astro`

Remove the exclusion. Biome supports `.astro` — confirm what it does and
does not check there (it lints the frontmatter and script blocks; it is
not a full template linter) and **say so plainly in PR.md**, so nobody
later assumes more coverage than exists.

### 2. `astro check` in the lint gate

Add it to `make lint`, so template types are checked by the gate rather
than only as a side effect of building.

### 3. Fix what this uncovers — but scope it

Turning the linter on ~50 unlinted files will surface a lot. **Do not
sprawl.** Rules:

- Fix everything that is a genuine defect or a real correctness risk.
- For stylistic noise, prefer configuring the rule over rewriting fifty
  files. Say what you disabled and why.
- **If the volume is large, fix the defects and land the config with the
  noisy rules off, listing them in PR.md as follow-up.** A lint gate that
  is on for real code beats a perfect one that never lands.

Report the count: how many diagnostics appeared, how many were real,
how many you fixed, how many you deferred.

### 4. The three named above

Whatever else you defer, these three are real and should be fixed:
the brittle DOM selector, the error-swallowing `catch {}` (a rejected
request and an unreachable service must read differently — that
distinction is load-bearing in this codebase and was a production bug),
and the uncleared interval that never stops on 401.

## Tests

- [ ] `pnpm lint` reports a file count that includes `.astro` files —
  assert the number is not 233.
- [ ] `make lint` fails on a deliberately broken `.astro` file. Add one
  temporarily, confirm the gate catches it, remove it, describe it in
  PR.md. A gate that cannot fail is the thing we are fixing.
- [ ] The existing 863 tests still pass.

## Warts / traps

- Do not change behaviour while fixing lint, except for the three named
  defects. A rename that silently alters rendering is worse than a lint
  warning.
- Do not touch enrolment, key minting, the scope API, the download route
  or authorization — all shipped and verified against the live gateway.
- `docs/design/**` is read-only law.

Finish: `/workspace/PR.md` with the before/after file counts, the
diagnostic tally, exactly which rules you disabled and why, proof the
gate now fails on a broken `.astro`, and the three named fixes.
