# SPEC — corten-yaml-jinja: Jinja in schema YAML values and the rest of dbt_project.yml

Repo: `loop-bot/corten`. Gate: `make build test lint`. Image: `corten-1` (spawn with
`--image corten-1`; the default image has no Rust and no dbt).

## The failure

Two corpus projects now stop on Jinja in configuration values (`audit/1.12.5/SUMMARY.md`):

```
tuva_integration_tests: package integration_tests: dbt_project.yml: Jinja in project settings (`models.integration_tests.+schema`) are not supported yet
stripe_integration_tests: models/staging/src_stripe.yml: sources: Jinja in property values (`database`) is not supported yet
```

Tuva's value (block `if`, `var()` with a `none` default, `is not none`, `trim`):

```yaml
    +schema: |
      {%- if var('tuva_schema_prefix', none) is not none and var('tuva_schema_prefix', none) | trim != '' -%}{{ var('tuva_schema_prefix') }}_semantic_layer{%- else -%}semantic_layer{%- endif -%}
```

Stripe's (`src_stripe.yml`, a source, rendered with project vars visible):

```yaml
    database: "{% if target.type != 'spark' %}{{ var('stripe_database', target.database) }}{% endif %}"
    schema: "{{var ('stripe_schema', 'stripe')}}"
    config:
      enabled: "{{ var('stripe_sources', []) == [] }}"
```

## Why

Corten's one rule (read `CLAUDE.md`): for every project dbt accepts, Corten's manifest is
**identical** to dbt's or Corten **refuses**. The gate checks it. Configuration values with
Jinja are routine in packages (every Fivetran package's sources look like stripe's).
`src/jinja/project_render.rs` already renders a safe subset of `dbt_project.yml`
(`DbtProjectYamlRenderer`, `docs/probes/project-jinja-rendering.md`);
`guard::check_entry_jinja` (`src/parse/guard.rs`) refuses any Jinja in schema YAML
property values.

## What to build

- [ ] **Probe and record** against the pinned dbt and dbt-core source
  (`dbt/config/renderer.py`: `DbtProjectYamlRenderer`, `SchemaYamlRenderer` and its
  `should_render_keypath`; `dbt/context/configured.py`; `dbt/parser/schemas.py` where
  entries are rendered): which keys are rendered and which are left raw (descriptions,
  tests, `columns.*.tests`, ...), the context each renderer gets (`var()` and which vars it
  sees, root vs package-scoped; `target`; `env_var`; macros or not), when rendering
  happens relative to `enabled` and patching, how a rendered value's type is coerced
  (string `"True"` → bool? `[]` comparisons), what lands in `config` vs `unrendered_config`
  (for sources and for models/seeds patched by YAML), and what Tuva's `+schema` block
  renders to under the corpus profile. Each fact gets a `Probed against dbt 1.12.5: ...`
  test comment and a write-up in `docs/probes/yaml-jinja.md`.
- [ ] **Extend the project renderer** to the statement forms dbt accepts there (block
  `if`/`else`, whitespace control, `none` and `is none` tests, the filters the corpus uses)
  and lift the refusal for whatever it now reproduces exactly.
- [ ] **Render schema YAML property values** (sources first, then models, seeds and
  analyses patches) with dbt's context and key rules; lift `check_entry_jinja` for what
  is reproduced exactly; keep refusing the rest with a precise message.
- [ ] **Generate it.** Extend `harness/gen_project.py`: Jinja-valued project settings with
  block statements and `var()` defaults (including `none`), Jinja-valued source
  `database`/`schema`/`identifier`/`config.enabled`/`loaded_at_field`, and Jinja in
  model/seed YAML `config:` values, each with CLI `--vars` and project `vars:` variants.
  Add feature names and remove them from `UNSUPPORTED` once handled. Keep the generator's
  `invalid` rate per 250 seeds near its current level (about 10); a jump means it emits
  projects dbt rejects.
- [ ] **Corpus.** Re-run `harness/audit.py`, commit the records, report the `--refusals`
  tally before and after and which corpus projects became identical.

## Tests

- [ ] Every probed fact has a test that fails if Corten gets it wrong.
- [ ] `make test` green: no `DIVERGED`, no `CRASH`, no missed refusal; `audit.py --property`
  and `fuzz.py --regressions` pass.
- [ ] Before finishing, run 1000 fresh seeds as four chunks, each its own foreground command:
  `harness/fuzz.py --start 44000 --seeds 250`, then `--start 44250`, `--start 44500`,
  `--start 44750`. Put the four summaries in PR.md. Any seed that diverges goes into
  `harness/fuzz_regressions.txt` with a one-line cause, after it is fixed.

## Warts / traps

- **Keep every single command under about 8 minutes**, and **never hand work to a background
  subagent or background command and end your turn**: both die when your iteration ends
  (shared `gotchas.md`).
- Projects without Jinja in these values must stay byte-identical.
- dbt quirks that look like bugs are matched, not fixed; cite the dbt function.
- The harness pins `TZ=UTC`, `LC_ALL=C.UTF-8` and `PYTHONHASHSEED=0`; never compare against
  dbt outside it. `env_var()` values must come from the harness environment only.
- `harness/normalize.py` and the normalization in `tests/parity.rs` must not change.
- Never hand-edit `audit/`. Regenerate it with the harness.
- Editing `UNSUPPORTED` in the generator reshuffles every seed.
- Clean room: dbt-core, dbt-adapters, dbt-common, Jinja2 and minijinja sources are fine to
  read; never dbt Fusion.
- The word "verified" may only describe something the gate or a probe actually checked.

Finish: `/workspace/PR.md` with the probed rules, what is still refused and why, the
refusal tally before and after, corpus projects that became identical, and the four fuzz
chunk summaries.
