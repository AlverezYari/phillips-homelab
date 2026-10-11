# SPEC — corten-generate-names: custom generate_schema_name / alias / database macros

Repo: `loop-bot/corten`. Gate: `make build test lint`. Image: `corten-1` (spawn with
`--image corten-1`; the default image has no Rust and no dbt).

## The failure

Two corpus projects stop on the same guard (`audit/1.12.5/SUMMARY.md`):

```
dbt_expectations_integration_tests: custom generate_schema_name macros are not supported yet (milestone 3 adds macro execution)
dbt_date_integration_tests:         custom generate_schema_name macros are not supported yet (milestone 3 adds macro execution)
```

Their macro (`integration_tests/macros/get_custom_schema.sql`), verbatim:

```jinja
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

This is the single most common customization in real dbt projects; nearly every
production project overrides `generate_schema_name`.

## Why

Corten's one rule (read `CLAUDE.md`): for every project dbt accepts, Corten's manifest is
**identical** to dbt's or Corten **refuses**. The gate checks it. Corten hard-codes dbt's
*default* naming (`Context::schema_for`/`database_for` and alias in `src/parse/`). With an
override, dbt executes the project's macro per node to decide `schema`, `alias` and
`database`, which feed `relation_name` and the duplicate-relation check. Corten can now
render macros (`src/jinja/render.rs`), so it can execute these too, exactly as dbt does.

## What to build

- [ ] **Probe and record** against the pinned dbt and dbt-core source
  (`dbt/parser/base.py` `_update_node_database/_schema/_alias`, `RelationUpdate`,
  `find_generate_macro_by_name`, `generate_runtime_macro_context` / the context these
  macros get): which macro is chosen (root project override, internal default; probed
  earlier that package-defined overrides are ignored, confirm), when it runs (per node,
  with what `custom_schema_name` / `custom_alias_name` / `node` values), how its output is
  post-processed (whitespace stripping), what context it sees (`target`, `var`, `env_var`,
  `node.*` fields, `execute`), what happens when it raises, and which node types it
  applies to (models, seeds, tests, snapshots, analyses). Also `generate_alias_name` and
  `generate_database_name`, and dispatch-based overrides (`default__generate_schema_name`
  in the root project). Write each fact as a test comment `Probed against dbt 1.12.5:
  ...` with a write-up in `docs/probes/`.
- [ ] **Execute the overrides** through the renderer for every node type dbt applies them
  to, replacing the guard in `src/parse/mod.rs`. Anything the macro does that Corten does
  not model (an adapter call it cannot answer, an unprobed `node` attribute) is refused.
- [ ] **Generate it.** Extend `harness/gen_project.py` with overrides of all three macros:
  the common patterns (custom schema only, prefix with target name, env-dependent via
  `target.name`, `node.resource_type` branches, alias from `node.name` or config), plus a
  dispatch-based override and a package-defined one that dbt ignores.
- [ ] **Corpus.** Re-run `harness/audit.py`, commit the records, report the `--refusals`
  tally before and after and which corpus projects became identical.

## Tests

- [ ] Every probed fact has a test that fails if Corten gets it wrong.
- [ ] `make test` green: no `DIVERGED`, no `CRASH`, no missed refusal; `audit.py --property`
  and `fuzz.py --regressions` pass.
- [ ] Before finishing, run 1000 fresh seeds as four chunks, each its own foreground command:
  `harness/fuzz.py --start 22000 --seeds 250`, then `--start 22250`, `--start 22500`,
  `--start 22750`. Put the four summaries in PR.md. Any seed that diverges goes into
  `harness/fuzz_regressions.txt` with a one-line cause, after it is fixed.

## Warts / traps

- **Keep every single command under about 8 minutes.** Claude Code's Bash tool moves longer
  commands to the background, and they die when your iteration ends (shared `gotchas.md`).
- Default naming (no override) must stay byte-identical; it is the common case and heavily
  fuzzed.
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

Finish: `/workspace/PR.md` with the probed naming rules, what is still refused and why,
the refusal tally before and after, corpus projects that became identical, and the four
fuzz chunk summaries.
