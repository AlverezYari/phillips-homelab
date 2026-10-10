# SPEC — osc-wave2-editor: activator, shift/layer, dual/ring, zone editors (wave 2 loop 3 of 3)

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-2.

**Read first, all on main:** `CLAUDE.md`;
`docs/design/timing-engine.md` v3 §3 (schema/upgrade law) + the
merged wave-2 loops 1–2 (their PRs name every construct);
`docs/design/editor.md` (style law — style.rs vocabulary only, word
labels, no glyphs); the wave-1 editor loop's §14.1 preservation
precedent. Extend `examples/preview.rs` for EVERY new screen; the
tour must exit 0 in your iteration loop; the conductor
pixel-reviews after landing.

## Build

1. - [ ] **Activator settings**: the advanced (gear) editor's
   reserved slots go live — long_press/double_tap/turbo/start/
   release rows with their timing fields (`long_press_ms`,
   `double_tap_ms`, `turbo_ms`, `fire_delay_ms`, `interruptible`),
   fan-out arrays, `{ cycle = … }` editing. Byte preservation per
   §14.1 for every untouched sibling key — red-first.
2. - [ ] **Schema-2 upgrade prompt**: the first wave-2 construct
   added to a schema-1 document triggers the one-way confirmation
   (timing-engine §3); declining reverts the edit cleanly. The
   editor writes the file's existing schema otherwise.
3. - [ ] **Shift/layer editors**: mode list gains layer flags
   (base-only law surfaced), shift tables per source, an
   effective-program preview row ("what this button does in
   <stack>") driven by the same fold code the daemon uses — zero
   reimplementation.
4. - [ ] **Dual trigger / ring / zone / scroll editors**: dual
   trigger soft+full rows, stick ring threshold rows, zone
   activation/overlap dropdowns, circular scroll style + cw/ccw
   binding rows. Vocabulary from osc-config only (compile-visible
   gap tests extend to every new variant).
5. - [ ] **Preview tour**: new steps for every screen above;
   every existing step keeps working.

## Warts / traps

- The effective-program preview MUST call the daemon-shared fold
  in osc-config; a second fold implementation is an automatic
  review rejection.
- No daemon changes. No new crates. PR.md to /workspace/PR.md.

## Finish — PR.md
Screen-by-screen list; preservation test names; upgrade-prompt
flows (accept + decline); tour confirmation; untested-here.
