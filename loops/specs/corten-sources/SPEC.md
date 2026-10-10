# SPEC — corten-sources: `sources:` in schema YAML

Repo: `loop-bot/corten`. Gate: `make build test lint`. Image: `corten-1` (spawn with
`--image corten-1`; the default image has no Rust and no dbt).

## The failure

Rendering now carries stripe far enough to hit a basic dbt feature Corten never built:

```
stripe_integration_tests: models/staging/src_stripe.yml: the `sources` property is not supported yet
```

Sources are in most real dbt projects. Four corpus projects define them (inventory in
`audit/1.12.5/*.json`): stripe 27, dbt_project_evaluator 8, tuva 3, codegen 2. Corten
refuses the `sources` key (`src/parse/guard.rs` `TOP_LEVEL_KEYS`) and any `source()` call
(`src/parse/nodes.rs`, "sources are not supported yet").

## Why

Corten's one rule (read `CLAUDE.md`): for every project dbt accepts, Corten's manifest is
**identical** to dbt's or Corten **refuses**. The gate checks it. Sources touch a lot of
the manifest: the `sources` section (one entry per table, unique id
`source.<package>.<source>.<table>`), every node's `sources` and `depends_on.nodes`,
`parent_map`/`child_map`, generic tests on sources and their columns (named
`source_<test>_<source>_<table>_...`, `file_key_name` `sources.<source>`), source config
(`enabled`, `meta`, `tags`, `freshness`, `loaded_at_field`, `event_time`), quoting,
`identifier`, default database/schema (the schema defaults to the source name),
`relation_name`, `external`, and package-source overrides (`overrides:`). Each is a place a
guess silently diverges. Note the earlier finding that dbt's static parser returns a
model's sources as a Python set (order normalized in `harness/normalize.py`); rendered
models record sources in execution order.

## What to build

- [ ] **Probe and record** against the pinned dbt and dbt-core source
  (`dbt/parser/sources.py`, `dbt/parser/schemas.py`, `SourceDefinition`, `SourceConfig`
  and the source-test paths in `schema_generic_tests.py`): the full `SourceDefinition`
  shape and defaults, config sources and precedence (project `sources:` tree, source-level
  and table-level `config:`, legacy top-level keys), freshness merging (source vs table,
  `null` to disable), quoting, identifier, relation naming, `fqn`, `source_name` /
  `source_description` / `loader`, columns, docs and descriptions rendering, `meta`/`tags`
  merging between source and table, disabled sources, package-source `overrides`, and the
  naming, hashing and refs of generic tests on sources. Each fact gets a `Probed against
  dbt 1.12.5: ...` test comment and a write-up in `docs/probes/`.
- [ ] **Implement sources** (the manifest `sources` section, `source()` resolution with
  dbt's error for unknown sources, `depends_on`, graph maps) and lift both refusals.
- [ ] **Implement tests on sources and source columns.**
- [ ] **Generate it.** Extend `harness/gen_project.py`: sources with multiple tables,
  descriptions, `doc()` references, columns and tests, freshness at both levels, quoting,
  identifiers, `meta`/`tags`, disabled sources, sources in packages with root
  `overrides`, and models that use `source()` statically and inside branches. Remove
  `sources_yml` from `UNSUPPORTED`.
- [ ] **Corpus.** Re-run `harness/audit.py`, commit the records, report the `--refusals`
  tally before and after and which corpus projects became identical.

## Tests

- [ ] Every probed fact has a test that fails if Corten gets it wrong.
- [ ] `make test` green: no `DIVERGED`, no `CRASH`, no missed refusal; `audit.py --property`
  and `fuzz.py --regressions` pass.
- [ ] Before finishing, run 1000 fresh seeds as four chunks, each its own foreground command:
  `harness/fuzz.py --start 28000 --seeds 250`, then `--start 28250`, `--start 28500`,
  `--start 28750`. Put the four summaries in PR.md. Any seed that diverges goes into
  `harness/fuzz_regressions.txt` with a one-line cause, after it is fixed.

## Warts / traps

- **Keep every single command under about 8 minutes.** Claude Code's Bash tool moves longer
  commands to the background, and they die when your iteration ends (shared `gotchas.md`).
- YAML is loaded by Corten's PyYAML-compatible loader (`src/yaml.rs`): YAML 1.1 scalars,
  last-wins duplicate keys. Source names and descriptions will exercise it.
- dbt quirks that look like bugs are matched, not fixed; cite the dbt function.
- The harness pins `TZ=UTC`, `LC_ALL=C.UTF-8` and `PYTHONHASHSEED=0`; never compare against
  dbt outside it. Freshness and `loaded_at_field` must not depend on the clock.
- `harness/normalize.py` and the normalization in `tests/parity.rs` must not change.
- Never hand-edit `audit/`. Regenerate it with the harness.
- Editing `UNSUPPORTED` in the generator reshuffles every seed.
- Clean room: dbt-core, dbt-adapters, dbt-common, Jinja2 and minijinja sources are fine to
  read; never dbt Fusion.
- Prefer the simplest reading of `CLAUDE.md` over filing decisions.
- The word "verified" may only describe something the gate or a probe actually checked.

Finish: `/workspace/PR.md` with the probed source rules, what is still refused and why,
the refusal tally before and after, corpus projects that became identical, and the four
fuzz chunk summaries.
