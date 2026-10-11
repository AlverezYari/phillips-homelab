# SPEC — corten-project-jinja: Jinja in dbt_project.yml stops 4 of 10 corpus projects

Repo: `loop-bot/corten`. Gate: `make build test lint`. Image: `corten-1` (spawn with
`--image corten-1`; the default image has no Rust and no dbt, so the gate is red from
iteration 1).

## The failure

`harness/audit.py` runs the pinned dbt 1.12.5 and Corten on ten pinned public projects.
Four stop on the same guard (`audit/1.12.5/SUMMARY.md`):

```
dbt_date_integration_tests: dbt_project.yml: Jinja in project settings
  (`models.dbt_date_integration_tests.+materialized`) are not supported yet
dbt_project_evaluator_integration_tests: dbt_project.yml: Jinja in project settings
  (`tests.dbt_project_evaluator_integration_tests....+enabled`) are not supported yet
stripe_integration_tests: dbt_project.yml: Jinja in project settings
  (`models.+persist_docs.columns`) are not supported yet
dbt_utils_integration_tests: dbt_project.yml: Jinja in project settings
  (`seeds.dbt_utils_integration_tests.sql.data_get_column_values_dropped.+post-hook`) ...
```

Real values from those files:

```yaml
+materialized: "{{ 'table' if target.type in ['duckdb', 'fabric', 'sqlserver', 'synapse'] else 'view' }}"
chained_views_threshold: "{{ 5 if target.type not in ['athena', 'trino', 'clickhouse'] else 4 }}"   # under vars:
account: "{{ source('stripe', 'account') }}"                                                       # under vars:
```

## Why this matters, and why it is not just "render everything"

Corten's one rule (read `CLAUDE.md`): for every project dbt accepts, Corten's manifest is
**identical** to dbt's or Corten **refuses**. It never writes a different manifest. That
rule is checked by the gate. The guard refuses all Jinja in `dbt_project.yml` because
Corten cannot render yet; that keeps the property, but blocks real projects that only use
a tiny, safe part of Jinja: `target.*`, `var()`, `env_var()` and plain expressions.

dbt does **not** render `dbt_project.yml` uniformly. Some values are rendered when the
project loads, some later per node, some never (hooks are stored raw and rendered at
run time; `vars` are rendered lazily when `var()` is called, which is why stripe's
`{{ source(...) }}` vars are legal). `config` gets the rendered value while
`unrendered_config` keeps the raw string. Getting any of these wrong silently changes the
manifest. **Probe each one against the pinned dbt; do not infer it from docs or memory.**

## What to build

- [ ] **Probe and record.** With tiny projects under the pinned dbt (`$CORTEN_DBT parse
  --no-partial-parse`), establish for `dbt_project.yml`: which keys are rendered at load,
  which per node, which never (`vars`, `on-run-start`/`on-run-end`, `+pre-hook`/`+post-hook`,
  `query-comment`, anything else you find); what the context contains (`target.*` fields,
  `var()` with and without default and with package-scoped `vars: {pkg: {...}}`, `env_var()`
  with and without default and when unset); whether rendering is native (does
  `"{{ 5 }}"` become `5` or `"5"`?); and what lands in `config` vs `unrendered_config`.
  Write each fact as a test comment `Probed against dbt 1.12.5: ...` next to the code
  that relies on it.
- [ ] **Render the safe subset.** Render `dbt_project.yml` values the way dbt does, for both
  the root project and installed packages, with a context limited to what you probed:
  `target`, `var`, `env_var`, literals, operators, filters. Any other call (a macro,
  `source()`, `ref()`, `run_query`, ...) in a value dbt renders must still be refused with a
  clear message. Values dbt does not render at load must not be rendered by Corten either.
- [ ] **Keep hooks refused, explicitly.** Hooks are a separate effort. Jinja inside a hook
  must produce the hooks message ("hooks are not supported yet"), not the generic project
  Jinja one, so dbt_utils' blocker is named correctly.
- [ ] **Generate it.** Extend `harness/gen_project.py` so the fuzzer produces project-config
  Jinja with `target.*`, `var()` (root and package-scoped vars), `env_var()` with defaults,
  and native-type results, at every config-tree level and for packages. Keep generating a
  refused variant (a macro call in project config) and assert it is refused. Update
  `UNSUPPORTED` accordingly.
- [ ] **Corpus.** Re-run `harness/audit.py` and commit the regenerated `audit/` records.
  dbt_date, project-evaluator and stripe must get past this guard: identical, or a
  *different*, honest first blocker. Report each project's before/after first blocker.

## Tests

- [ ] Every probed fact has a test that would fail if Corten rendered that key differently.
- [ ] `make test` stays green: no `DIVERGED`, no `CRASH`, no missed refusal in the fuzz
  smoke run, `audit.py --property` passes.
- [ ] Before finishing, run a bigger fuzz pass on fresh seeds
  (`harness/fuzz.py --start 5000 --seeds 600`) and put its summary line in PR.md.

## Warts / traps

- `env_var()` reads the process environment. Tests and the fuzzer must set any variable
  they rely on explicitly for both engines; never depend on the sandbox's environment.
  The gate must stay hermetic: no network.
- `var()` precedence differs between the root project and packages (`vars: {pkg: {...}}`
  overrides). Probe it; do not assume.
- `harness/normalize.py` and `tests/parity.rs` must not change for this. If dbt output
  looks nondeterministic, that is a finding for PR.md, not a normalization.
- Never hand-edit `audit/`. Regenerate it with the harness.
- Prefer the simplest reading of `CLAUDE.md` over filing decisions.
- The word "verified" may only describe something the gate or a probe actually checked.

Finish: `/workspace/PR.md` with the probed rendering rules (a table: key, when rendered,
context, `config` vs `unrendered_config`), what is still refused and why, the corpus
before/after first blockers, and the fresh-seed fuzz summary.
