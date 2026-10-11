# SPEC — corten-render-1: render models at parse time, the way dbt does

Repo: `loop-bot/corten`. Gate: `make build test lint`. Image: `corten-1` (spawn with
`--image corten-1`; the default image has no Rust and no dbt).

## The failure

After two loops of small features, the corpus (`audit/1.12.5/SUMMARY.md`) is blocked
almost entirely by one missing capability. Corten only analyses Jinja statically; dbt
**executes** it at parse time. Real first blockers today:

```
dbt_utils_integration_tests:  models/datetime/test_date_spine.sql: calls macro dbt_utils.date_spine()
                              inside a branch, loop or macro definition; this needs Jinja rendering
codegen_integration_tests:    models/model_struct.sql: calls ref() inside a branch, loop or macro
                              definition; this needs Jinja rendering
dbt_project_evaluator_...:    models/utils/all_days.sql: calls macro dbt.current_timestamp() inside
                              a branch, loop or macro definition; this needs Jinja rendering
audit_helper_integration_...: analyses/compare_column_values_smoke_test.sql: calls macro run_query()
                              inside a branch...; this needs Jinja rendering
```

The refusals are correct (they keep Corten's rule, below), but every real project hits
one. This spec starts milestone 3: **render model SQL at parse time, with dbt's parse
context, and record what rendering records.** Later specs cover custom
`generate_*_name` macros, test macros that call `config()`, and hooks; stay out of those.

## Why it matters, and the rule you must keep

Corten's one rule (read `CLAUDE.md`): for every project dbt accepts, Corten's manifest is
**identical** to dbt's or Corten **refuses**. The gate checks it with the corpus audit and
differential fuzzing. Rendering is where a reimplementation silently diverges: a branch
taken differently, a ref recorded in the wrong order, a macro dbt executes that Corten
evaluates to something else. The static analysis that exists today was built to be exact
or refuse; the renderer must keep that standard. When rendering reaches something Corten
does not model exactly (an adapter introspection call, a Jinja feature minijinja handles
differently from Jinja2, a context member nobody probed), **refuse**. Never let an unknown
value render as an empty string.

## What to build

- [ ] **See every blocker, not just the first.** Add a diagnostic mode (e.g.
  `corten parse --report-refusals`) that keeps going after a refusal and prints every
  refusal in the project, one line each, still exiting nonzero and writing no manifest.
  Add a harness summary (e.g. `harness/audit.py --refusals`) that tallies them per reason
  across the corpus. Put the before-tally in PR.md; it scopes this and later specs.
- [ ] **Probe and record dbt's parse-time context** against the pinned dbt, with tiny
  projects and the dbt-core source in the venv (`dbt/context/providers.py`
  `ParseProvider`, `ParseDatabaseWrapper`, `ParseRefResolver`, `dbt/context/base.py`).
  At minimum: `execute` (false at parse), what `ref()`/`source()` return and render to,
  `this`, `is_incremental()`, `var()` precedence (root vars, package-scoped vars, CLI),
  `env_var()`, `target`, `config.get`/`config.require`, `run_query` and `statement` at
  parse, `adapter.dispatch`, which `adapter.*` calls return what (`get_relation`,
  `get_columns_in_relation`, ...), `log`/`print`, `return`, `exceptions.*`, `modules.*`,
  `zip`/`set`/`tojson`/`fromjson`. Which calls are recorded into `refs`, `sources`,
  `depends_on.macros` (earlier probing found only macros called **directly** by the
  node's template are recorded, not ones called inside other macros; confirm), in what
  order, and whether refs made inside macros count. Write each fact as a test comment
  `Probed against dbt 1.12.5: ...` and keep a write-up in `docs/probes/`.
- [ ] **Render models.** For model SQL that dbt's static parser would not handle, execute
  the template with that context and the project's macros (root, packages, internal dbt
  and dbt-duckdb, with dispatch), recording refs, sources, macro dependencies and config
  the way dbt does, then lift the corresponding refusals in `rendered_calls`
  (`src/parse/mod.rs`). Statically parseable models must keep producing exactly what they
  do today (the static path is a separate dbt code path with its own quirks; see
  `src/jinja/unrendered.rs`).
- [ ] **Jinja2 vs minijinja.** dbt runs Jinja2 with Python objects underneath. List every
  semantic difference the corpus and fuzzer reach (method calls like `.items()`,
  `.upper()`, `.split()`; `loop` variables; undefined handling; `namespace`; filters;
  integer/float formatting in output) and either match Jinja2 exactly or refuse. Record
  the list in the probe write-up.
- [ ] **Generate it.** Extend `harness/gen_project.py`: models with branches on `target.*`,
  `var()`, `execute`, `is_incremental()`; loops over literal lists building SQL; refs and
  macro calls inside branches and inside project macros; `{% set %}` blocks; `run_query`
  guarded by `if execute`; dispatch to project and package macros. Move `conditional_ref`
  out of `UNSUPPORTED` once handled.
- [ ] **Corpus.** Re-run `harness/audit.py`, commit the regenerated records, and put the
  refusal tally after the change next to the before-tally in PR.md.

If the whole renderer does not fit in the budget, land a coherent, gate-green subset
(e.g. models only, a probed subset of the context) and say precisely in PR.md what is
done and what remains. A smaller exact renderer beats a larger approximate one.

## Tests

- [ ] Every probed fact has a test that fails if Corten gets it wrong.
- [ ] `make test` green: no `DIVERGED`, no `CRASH`, no missed refusal; `audit.py --property`
  and `fuzz.py --regressions` pass.
- [ ] Before finishing, run `harness/fuzz.py --start 12000 --seeds 1000` and put its summary
  in PR.md. Any seed that diverges goes into `harness/fuzz_regressions.txt` with a
  one-line cause, after it is fixed.

## Warts / traps

- Do not change how statically parseable models are handled; the fuzzer covers that path
  heavily and it is exact today.
- `depends_on.macros` order is execution order for rendered templates (arguments before
  the call receiving them; see `src/jinja/exec.rs`). Refs and sources too.
- dbt has quirks that look like bugs (`merge_config_dicts` keeps its first merged argument
  raw; `src/config.rs`). Match dbt, cite the dbt function, don't fix dbt.
- The harness pins `TZ=UTC`, `LC_ALL=C.UTF-8` and `PYTHONHASHSEED=0` because dbt output
  depends on them. Never compare against dbt run outside the harness environment.
- `harness/normalize.py` and `tests/parity.rs` normalization must not change. Apparent
  nondeterminism in dbt is a finding for PR.md, not a normalization.
- Never hand-edit `audit/`. Regenerate it with the harness.
- Editing `UNSUPPORTED` in the generator reshuffles every seed; expect fuzz counts to move.
- Clean room: dbt-core, dbt-adapters, dbt-common, dbt-extractor, minijinja and Jinja2
  sources are fine to read. Never read dbt Fusion source.
- Prefer the simplest reading of `CLAUDE.md` over filing decisions.
- The word "verified" may only describe something the gate or a probe actually checked.

Finish: `/workspace/PR.md` with the probed context table, the Jinja2-vs-minijinja list
(matched or refused), what is still refused and why, the corpus refusal tallies before
and after, and the fresh-seed fuzz summary.
