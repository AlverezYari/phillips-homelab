# SPEC — osc-wave2-features: control pass, shifts/layers, chords, dual/rings, zones (wave 2 loop 2 of 3)

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-2.

**Read first, all on main:** `CLAUDE.md`;
`docs/design/timing-engine.md` **v3** — law, exactly its staging
loop 2: §4 (control pass), §5 (shifts/layers + effective-program
fold), §6 (chords), §7 (dual triggers/rings), §8 (zones/scroll).
The merged osc-timing-engine work is your substrate: its
BindingPath machines, clock, and schema-2 parse types (including
the "not yet supported" load errors you now DELETE construct by
construct as you implement each one — that gate exists precisely
for you).

## Build, in order (red-first per item)

1. - [ ] **§4 control pass**: `set:`/`layer_*:` as control actions
   in the bounded transaction phases; releases unconditional; at
   most one rising control action per §4's deterministic-winner
   rule; source-program pinning; no recursive passes. The §4 trace
   rows including the round-2 finding-5 case (layer_hold release +
   higher-priority set edge in one transaction — teardown is
   unconditional reconciliation).
2. - [ ] **§5 shifts/layers**: base-only flags, entry ownership,
   ordered-fold effective program (later-wins), the ≤65
   ordered-stack validation, reload cleanup, §5.1 transition
   ownership clearing.
3. - [ ] **§6 chords**: zero-latency modifier-first, declaring-path
   consumption for BOTH affected paths through physical release,
   irreversible-first-source law, simultaneous-rise/symmetric
   rejection, system chords always win.
4. - [ ] **§7 dual triggers + stick rings**: the numeric laws
   (normalized/clamped radius, hysteresis, soft+full coexistence,
   analog max-fold) with their trace tables.
5. - [ ] **§8 zones + circular scroll**: split click/touch
   activation state tables (the §14.1/§14.2 reconciliation), zone
   `activation`/`zones`/`overlap`, scroll `style`/`cw`/`ccw`
   edge-pulse deliveries.

## Warts / traps

- Every construct you implement must remove its "not yet supported
  by this daemon" load error in the same commit — grep for the
  gate's construct list at the end; anything left is unfinished
  scope, anything removed without implementation is a lie.
- Trace tables cite v3 sentences like the engine loop's did.
- Injected now_ms only; all prior suites green; no new crates.
- PR.md to /workspace/PR.md. Never `git add -A`.

## Finish — PR.md
Per-section trace audits; the deleted-error construct list; the §4
finding-5 trace verbatim; untested-here.
