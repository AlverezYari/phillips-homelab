# Adversarial review: radial menus v1

## Verdict

**NO-GO** for promotion to law, including with the amendments currently
promised in the draft. The shape is plausible, and commit-on-touch-loss is a
coherent behavior choice, but the renderer handshake, concurrent-menu order,
synthetic-binding delivery, and touch ownership are not yet implementable
without inventing correctness rules in a build loop.

## Findings, ranked

1. **P0 — one-way IPC permits blind fire and is not total for concurrent
   menus.** Owning `dev.opensteamcontroller.Overlay` proves that a process
   exists, not that the open signal has produced a surface. A quick lift can
   therefore commit before anything was visible, contradicting §4's
   no-overlay/no-blind-fire rule. The fence explicitly required
   acknowledgement and stale-reply rejection; selection staying daemon-side
   does not remove the need for a rendered/ready acknowledgement. In addition,
   “newest signal only” with order `(ident, session, instance)` is not a time
   order across controllers, and does not even distinguish the two sides of
   one controller. An open or close from one menu can discard or hide an
   unrelated simultaneous menu. Define either independent per-`(ident, side)`
   surfaces/streams or explicit global arbitration, and make readiness part of
   the daemon machine.

2. **P0 — the claimed pulse composition has no law.** Config-profiles §14.6
   defines a pulse *output*: a release-less wheel `RelativeEvent` on one
   contribution's rising edge. It does not define a generic resolved
   press-and-release source that can be fed into a `DigitalBinding`. The draft
   consequently leaves the timing engine to invent whether press and release
   occupy one or two transactions, when `start_press`/`release_press`, delayed
   press, double-tap, toggle, cycle, and fan-out advance, whether turbo can
   start, and where a `set:`/`layer_*:` result enters §4's one control pass.
   Specify a synthetic activation at a `BindingPath` in timing-engine terms,
   including lifetime, phase ordering, cancellation, and all sink forms; then
   test that law rather than calling it a §14.6 pulse.

3. **P0 — touch ownership contradicts existing law, and the machine is not
   total enough to resolve the contradiction.** Timing-engine §8 and
   config-profiles §14.2 say `pad_*_touch` is independent and concurrent and is
   never consumed or masked by pad behavior. Radial §2 instead suppresses it
   while open. That can be a deliberate new exception, but it requires a
   same-commit amendment and an ordering rule for the opening transaction,
   cancellation of an already armed touch activator, suppression through
   physical release, and the unavailable-overlay case. The state table also
   needs explicit precedence for touch-end concurrent with generation/layer/
   liveness cancellation, must say that a no-touch sample commits the previous
   selection rather than re-evaluating stale coordinates, and must define a
   held touch when liveness or a new generation arrives. Merely promising a
   test for every pair does not define those pairs. Commit on ordinary touch
   loss itself conflicts with no existing behavior law once these ownership
   rules are amended; cancellation must win over commit.

4. **P1 — positional identity is safe only inside the mapper; the missing
   generation makes it unsafe end-to-end.** Reorder/delete deliberately changes
   `menu.<n>`, contrary to the fence's request for identity stable under those
   edits. A generation clear can justify that deviation for activator, cycle,
   toggle, delayed-dispatch, and open-menu state. It does not protect the
   overlay: `session` is a device-connection generation, not a program
   generation, while §5.1 clearing can reset the menu instance counter. A late
   old-generation signal can therefore equal or outrank a new menu and attach
   old labels/selection to it. Put program generation in the wire identity and
   ordering (or normatively keep a non-resetting instance epoch), and explicitly
   reject the fence's stable-ID requirement if positional identity remains the
   chosen tradeoff.

5. **P1 — the serialized binding and validation contract is incomplete.** The
   example's `{ label, press }` only demonstrates an activator-shaped item; it
   provides no exact representation for the claimed bare binding, fan-out
   array, or `{ cycle = ... }` alongside `label`. Introduce an unambiguous item
   field such as `binding = <DigitalBinding>` and show every admitted form, or
   normatively define the flattened grammar and its key collisions. The
   same-commit schema row must also say whether a radial behavior accepts a
   `click` field. Finally, “validate per declaration” does not discharge
   reachable-fold validation: nested outputs in layer/shift declarations still
   need every applicable DigitalBinding predicate, including
   `gamepad_output=false`, checked against every reachable base and ordered
   stack.

6. **P1 — output placement is neither portable Wayland law nor complete
   degradation.** An input-transparent Wayland client cannot generally discover
   global pointer coordinates merely by creating a layer-shell surface. The
   draft must name the available protocol/source for choosing “the output
   containing the pointer,” and define no pointer, no focused output, output
   removal, and multiple-output fallback. It must also say whether concurrent
   menus share, replace, or create multiple surfaces. Separately, a crash that
   happens after profile load cannot retroactively emit a profile-load §7
   diagnostic from the immutable catalog; make runtime unavailability a defined
   tray/runtime diagnostic and state when the three-crash budget resets. The
   intended loud-off policy and mid-open Cancel are otherwise internally
   consistent.

## Minimal fold list

1. Define exact item TOML for every DigitalBinding form, the exact schema-2 and
   validation rows, click legality, and reachable-stack validation.
2. Replace §2 prose with a total event/precedence table, including touch-source
   suppression, held-through-transition behavior, stale coordinates, and a
   waiting-for-render state; amend the existing independent-touch law explicitly.
3. Add a timing-engine synthetic-activation law covering every activator sink,
   fan-out/cycle, control-pass placement, lifetime, and cancellation.
4. Make IPC per-menu and generation-aware, add rendered/ready acknowledgement
   with stale-ack rejection, and define simultaneous controllers/sides plus
   daemon/overlay owner changes.
5. Specify implementable output selection and fallbacks, and separate runtime
   degradation status from load diagnostics.
