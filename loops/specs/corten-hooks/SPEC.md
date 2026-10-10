# SPEC — corten-hooks: node hooks and on-run-start / on-run-end

Repo: `loop-bot/corten`. Gate: `make build test lint`. Image: `corten-1` (spawn with
`--image corten-1`; the default image has no Rust and no dbt).

## The failure

Corten refuses every hook. The corpus shows both kinds:

```
tuva_integration_tests: package integration_tests: dbt_project.yml: `on-run-start` hooks are not supported yet
```

Tuva's (verbatim, `integration_tests/dbt_project.yml`):

```yaml
on-run-start:
  - "{{ ensure_target_schema_for_unit_tests() }}"
```

and dbt_utils' seed hook (`seeds: ... +post-hook: "{% do adapter.drop_relation(this.incorporate(type='table')) %}"`)
plus the generator's `model_hook` feature (`config(post_hook='select 1')`) hit the node
hook refusal (`<id> has a post-hook; hooks are not supported yet`, `src/parse/nodes.rs`).

## Why

Corten's one rule (read `CLAUDE.md`): for every project dbt accepts, Corten's manifest is
**identical** to dbt's or Corten **refuses**. The gate checks it. Hooks touch the manifest
in several places: node hooks become `config.pre-hook` / `config.post-hook` entries
(objects with `sql`, `transaction`, `index`; probed earlier: the raw string stays in
`unrendered_config`), and dbt **renders each hook at parse time** to collect refs and
sources (`update_parsed_node_config` in `dbt/parser/base.py`). `on-run-start` /
`on-run-end` become their own `operation` nodes (`dbt/parser/hooks.py`), with their own
unique ids, fqn, `depends_on` and ordering.

## What to build

- [ ] **Probe and record** against the pinned dbt and dbt-core source
  (`dbt/parser/base.py` `_mangle_hooks` and hook rendering, `dbt/parser/hooks.py`,
  `Hook` in `dbt/artifacts/resources`): the manifest shape of node hooks from every
  source (project config at each level, YAML config, SQL `config()`, `pre_hook` vs
  `pre-hook`, string vs list vs dict-with-`transaction`), merge order, `index` values,
  what rendering a hook at parse time records (refs, sources, macros, onto which node),
  what a hook's Jinja may and may not do at parse time; and the full shape of
  `on-run-start` / `on-run-end` operation nodes (unique id, name, fqn, path, `index`,
  `depends_on`, root vs package hooks, ordering across packages). Each fact gets a
  `Probed against dbt 1.12.5: ...` test comment and a write-up in `docs/probes/`.
- [ ] **Implement node hooks** and lift their refusal.
- [ ] **Implement on-run-start / on-run-end** operation nodes and lift their refusal
  (`src/parse/guard.rs`).
- [ ] **Generate it.** Extend `harness/gen_project.py` with hooks at every level and
  form, hooks with Jinja that calls macros or refs, and on-run hooks in the root project
  and packages. Remove `model_hook` and `on_run_start` from `UNSUPPORTED`.
- [ ] **Corpus.** Re-run `harness/audit.py`, commit the records, report the `--refusals`
  tally before and after and which corpus projects became identical.

## Tests

- [ ] Every probed fact has a test that fails if Corten gets it wrong.
- [ ] `make test` green: no `DIVERGED`, no `CRASH`, no missed refusal; `audit.py --property`
  and `fuzz.py --regressions` pass.
- [ ] Before finishing, run 1000 fresh seeds as four chunks, each its own foreground command:
  `harness/fuzz.py --start 24000 --seeds 250`, then `--start 24250`, `--start 24500`,
  `--start 24750`. Put the four summaries in PR.md. Any seed that diverges goes into
  `harness/fuzz_regressions.txt` with a one-line cause, after it is fixed.

## Warts / traps

- **Keep every single command under about 8 minutes.** Claude Code's Bash tool moves longer
  commands to the background, and they die when your iteration ends (shared `gotchas.md`).
- Hook Jinja is rendered by dbt at parse time with the node's context; reuse the renderer
  (`src/jinja/render.rs`), and refuse what it cannot do exactly.
- dbt quirks that look like bugs are matched, not fixed; cite the dbt function.
- The harness pins `TZ=UTC`, `LC_ALL=C.UTF-8` and `PYTHONHASHSEED=0`; never compare against
  dbt outside it.
- `harness/normalize.py` and the normalization in `tests/parity.rs` must not change.
- Never hand-edit `audit/`. Regenerate it with the harness.
- Editing `UNSUPPORTED` in the generator reshuffles every seed.
- Clean room: dbt-core, dbt-adapters, dbt-common, Jinja2 and minijinja sources are fine to
  read; never dbt Fusion.
- Prefer the simplest reading of `CLAUDE.md` over filing decisions.
- The word "verified" may only describe something the gate or a probe actually checked.

Finish: `/workspace/PR.md` with the probed hook rules, what is still refused and why, the
refusal tally before and after, corpus projects that became identical, and the four fuzz
chunk summaries.
