# SPEC — corten-render-tests: render tests, analyses and test macros the way dbt does

Repo: `loop-bot/corten`. Gate: `make build test lint`. Image: `corten-1` (spawn with
`--image corten-1`; the default image has no Rust and no dbt).

## The failure

Corten now renders **models** at parse time (`src/jinja/render.rs`, previous loops). It
still only analyses everything else statically, but dbt **renders** singular tests,
analyses and generic tests (including executing the test's macro). Of the corpus's 42
remaining refusals (`harness/audit.py --refusals`), these block three projects outright:

```
audit_helper:  models/schema.yml: compare_queries: test macro macro.dbt_utils.test_equality
               calls ref, source or config; this needs Jinja rendering
codegen:       tests/test_generate_base_models.sql: calls macro.codegen.generate_base_model,
               which calls ref, source or config; this needs Jinja rendering
stripe:        tests/consistency/consistency_activity_itemized_2.sql: calls config() with
               non-constant arguments; this needs Jinja rendering
dbt_utils:     models/sql/test_nullcheck_table.sql: invalid operation: calls
               exceptions.raise_compiler_error() (macro dbt_utils._is_relation in
               macros/jinja_helpers/_is_relation.sql)
```

The last one is a model, already rendered, but `ref()`'s return value does not behave
enough like a dbt `Relation` for `dbt_utils._is_relation` to accept it, so the macro raises.

## Why

Corten's one rule (read `CLAUDE.md`): for every project dbt accepts, Corten's manifest is
**identical** to dbt's or Corten **refuses**. The gate checks it. Tests are where config
gets set from inside macros: `dbt_utils.equality` calls `config(fail_calc=...)` in its own
body, so dbt records `fail_calc` in the test's `config` and (as rebuilt source text) in
`unrendered_config`. A wrong guess here changes `config`, `unrendered_config`,
`depends_on` and `refs` of every test using such a macro.

## What to build

- [ ] **Probe and record** against the pinned dbt, with tiny projects and dbt-core source
  (`dbt/parser/schema_generic_tests.py` `render_test_update`, `dbt/parser/base.py`,
  `dbt/context/providers.py` `generate_test_context`, `add_rendered_test_kwargs`):
  how generic tests are rendered (the unique/not_null shortcut stays as is); what a
  `config()` call inside a test macro records into `config` and `unrendered_config`
  (`statically_parse_unrendered_config` reads the node's *raw code*, which for a generic
  test is the `{{ test_x(...) }}{{ config(...) }}` line, not the macro body: probe what
  that means); which refs/sources/macros are recorded and in what order for tests and
  analyses; how singular tests and analyses with non-constant `config()` are recorded.
  Also probe what `ref()`/`source()`/`this` return at parse time as **objects**: which
  attributes and methods dbt's `RelationProxy`/`BaseRelation` expose (`database`,
  `schema`, `identifier`, `include()`, `render()`, `is_table`, comparisons, `str()`), and
  what `dbt_utils._is_relation` checks. Each fact gets a `Probed against dbt 1.12.5: ...`
  test comment and a write-up in `docs/probes/`.
- [ ] **Render singular tests and analyses** through the renderer, lifting the
  corresponding refusals in `rendered_calls`.
- [ ] **Render generic tests**, executing the test macro the way dbt does, and lift the
  `test macro ... calls ref, source or config` refusal. The unique/not_null shortcut
  (`src/parse/schema.rs`) must keep its current, exact behavior.
- [ ] **Relation fidelity.** Make `ref()`/`source()`/`this` return objects with the probed
  attributes and methods, so macros like `_is_relation` behave as in dbt. Anything not
  probed stays refused.
- [ ] **Generate it.** Extend `harness/gen_project.py`: custom generic tests whose macro
  calls `config()` and `ref()`; namespaced package tests; singular tests and analyses with
  non-constant `config()`, branches and macro calls; macros inspecting relations.
- [ ] **Corpus.** Re-run `harness/audit.py`, commit the records, and put the `--refusals`
  tally before and after in PR.md, plus which corpus projects (if any) became identical.

## Tests

- [ ] Every probed fact has a test that fails if Corten gets it wrong.
- [ ] `make test` green: no `DIVERGED`, no `CRASH`, no missed refusal; `audit.py --property`
  and `fuzz.py --regressions` pass.
- [ ] Before finishing, run 1000 fresh seeds as four chunks, each its own foreground command:
  `harness/fuzz.py --start 20000 --seeds 250`, then `--start 20250`, `--start 20500`,
  `--start 20750`. Put the four summaries in PR.md. Any seed that diverges goes into
  `harness/fuzz_regressions.txt` with a one-line cause, after it is fixed.

## Warts / traps

- **Keep every single command under about 8 minutes.** Claude Code's Bash tool moves longer
  commands to the background, and they die when your iteration ends (see the shared
  `gotchas.md`). Split long runs; never "wait for a background job" across iterations.
- Do not change the static-parser path, the unique/not_null shortcut, or the existing
  exec-order recording; they are exact and heavily fuzzed.
- Lenient behavior can turn a loud refusal into a silent wrong value. After every
  relaxation, check which refusals disappeared and why.
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

Finish: `/workspace/PR.md` with the probed rules for test rendering and relations, what is
still refused and why, the refusal tally before and after, corpus projects that became
identical, and the four fuzz chunk summaries.
