# SPEC — corten-render-mutable: Python-style mutable lists and dicts in Jinja

Repo: `loop-bot/corten`. Gate: `make build test lint`. Image: `corten-1` (spawn with
`--image corten-1`; the default image has no Rust and no dbt).

## The failure

dbt runs Jinja2 on real Python objects, so templates build lists and dicts by mutating
them. This idiom is everywhere in real dbt packages:

```jinja
{% set cols = [] %}
{% for c in columns %}{% do cols.append(c.name) %}{% endfor %}
{{ cols | join(', ') }}
```

Corten renders with minijinja, whose list and dict literals are immutable (`Arc`-backed,
no hook over literal construction). The previous loop (`docs/probes/jinja2-vs-minijinja.md`
§5) refused these rather than fake them, correctly. Today's corpus tally
(`harness/audit.py --refusals`) still has, among 51 refusals:

```
unknown method: sequence has no method named append (in pkg:dbt_utils:1140)
unknown method: sequence has no method named append (in pkg:stripe:754)
unknown method: sequence has no method named append (in pkg:stripe:869)
unknown method: sequence has no method named append (in <model>:8)
could not render include: error in "<model>" (in <outer>:789)     # x3, plus :711, :628
```

Two things are wrong: the missing semantics, and messages a user cannot act on (no file,
no plain cause).

## Why

Corten's one rule (read `CLAUDE.md`): for every project dbt accepts, Corten's manifest is
**identical** to dbt's or Corten **refuses**. Mutation is where a naive fix silently
diverges: Python lists are shared by reference (`{% set a = b %}` then `a.append(x)`
changes `b`), `{% set %}` inside loops has Jinja2 scoping rules, `dict.update` merges,
`list.extend`/`pop`/`insert` return values differ from what a template might expect, and
the result's printed form must match Python's `str()`/`repr()`. Probe each one.

Direction approved by Casey: **first try a minimal, maintained patch to minijinja**
(Apache 2.0) or a pre-evaluation rewrite that turns list/dict literals into Corten's own
mutable objects. Pick whichever is smaller and exact; explain the choice in PR.md. If a
patch to minijinja is needed, vendor it under `vendor/minijinja/` (or a `[patch]`
section) with the diff isolated and documented, and keep it upgradable. Keep the running
list of every Jinja2 difference Corten patches around (`docs/probes/jinja2-vs-minijinja.md`):
it is the evidence for whether Corten later needs its own evaluator.

## What to build

- [ ] **Probe and record** Python container semantics as dbt's Jinja2 exposes them, against
  the pinned dbt (the `exceptions.raise_compiler_error` probe trick from the previous loop
  works): `append`, `extend`, `insert`, `pop`, `remove`, `update`, `setdefault`, `pop` on
  dicts, aliasing (`set a = b`), mutation inside `for` loops and macros (scoping), mutation
  of a list passed into a macro, return values of mutating methods (`None`, rendered as?),
  printing a mutated list/dict (`str()`/`repr()` formatting: quotes, `True`/`None`,
  nested), `| join`, `| length`, `in`, equality. Write each fact as a test comment
  `Probed against dbt 1.12.5: ...` and extend the probe doc.
- [ ] **Implement mutable containers** with exactly those semantics, everywhere Corten
  renders Jinja. Anything not probed stays refused.
- [ ] **Refusal messages users can act on.** Every refusal names the node or file
  (`models/x.sql`, `macro dbt_utils.star in dbt_packages/dbt_utils/macros/...`), and says
  what dbt feature is unsupported in plain words. No raw engine strings like
  `<outer>:789` or `error in "<model>"`. Add a test for the message shape.
- [ ] **Generate it.** Extend `harness/gen_project.py` with the idiom and its awkward
  variants: aliasing, mutation in loops and inside macros, nested containers, printing
  mutated values, dict building with `update`/`setdefault`.
- [ ] **Corpus.** Re-run `harness/audit.py`, commit the records, and put the `--refusals`
  tally before and after in PR.md.

## Tests

- [ ] Every probed fact has a test that fails if Corten gets it wrong.
- [ ] `make test` green: no `DIVERGED`, no `CRASH`, no missed refusal; `audit.py --property`
  and `fuzz.py --regressions` pass.
- [ ] Before finishing, run `harness/fuzz.py --start 16000 --seeds 1000` and put its summary
  in PR.md. Any seed that diverges goes into `harness/fuzz_regressions.txt` with a
  one-line cause, after it is fixed.

## Warts / traps

- Do not change the static-parser path or the existing exec-order call recording; they
  are exact and heavily fuzzed.
- Lenient behavior can turn a loud refusal into a silent wrong value (the previous loop
  caught this with `int`). After every relaxation, check which refusals disappeared and
  why.
- dbt quirks that look like bugs are matched, not fixed; cite the dbt or Jinja2 function.
- The harness pins `TZ=UTC`, `LC_ALL=C.UTF-8` and `PYTHONHASHSEED=0`; never compare
  against dbt outside it.
- `harness/normalize.py` and the normalization in `tests/parity.rs` must not change.
- Never hand-edit `audit/`. Regenerate it with the harness.
- Editing `UNSUPPORTED` in the generator reshuffles every seed.
- Clean room: dbt-core, dbt-common, Jinja2 and minijinja sources are fine to read; never
  dbt Fusion.
- Prefer the simplest reading of `CLAUDE.md` over filing decisions.
- The word "verified" may only describe something the gate or a probe actually checked.

Finish: `/workspace/PR.md` with the probed semantics table, the approach chosen (patch or
rewrite) and why, the updated Jinja2-difference list, the refusal tally before and after,
and the fresh-seed fuzz summary.
