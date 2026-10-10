# SPEC — corten-config-reconstruct: every expression form in a rendered `config()` call

Repo: `loop-bot/corten`. Gate: `make build test lint`. Image: `corten-1` (spawn with
`--image corten-1`; the default image has no Rust and no dbt).

## The failure

`tuva_integration_tests` now stops here (`audit/1.12.5/SUMMARY.md`):

```
tuva_integration_tests: tests/check_extension_source_only_name_collision.sql: config() argument is not a constant; this needs Jinja rendering, which Corten does not do yet (milestone 3)
```

The test (in the tuva package's `integration_tests/tests/`):

```sql
{% set passthrough_config = var('passthrough', {}) %}
{% set extension_prefix = passthrough_config.get('prefix', 'x_') %}
{% set strip_prefix = passthrough_config.get('strip', false) %}

{{ config(
     enabled = (the_tuva_project.tuva_boolean_var('claims_enabled', false))
            and strip_prefix
            and (extension_prefix | lower) in ['x_', 'ext_'],
     tags = ['extension_columns'],
     severity = 'error'
   )
}}
```

The refusal comes from `reconstruct` in `src/jinja/unrendered.rs`, Corten's copy of how
dbt rebuilds the first `config()` call's arguments as source-like text for
`unrendered_config` on the rendered path (`statically_parse_unrendered_config`). It knows
constants, names, lists, tuples, dicts, attribute/item access, calls, comparisons, `and`/
`or`/`~` and unary ops. It bails on everything else: filters (`| lower`), tests
(`is none`), conditional expressions (`a if c else b`), arithmetic (`+ - * / // % **`),
slices, and whatever else dbt's reconstructor handles.

## Why

Corten's one rule (read `CLAUDE.md`): for every project dbt accepts, Corten's manifest is
**identical** to dbt's or Corten **refuses**. The gate checks it. Conditional `enabled`
expressions in `config()` are routine in packages.

## What to build

- [ ] **Probe and record** against the pinned dbt and dbt-core / dbt-common source: find
  `statically_parse_unrendered_config` and the reconstructor it uses, list every Jinja AST
  node type it handles and exactly how it prints each (spacing, parentheses, quoting,
  filter/test argument syntax, operator precedence: does `(a | lower) in b` keep its
  parentheses?), and what dbt does with a node it can't print (error, skip the key, skip
  the call, fall back to something). Also the rendered side: what lands in `config` for
  tuva's test under the corpus profile, including the macro call
  `the_tuva_project.tuva_boolean_var`. Each fact gets a `Probed against dbt 1.12.5: ...`
  test comment and a write-up in `docs/probes/config-reconstruct.md`.
- [ ] **Implement** every node type dbt prints, byte-exact. Match dbt's handling of the
  ones it can't print exactly; refuse precisely only where Corten can't reproduce it.
  Where the reconstructed text is right but the rendered `config` value needs evaluation
  Corten can't do, keep refusing with a message naming that, not the reconstructor.
- [ ] **Generate it.** Extend `harness/gen_project.py`: `config()` calls in models,
  singular tests and snapshots whose arguments use filters (with and without arguments),
  tests, conditional expressions, arithmetic, parenthesised subexpressions, `set`
  variables and `var()`/macro calls, on the rendered path. Add feature names and remove
  them from `UNSUPPORTED` once handled. Keep the generator's `invalid` rate per 250 seeds
  near its current level (about 10); a jump means it emits projects dbt rejects.
- [ ] **Corpus.** Re-run `harness/audit.py`, commit the records, report the `--refusals`
  tally before and after and which corpus projects became identical.

## Tests

- [ ] Every probed fact has a test that fails if Corten gets it wrong.
- [ ] `make test` green: no `DIVERGED`, no `CRASH`, no missed refusal; `audit.py --property`
  and `fuzz.py --regressions` pass.
- [ ] Before finishing, run 1000 fresh seeds as four chunks, each its own foreground command:
  `harness/fuzz.py --start 48000 --seeds 250`, then `--start 48250`, `--start 48500`,
  `--start 48750`. Put the four summaries in PR.md. Any seed that diverges goes into
  `harness/fuzz_regressions.txt` with a one-line cause, after it is fixed.

## Warts / traps

- **Keep every single command under about 8 minutes**, and **never hand work to a background
  subagent or background command and end your turn**: both die when your iteration ends
  (shared `gotchas.md`).
- Projects whose `config()` calls are already handled must stay byte-identical.
- dbt quirks that look like bugs are matched, not fixed; cite the dbt function.
- The harness pins `TZ=UTC`, `LC_ALL=C.UTF-8` and `PYTHONHASHSEED=0`; never compare against
  dbt outside it.
- `harness/normalize.py` and the normalization in `tests/parity.rs` must not change.
- Never hand-edit `audit/`. Regenerate it with the harness.
- Editing `UNSUPPORTED` in the generator reshuffles every seed.
- Clean room: dbt-core, dbt-adapters, dbt-common, dbt-extractor, Jinja2 and minijinja
  sources are fine to read; never dbt Fusion.
- The word "verified" may only describe something the gate or a probe actually checked.

Finish: `/workspace/PR.md` with the probed rules, what is still refused and why, the
refusal tally before and after, corpus projects that became identical, and the four fuzz
chunk summaries.
