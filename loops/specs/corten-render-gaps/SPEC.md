# SPEC — corten-render-gaps: the four renderer gaps the corpus still hits

Repo: `loop-bot/corten`. Gate: `make build test lint`. Image: `corten-1` (spawn with
`--image corten-1`; the default image has no Rust and no dbt).

## The failure

Four corpus projects stop on rendering gaps rather than missing features
(`audit/1.12.5/SUMMARY.md`, verbatim):

```
dbt_utils_integration_tests: tests/jinja_helpers/assert_pretty_output_msg_is_string.sql: undefined value (macro dbt_utils.default__pretty_time in macros/jinja_helpers/pretty_time.sql)
dbt_expectations_integration_tests: test.dbt_expectations_integration_tests.dbt_expectations_expect_column_values_to_match_regex_data_text_email_address__i___A_Z_.1e1b855a2c: invalid value "{{ target.type not in ['bigquery', 'spark' ] }}" for config `enabled` (dbt rejects this project too)
codegen_integration_tests: tests/test_generate_base_models_all_args.sql: invalid operation: calls adapter.quote(); this needs Jinja rendering, which Corten does not do yet (milestone 3)
dbt_project_evaluator_integration_tests: models/marts/core/int_all_dag_relationships.sql: invalid operation: int filter: argument still contains Jinja syntax ("{{ 9 if target.type in [...] else 4 if ... else -1 }}"), which means something upstream didn't render it ... (macro dbt_project_evaluator.default__recursive_dag in macros/recursive_dag.sql)
```

Earlier loops may have moved some of these; start from the current `SUMMARY.md`, not
this list. The dbt_expectations message is wrong as written: dbt accepts that project
(its manifest is in the audit record), so Corten's claim that "dbt rejects this project
too" is false and must go.

## Why

Corten's one rule (read `CLAUDE.md`): for every project dbt accepts, Corten's manifest is
**identical** to dbt's or Corten **refuses**. The gate checks it. Each of these is a
place where dbt's parse-time rendering produces a value Corten does not yet compute:

1. **`pretty_time`** (dbt_utils): `modules.datetime` in the parse context. Find what
   dbt's `modules` exposes at parse time and what the test renders. The manifest must not
   depend on the clock; if it would, find out how dbt avoids that or refuse.
2. **Jinja in generic-test config values** (dbt_expectations):
   `config: {enabled: "{{ target.type not in [...] }}"}` on a generic test in schema YAML.
   Find where dbt renders test config values (`dbt/parser/schemas.py`,
   `SchemaGenericTestParser`, `render_test_update` / the `ContextConfig` path) and what
   it records in `config` vs `unrendered_config`.
3. **`adapter.quote`** (codegen): what the parse-time adapter returns for `quote()` with
   dbt-duckdb (`dbt/adapters/base/impl.py`, `duckdb` overrides), and which other cheap,
   pure adapter methods the corpus calls at parse time.
4. **Package vars rendered lazily** (dbt_project_evaluator): a `vars:` value in a
   package's `dbt_project.yml` that is itself a Jinja string. Find when dbt renders it
   (`dbt/config/project.py` `vars`, `VarProvider`, `dbt/context/configured.py`): at
   load, per call to `var()`, against which context, and what `var()` returns.

## What to build

- [ ] **Probe and record** each gap against the pinned dbt and the dbt-core /
  dbt-adapters / dbt-duckdb source: build a tiny project per gap, run the pinned dbt,
  read its manifest. Each fact gets a `Probed against dbt 1.12.5: ...` test comment and a
  write-up in `docs/probes/render-gaps.md`.
- [ ] **Implement** each gap exactly, or refuse with a precise message if it can't be
  reproduced exactly (for example, a clock-dependent manifest value). Fix the false "dbt
  rejects this project too" claim wherever Corten makes it without evidence.
- [ ] **Generate it.** Extend `harness/gen_project.py`: Jinja-valued generic-test config
  (`enabled`, `severity`, `where`, `tags`), `adapter.quote` and the other probed adapter
  methods in models and macros, `modules.*` calls whose output reaches the manifest, and
  Jinja-valued package and root `vars` used from models and macros. Add a feature name
  per gap and remove it from `UNSUPPORTED` once handled.
- [ ] **Corpus.** Re-run `harness/audit.py`, commit the records, report the `--refusals`
  tally before and after and which corpus projects became identical.

## Tests

- [ ] Every probed fact has a test that fails if Corten gets it wrong.
- [ ] `make test` green: no `DIVERGED`, no `CRASH`, no missed refusal; `audit.py --property`
  and `fuzz.py --regressions` pass.
- [ ] Before finishing, run 1000 fresh seeds as four chunks, each its own foreground command:
  `harness/fuzz.py --start 36000 --seeds 250`, then `--start 36250`, `--start 36500`,
  `--start 36750`. Put the four summaries in PR.md. Any seed that diverges goes into
  `harness/fuzz_regressions.txt` with a one-line cause, after it is fixed.

## Warts / traps

- **Keep every single command under about 8 minutes.** Claude Code's Bash tool moves longer
  commands to the background, and they die when your iteration ends (shared `gotchas.md`).
- Projects that don't use these features must stay byte-identical.
- dbt quirks that look like bugs are matched, not fixed; cite the dbt function.
- The harness pins `TZ=UTC`, `LC_ALL=C.UTF-8` and `PYTHONHASHSEED=0`; never compare against
  dbt outside it. Nothing in the manifest may depend on the wall clock.
- `harness/normalize.py` and the normalization in `tests/parity.rs` must not change.
- Never hand-edit `audit/`. Regenerate it with the harness.
- Editing `UNSUPPORTED` in the generator reshuffles every seed.
- Clean room: dbt-core, dbt-adapters, dbt-common, dbt-duckdb, Jinja2 and minijinja
  sources are fine to read; never dbt Fusion.
- Prefer the simplest reading of `CLAUDE.md` over filing decisions.
- The word "verified" may only describe something the gate or a probe actually checked.

Finish: `/workspace/PR.md` with the probed rules per gap, what is still refused and why,
the refusal tally before and after, corpus projects that became identical, and the four
fuzz chunk summaries.
