# SPEC — corten-hooks-2: the hook divergences the fixed generator exposes

Repo: `loop-bot/corten`. Gate: `make build test lint`. Image: `corten-1` (spawn with
`--image corten-1`; the default image has no Rust and no dbt).

## Start here

This loop continues `corten-hooks`, which never merged. **Your first action:**
`git fetch origin && git merge --no-edit origin/loop/corten-hooks` on your branch, then
read `docs/probes/hooks.md` and that branch's history. Its last commit (`2ffba93`, from
review) fixes a generator bug: `hook_kwarg_value` single-quoted hook bodies that contain
single quotes (`ref('x')`), so dbt rejected ~55% of generated projects as invalid Jinja
and hook coverage was mostly fake. With the fix, seeds 100000-100999 show **13
DIVERGED**:

```
100036 100197 100292 100415 100439 100447 100473 100494 100620 100713 100717 100747 100837
```

Three shapes (from `harness/fuzz.py --start <seed> --seeds 1 -v`):

1. **Ref order** (100036, 100415): `depends_on.nodes` / `refs` order differs when a node
   has hook refs and body refs. Corten puts them in a different order from dbt.
2. **`unrendered_config` keys missing** (100197, 100620): a SQL `config(...)` call with
   a double-quoted hook (`pre_hook=[{'sql': "select ..."}]`) — dbt records `alias`,
   `docs`, `pre_hook`, `quoting` in `unrendered_config`; Corten records none. Likely the
   static parser (dbt-extractor) rejects that call and dbt takes the rendered path; find
   out exactly.
3. **`unrendered_config` value shape** (100292, 100837): dbt keeps the hook list as
   source text (`"[\"select 'visit'\", \"select 'payment'\"]"`); Corten writes a JSON
   list.

Classify the other seeds; some may be new shapes.

## Why

Corten's one rule (read `CLAUDE.md`): for every project dbt accepts, Corten's manifest is
**identical** to dbt's or Corten **refuses**. These 13 seeds are wrong outputs.

## What to build

- [ ] **Merge** `origin/loop/corten-hooks` (above) and confirm the 13 seeds reproduce.
- [ ] **Probe and record** each shape against the pinned dbt and dbt-core /
  dbt-extractor source (where hook refs are recorded relative to body refs; which
  `config()` calls the static parser accepts and what the rendered path records in
  `unrendered_config`; the string-vs-structure rule for `unrendered_config` values).
  Each fact gets a `Probed against dbt 1.12.5: ...` test comment and a section in
  `docs/probes/hooks.md`.
- [ ] **Fix** each shape exactly, or refuse precisely what can't be reproduced. Add every
  fixed seed to `harness/fuzz_regressions.txt` with a one-line cause.
- [ ] **Corpus.** Re-run `harness/audit.py`, commit the records.

## Tests

- [ ] Every probed fact has a test that fails if Corten gets it wrong.
- [ ] `make test` green: no `DIVERGED`, no `CRASH`, no missed refusal; `audit.py --property`
  and `fuzz.py --regressions` pass.
- [ ] Before finishing, run 1000 fresh seeds as four chunks, each its own foreground command:
  `harness/fuzz.py --start 40000 --seeds 250`, then `--start 40250`, `--start 40500`,
  `--start 40750`, plus the four chunks starting at 100000 (the seeds above). Put all
  summaries in PR.md. The `invalid` count per chunk must stay low (it was about 10 of
  250 before hooks); a jump means the generator emits projects dbt rejects, which hides
  coverage. Find out why and fix the generator.

## Warts / traps

- **Keep every single command under about 8 minutes.** Claude Code's Bash tool moves longer
  commands to the background, and they die when your iteration ends (shared `gotchas.md`).
- Hook-free projects must stay byte-identical.
- dbt quirks that look like bugs are matched, not fixed; cite the dbt function.
- The harness pins `TZ=UTC`, `LC_ALL=C.UTF-8` and `PYTHONHASHSEED=0`; never compare against
  dbt outside it.
- `harness/normalize.py` and the normalization in `tests/parity.rs` must not change.
- Never hand-edit `audit/`. Regenerate it with the harness.
- Editing `UNSUPPORTED` in the generator reshuffles every seed; the seed list above is
  only valid while it is unchanged.
- Clean room: dbt-core, dbt-adapters, dbt-common, dbt-extractor, Jinja2 and minijinja
  sources are fine to read; never dbt Fusion.
- The word "verified" may only describe something the gate or a probe actually checked.

Finish: `/workspace/PR.md` covering everything on the branch (corten-hooks' work plus
this loop's): the probed hook rules, what is still refused and why, the refusal tally
before and after, corpus projects that became identical, and the fuzz chunk summaries.
