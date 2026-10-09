# SPEC — corten-analyses-quoting: two small refusals block 4 of 10 corpus projects

Repo: `loop-bot/corten`. Gate: `make build test lint`. Image: `corten-1` (spawn with
`--image corten-1`; the default image has no Rust and no dbt).

## The failure

`harness/audit.py` runs the pinned dbt 1.12.5 and Corten on ten pinned public projects.
Four stop on one of two guards in `src/parse/guard.rs`:

```
dbt_expectations_integration_tests: dbt_project.yml: project-level `quoting` settings are not supported yet
dbt_date_integration_tests:         dbt_project.yml: project-level `quoting` settings are not supported yet
audit_helper_integration_tests:     analyses/compare_column_values_smoke_test.sql: analyses are not supported yet
stripe_integration_tests:           analyses/stripe__arr_snapshot_analysis.sql: analyses are not supported yet
```

dbt_expectations' setting, verbatim:

```yaml
quoting:
    database: false
    identifier: false
    schema: false
```

## Why

Corten's one rule (read `CLAUDE.md`): for every project dbt accepts, Corten's manifest is
**identical** to dbt's or Corten **refuses**. The gate checks it. Both features are
refused only because nobody has measured dbt's behavior for them yet.

- **Quoting** decides how every relation is written: `relation_name` on models, seeds and
  failure-storing tests, `metadata.quoting` in the manifest, and possibly per-node
  `config.quoting`. Today Corten hard-codes DuckDB's all-quoted form in
  `Context::relation_name` (`src/parse/mod.rs`). A wrong guess here changes every node at
  once, so measure it.
- **Analyses** are SQL files under `analysis-paths`, parsed by dbt into `analysis` nodes.
  They are rendered like models, so the existing machinery for refs, sources, macro calls
  and `config()` (`rendered_calls`, `src/parse/mod.rs`) and its refusals apply. Beware:
  `require_corrected_analysis_fqns` changes which config tree analyses read
  (`dbt/context/context_config.py`). Probe what 1.12.5 does.

## What to build

- [ ] **Probe and record** both features against the pinned dbt (`$CORTEN_DBT parse
  --no-partial-parse` on tiny projects), and read the relevant dbt-core source in the venv.
  For quoting: every combination of database/schema/identifier true/false/absent, project
  level and per-node `+quoting` config, what lands in `relation_name`, `metadata.quoting`
  and `config.quoting`, and how DuckDB's defaults interact. For analyses: the full node
  shape (diff its keys against a model's), fqn, path, config tree (`analyses:` vs
  `models:`), checksum, `depends_on`, and whether analyses count as relational for dbt's
  duplicate-relation check. Write each fact as a test comment `Probed against dbt 1.12.5:
  ...` next to the code relying on it, and keep a short write-up in `docs/probes/`.
- [ ] **Implement quoting** (project-level and node-level), removing its refusal from
  `guard.rs`.
- [ ] **Implement analyses**, removing their refusal. Analyses whose Jinja needs real
  rendering must still be refused through `rendered_calls`, not approximated.
- [ ] **Generate both.** Extend `harness/gen_project.py`: quoting combinations at project
  and node level (including packages), and analyses with refs, config calls and nested
  directories. Remove `analysis` from `UNSUPPORTED` there.
- [ ] **Corpus.** Re-run `harness/audit.py`, commit the regenerated `audit/` records, and
  report each of the four projects' before/after first blocker (identical, or a different
  honest blocker).

## Tests

- [ ] Every probed fact has a test that fails if Corten gets it wrong.
- [ ] `make test` green: no `DIVERGED`, no `CRASH`, no missed refusal, `audit.py --property`
  passes, `fuzz.py --regressions` passes.
- [ ] Before finishing, run `harness/fuzz.py --start 9000 --seeds 800` and put its summary in
  PR.md. Any seed that ever diverges goes into `harness/fuzz_regressions.txt` with a
  one-line cause, after it is fixed.

## Warts / traps

- dbt has quirks that look like bugs (e.g. `merge_config_dicts` keeps the first merged
  argument raw, see `src/config.rs`). Match dbt, cite the dbt function, don't "fix" dbt.
- The harness pins `TZ=UTC` and `LC_ALL=C.UTF-8` because dbt output depends on them. Never
  run dbt for a comparison without the harness's environment.
- `harness/normalize.py` and `tests/parity.rs` must not change. Apparent nondeterminism in
  dbt is a finding for PR.md, not a normalization.
- Never hand-edit `audit/`. Regenerate it with the harness.
- Editing `UNSUPPORTED` in the generator reshuffles every seed; expect fuzz counts to move.
- Prefer the simplest reading of `CLAUDE.md` over filing decisions.
- The word "verified" may only describe something the gate or a probe actually checked.

Finish: `/workspace/PR.md` with the probed rules (one table per feature), what is still
refused and why, the corpus before/after table, and the fresh-seed fuzz summary.
