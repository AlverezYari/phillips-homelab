# SPEC — osc-config-files: profiles on disk (profiles stage 2)

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-1.

**Read first, all on main:** `CLAUDE.md`;
`docs/design/config-profiles.md` **v3** — law, specifically §3 (file
locations, TOML document shapes, validation table, cycling/selection
rules), §4 (CatalogSnapshot generations, carry-forward stale, durable
serial identity, lifecycle table), §5 (TrayState/TrayCommand, dynamic
submenu, zero-controller reload), §6 (the D-Bus contract:
`dev.opensteamcontroller.Daemon1`, digest-attributed `ReloadProfiles`,
dedicated pump thread, `dbus-crossroads`), §7 (activator
warn-and-inert), §9 (Windows: none of this exists there). Stage 1
(merged: `osc-config` crate, `step` interpreter, compiled-in defaults)
is the foundation; do not modify the interpreter or vocabulary.

## Why

Stage 1 made modes data; stage 2 makes them *files*. After this loop a
user can drop `elden-ring.toml` in the profiles dir, pick it from the
tray (or D-Bus), and the mapper runs it — with the shipped defaults
untouchable underneath, broken files held to last-good, and every
error visible instead of silent.

## Build, in order

1. - [ ] **TOML round-trip in `osc-config`**: parse/serialize the §3
   profile and games.toml document shapes into the existing stage-1
   types, emitting §3's validation table as typed `Diagnostic`s —
   red-first tests covering EVERY table row (schema gating, mode
   cardinality, overlay rules, unknown-key rejection at every depth,
   activator warn-and-inert, combination-rule errors, games.toml rule
   validation). Property: any accepted document re-serializes to an
   equivalent document (editor round-trip safety, stage 4 depends on
   it).
2. - [ ] **ConfigStore + CatalogSnapshot** (daemon, coordinator-owned):
   XDG discovery, generation counter, carry-forward-stale semantics,
   `default` reservation (file named `default.toml` = load error), the
   full §4 lifecycle table as pure-testable transitions. games.toml
   loads/validates here too (matching itself is stage 3 — store the
   rules, don't act on them).
3. - [ ] **Selection plumbing**: `SetProfile(id)` through the
   coordinator → queued per-controller transition carrying the
   snapshot Arc → next transaction swaps and reconciles (behavior
   memory cleared — the §4 rules). Accepted-profile rule: first
   non-overlay mode. Reload-while-latched: preserve by mode name,
   else first. Serial-keyed persistence in `state.toml`,
   coordinator-writes-only; no-serial controllers are session-only.
4. - [ ] **TrayState/TrayCommand**: the §5 owned structs replacing the
   cloned-`DeviceProperties`-only channel; dynamic profile submenu
   (owned strings, NOT the `'static` Choice descriptor) + per-device
   active profile/mode + catalog statuses + diagnostics + reload
   action, in BOTH `status_tray.rs` and `status_tray_not_linux.rs`;
   the non-Linux skip-if-unchanged check compares full `TrayState`
   including generation. Reload must work with zero controllers.
5. - [ ] **D-Bus service**: `dev.opensteamcontroller.Daemon` name,
   §6 object/interface, `ReloadProfiles(a(ss)) -> (u, a(ssssss))`
   exactly — digest verification per §6, one lossless `Diagnostic`
   schema everywhere. `dbus-crossroads` added (founder-approved,
   Linux-only dep). Dedicated pump thread owning the connection,
   channels to the coordinator, bounded replies. `FocusChanged` is
   NOT implemented (stage 3); do not stub it into the interface.

## Warts / traps

- **No D-Bus session, no hardware in the sandbox.** Structure the
  D-Bus layer so everything interesting (digest matching, diagnostic
  assembly, request→coordinator→reply flow) is pure-testable with the
  bus mocked as channels; the actual connection glue must be thin and
  is untestable here — say so in PR.md, never "verified".
- Do not touch `osc-config`'s interpreter, vocabulary, or defaults
  beyond what TOML derives strictly need (serde attrs on existing
  types are fine; semantic changes are not).
- Windows (§9): no profile loading, no submenu, no D-Bus — `cfg` it
  out cleanly; workspace still compiles blind for that target.
- Filesystem tests use temp dirs; never read the real XDG paths in
  tests. The daemon must not create the profiles dir with contents —
  empty dir + compiled-in default is the fresh-install state.
- Steam+X cycling semantics (non-overlay modes, file order) are
  interpreter-side and already landed in stage 1 — do not
  re-implement; just feed it profiles.
- Never `git add -A`.

## Finish — PR.md must contain

- The validation-table audit: every §3 row → the test that pins it.
- The lifecycle audit: every §4 table row → the test that pins it.
- A fresh-install walkthrough (empty config dir → default profile
  active → drop a file → reload → select → reboot persistence), as a
  narrated sequence of the actual tests that cover each step.
- The exact D-Bus interface XML/introspection as implemented.
- Untested-here honesty section (live bus, live tray, hardware).
