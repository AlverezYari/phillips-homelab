# Verification review: radial menus v2

## Round-1 resolution

| # | Status | v2 disposition |
|---:|---|---|
| 1 | **PARTIAL** | `WaitingRender`/`MenuReady` prevents ordinary blind fire and streams are independent per `(ident, side)`, but the ordering key discards updates within an instance and has no daemon-restart epoch (Finding 1). |
| 2 | **RESOLVED** | The T/T+1 source pair is a complete input to the landed classifier and sinks; no radial-only sink behavior is needed. |
| 3 | **PARTIAL** | The touch mask, held-through-transition rule, stored selection, and cancel-before-release rule are explicit and amendable, but `WaitingRender` still has conflicting/incomplete combined-event behavior (Finding 3). |
| 4 | **PARTIAL** | Program generation plus a mapper-external instance counter fixes clear-then-reopen during one daemon lifetime. Same-instance updates and daemon restart remain unsafe (Finding 1). |
| 5 | **PARTIAL** | The explicit `binding` field, click rejection, and ordered-stack validation are sound. Two promised binding forms are not in the landed `DigitalBinding` grammar (Finding 2). |
| 6 | **PARTIAL** | Null output avoids the unavailable pointer-position protocol and runtime degradation is now separate from catalog diagnostics. The offset/non-overlap law is not implementable or total as written (Finding 4). |

## Priority checks

- **Synthetic activation passes.** With no timing classifier, `press`/`start_press` begin at T and the normal fall/`release_press` occurs at T+1. Long-only resolves a short `Press` on that fall; double-tap retains the ordinary window; `fire_delay` later dispatches the already-ended lifetime as a pulse-hold; toggle flips at Press onset; turbo can contribute only for the one held transaction. The landed edge-before-equal-deadline rule also covers a delayed T+1 without inventing a boundary case. A transition before T+1 clears the same machine and reconciles the same contributions.
- **Control composition passes, with one wording clarification.** The landed winner key is `(action tier, BindingPath)`: `set:` beats `layer_*`, then canonical path breaks equal-tier ties. Thus `buttons.*` really does beat `trackpads.*` on a tie, but not across action tiers. Adding synthetic rises to that candidate set and their T+1 falls to unconditional hold reconciliation needs no second reduction rule. The mask must supply the logical (suppressed) `pad_*_touch` edge to this scan too, not merely to activator machines; §2.2's source-level wording already requires that.
- **Touch ownership is otherwise coherent.** A fresh rise is masked before opening, the mask survives the closing release and unavailable-overlay case, a pre-existing hold keeps its lifecycle without opening, and the other pad remains independent. The remaining state-machine hole is Finding 3.
- **Wire ordering and concurrent placement fail** as Findings 1 and 4 describe.

## New findings, ranked

### 1. BLOCKER: the wire drops every selection and close after the open, and restart can stale-lock the overlay

`MenuState` uses the same `(generation, instance)` for open, selection changes, and close, while §3.2 drops every signal not *strictly newer*. Once open is rendered, every later signal for that instance compares equal and is dropped; the menu cannot update or close. The external instance counter does make §5.1-clear-then-reopen safe within one daemon lifetime.

Both generation and instance are only daemon-lifetime values. The overlay owns its own well-known name and is not required to exit or clear ordering state when the daemon's name owner changes, so a surviving overlay can reject a restarted daemon's reset keys indefinitely.

Add a monotone per-instance revision (including close) and either a daemon-incarnation field or a normative last-seen reset on daemon name-owner change. Test open → selection(s) → close, clear → reopen, and daemon death/restart with the overlay surviving.

### 2. BLOCKER: the advertised item grammar is not the landed `DigitalBinding` grammar

The example's top-level `binding = ["key:1", "key:2"]` and `binding = { cycle = [...] }` do not parse as `DigitalBinding`. In landed code, `DigitalBinding` is output, control, schema-1 activator, or rich activator; fan-out and cycle are `ActivatorSlot` forms only inside a rich activator sink (`osc-config/src/vocabulary.rs:739-751,967-993`).

Either use the landed shapes (`binding = { press = [...] }` and `binding = { press = { cycle = [...] } }`) or explicitly expand `DigitalBinding` everywhere. The latter is a grammar/editor/validation change, not reuse of the same predicate set. Promotion must choose one and make the examples, schema row, and tests agree.

### 3. HIGH — GATE: `WaitingRender` is not total at timeout or concurrent ready/release

The explicit deadline row transitions to `Idle` without emitting `MenuState(closed)`, while the CANCEL list also names `MenuReady timeout` and the CANCEL row does emit close. Those are conflicting actions for the same event and can leave the acknowledged surface visible.

The table also gives no precedence for matching `MenuReady` and touch-end in one transaction. `WaitingRender` stores no selection, so an implementation must choose between the row's never-fire result and entering `Open`, deriving a selection from a no-touch/stale sample, then committing. State the precedence (touch-end while waiting should remain never-fire), emit close on every waiting exit after open was sent, and add the combined ready/release trace.

### 4. HIGH — GATE: null-output placement does not implement the promised offsets or non-overlap

Null output itself is valid, but wlr-layer-shell centers an unanchored surface and `set_margin` has no effect on edges to which the surface is not anchored. The stated centered surface therefore has no protocol operation that moves it by 12% of output height; obtaining that percentage also requires an output-sized configure or another defined source of logical output dimensions.

Even with coordinates, two centers separated by 24% do not imply non-overlap without a maximum rendered diameter, and unbounded additional controllers eventually collide or leave the output. Define an actual layer-shell layout (for example an output-sized, input-transparent surface with bounded packing), maximum menu extent, and overflow/disconnect/reorder behavior. Test simultaneous sides and enough controllers to exercise the fallback.

## Verdict

**NO-GO for promotion to law.** The synthetic classifier law, touch-source exception, and mixed physical/synthetic control reduction are sound against the landed engine. Findings 1–4 still force build loops to invent wire, grammar, state-machine, and renderer behavior. They must be folded before promotion. The founder's crate ruling remains a separate build gate and is not part of this verdict.
