# SPEC — osc-wave4-views: diagram view + live input tester (wave 4, editor depth)

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-2.

**Read first, all on main:** `CLAUDE.md`;
`docs/design/overlay-and-services.md` **v5** §1 (diagram — GO) and
§2 (tester — GO): law, including the hit-map JSON schema, the
22-entry region registry, the `(session, seq)` staleness law, and
`ControllersChanged`. `docs/design/editor.md` for style law.

## Build, in order (red-first per item)

1. - [ ] **Hit-map generation**: extend the generate.py pipeline to
   emit the base raster + `controller-diagram.hitmap.v1.json` per
   §1.1, with the one-to-one SVG-id ↔ registry diff and
   target-vocabulary validation as GENERATION-TIME failures; commit
   the artifacts; the gate re-runs generation and diffs (icon-blob
   precedent).
2. - [ ] **Diagram view**: fourth navigation altitude per §1 —
   raster + hit-test + hover highlight + §1.2 click targets +
   binding-summary chips (base-mode, header-labeled) + §1.3
   keyboard cycling with focus ring. Rect-overlay highlight only;
   no per-region raster work.
3. - [ ] **Daemon snapshot surface**: `GetControllers() → a(sbbt)`,
   `ControllersChanged`, and `GetInputSnapshot` exactly per §2.1 —
   ident law (serial else `path:<basename>`, known map, session
   generations), the f32 → i16 conversion rule, zeroing exemptions,
   UnknownController error. Publication via the per-controller
   shared slot; the D-Bus thread sends no controller commands.
4. - [ ] **Tester panel**: §2.2 — diagram with live paint, 30 Hz
   poll only while open, 1 Hz grey-out retry, selector from
   GetControllers with the 5 s bounded refresh and single-candidate
   fallback, sleeping/unreachable overlays.
5. - [ ] **Zone-layout visuals** (founder request 2026-08-19, after
   confirming zone buttons in-game): the trackpad behavior card
   shows a small inline glyph of the active zone layout (the
   4-split cross with the bound directions highlighted), so the
   difference between layouts is visible at a glance, not inferred
   from labels. Same pre-rendered-asset pipeline as the diagram —
   no runtime SVG. Also shown in the behavior dropdown's hint row.
6. - [ ] **Preview tour**: diagram + tester + zone-glyph steps
   (tester renders against a fake snapshot source — the poll layer
   is a trait so the tour never needs a daemon).

## Warts / traps

- The registry table's 22 rows are law — the generator must fail on
  any drift, not silently skip.
- Snapshot staleness: `seq` never compared across `session`; the
  editor watches NameOwnerChanged.
- Polling stops the frame the panel closes — a leaked timer is a
  review rejection.
- No new crates (svg parsing at generation time uses the existing
  Python pipeline, not a Rust dependency).
- PR.md to /workspace/PR.md.

## Finish — PR.md
Generation-gate description; region-registry audit; D-Bus method
signatures as landed; tour confirmation; untested-here.
