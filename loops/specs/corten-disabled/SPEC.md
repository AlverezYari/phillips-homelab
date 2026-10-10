# SPEC — corten-disabled: disabled nodes and the manifest's `disabled` section

Repo: `loop-bot/corten`. Gate: `make build test lint`. Image: `corten-1` (spawn with
`--image corten-1`; the default image has no Rust and no dbt).

## The failure

Corten refuses any node whose config resolves to `enabled: false`
(`src/parse/nodes.rs`, "is disabled; disabled nodes are not supported yet"). Disabled
nodes are common in real projects; the corpus inventories (`audit/1.12.5/*.json`,
`inventory.disabled`) count them in six of ten projects: tuva 116, dbt_project_evaluator
30, stripe 27, dbt_utils 1, dbt_expectations 1, dbt_date 1. dbt_date already hits it
indirectly:

```
dbt_date_integration_tests: models/test_compile_time_disabled.sql: invalid operation: calls
  exceptions.raise_compiler_error(); this needs Jinja rendering ...
```

That model is disabled; dbt evidently does not fail on it the way Corten does. Find out
exactly why (when dbt decides a node is disabled, and what it still renders).

## Why

Corten's one rule (read `CLAUDE.md`): for every project dbt accepts, Corten's manifest is
**identical** to dbt's or Corten **refuses**. The gate checks it. dbt moves disabled nodes
into the manifest's `disabled` section (a map from unique id to a **list** of nodes),
leaves them out of `nodes`, graph maps and ref resolution in specific ways, and handles
generic tests attached to disabled nodes, refs to disabled nodes, and disabled sources,
each with its own rules.

## What to build

- [ ] **Probe and record** against the pinned dbt and dbt-core source
  (`dbt/parser/manifest.py`, `dbt/contracts/graph/manifest.py` `add_disabled`,
  `disabled_lookup`, `dbt/parser/base.py`): every way a node becomes disabled (project
  config at each level, YAML config, SQL `config(enabled=false)`, `+enabled` with Jinja),
  at which point dbt decides it, whether the node's SQL is rendered (and what happens to
  errors raised while rendering a disabled node), the exact shape of entries in
  `disabled` (why a list, ordering, fields present), how generic tests on disabled models
  and tests that ref disabled models behave, refs to disabled nodes (error vs warning),
  `parent_map`/`child_map`, disabled seeds, analyses, singular tests, sources (if
  `corten-sources` has landed) and versioned duplicates. Each fact gets a `Probed against
  dbt 1.12.5: ...` test comment and a write-up in `docs/probes/`.
- [ ] **Implement disabled nodes** and the `disabled` section, lifting the refusal.
- [ ] **Generate it.** Extend `harness/gen_project.py` with disabled nodes from every
  source, tests on disabled models, refs to disabled models (only where dbt accepts the
  project), and disabled package nodes. Remove `disabled_model` from `UNSUPPORTED`.
- [ ] **Corpus.** Re-run `harness/audit.py`, commit the records, report the `--refusals`
  tally before and after and which corpus projects became identical.

## Tests

- [ ] Every probed fact has a test that fails if Corten gets it wrong.
- [ ] `make test` green: no `DIVERGED`, no `CRASH`, no missed refusal; `audit.py --property`
  and `fuzz.py --regressions` pass.
- [ ] Before finishing, run 1000 fresh seeds as four chunks, each its own foreground command:
  `harness/fuzz.py --start 32000 --seeds 250`, then `--start 32250`, `--start 32500`,
  `--start 32750`. Put the four summaries in PR.md. Any seed that diverges goes into
  `harness/fuzz_regressions.txt` with a one-line cause, after it is fixed.

## Warts / traps

- **Keep every single command under about 8 minutes.** Claude Code's Bash tool moves longer
  commands to the background, and they die when your iteration ends (shared `gotchas.md`).
- Enabled-only projects must stay byte-identical; they are the common case and heavily
  fuzzed.
- dbt quirks that look like bugs are matched, not fixed; cite the dbt function.
- The harness pins `TZ=UTC`, `LC_ALL=C.UTF-8` and `PYTHONHASHSEED=0`; never compare against
  dbt outside it.
- `harness/normalize.py` and the normalization in `tests/parity.rs` must not change. If the
  order of a `disabled` list turns out to be nondeterministic in dbt itself, report it in
  PR.md with evidence; do not normalize it without that evidence.
- Never hand-edit `audit/`. Regenerate it with the harness.
- Editing `UNSUPPORTED` in the generator reshuffles every seed.
- Clean room: dbt-core, dbt-adapters, dbt-common, Jinja2 and minijinja sources are fine to
  read; never dbt Fusion.
- Prefer the simplest reading of `CLAUDE.md` over filing decisions.
- The word "verified" may only describe something the gate or a probe actually checked.

Finish: `/workspace/PR.md` with the probed rules, what is still refused and why, the
refusal tally before and after, corpus projects that became identical, and the four fuzz
chunk summaries.
