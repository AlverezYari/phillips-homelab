# SPEC — sol-review-osc-radial: adversarial review of the radial-menu design (REVIEW ONLY)

Repo: `loop-bot/OpenSteamController`. Gate: `test -s /workspace/repo/REVIEW.md`.
Engine: codex (Sol). You change NOTHING except creating `REVIEW.md`.

First round on `docs/design/radial-menus.md` v1 — the document
`overlay-and-services.md` §3 (v5) demanded, written against its
required table of contents. Context to read: `timing-engine.md` v3
(BindingPath grammar §2.1, schema-2 list §3, ownership §5.1, §14.6
pulses, §5 fold law), `config-profiles.md` (§14.0 identity, §14.1
preservation, §7 diagnostics), `overlay-and-services.md` v5 §3's
fence and its round-1 fold list (the ToC contract).

Attack, in priority order:

1. Does the document actually discharge every item of the §3 fence's
   required contents? Anything still delegated to a build loop's
   invention?
2. The §2 machine: totality over (state, event); the touch-ownership
   law vs wave-1 `pad_*_touch` semantics (§14.2 click/touch
   suppression interactions); commit-on-touch-loss as a deliberate
   choice — does it contradict any existing touch law?
3. The pulse-delivery claim: does §14.6 pulse law actually compose
   with full DigitalBindings (cycles, fan-out, control actions) the
   way §1 asserts, per timing-engine v3's sink laws?
4. Positional identity + generation-bump argument: is there any
   state that survives an edit that would misattach?
5. One-directional IPC: any correctness need for an overlay→daemon
   channel the design wishes away? Multi-output/pointer-on-no-output
   anchoring; two controllers opening menus on both pads/sides at
   once (signal is per (ident, side) — is the overlay's
   newest-signal-only rule total then?).
6. Degradation: loud-off vs blind-fire — internally consistent with
   §4's overlay-death-mid-open Cancel?

Do not relitigate: schema 2, egui for the editor, the fence
mechanism itself, deferral of the crate ruling to the founder.
Concision over prose.

## Output

`REVIEW.md`: findings ranked, GO / NO-GO for promoting the document
to law (with its same-commit amendments), minimal fold list if
NO-GO.
