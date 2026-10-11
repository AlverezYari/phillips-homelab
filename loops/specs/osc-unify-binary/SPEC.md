# SPEC — osc-unify-binary: ONE installed binary (founder ruling, top priority)

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-2.

**Founder ruling (2026-08-19, verbatim intent):** the project ships
as ONE binary — a system tray daemon that can pop up the editor.
No little binaries for each little thing. The current state (three
installed bins: open-steam-controller, osc-editor, osc-explore) is
rejected. Library crates inside the workspace are fine — users
never see them. Installed artifacts: exactly one.

## Build

1. - [ ] **Single bin target**: `open-steam-controller` is the ONLY
   `[[bin]]` in the workspace. Dispatch on argv[1]:
   - no args → daemon + tray (unchanged behavior);
   - `editor` → the full osc-editor GUI (the `osc-editor` crate
     becomes a pure library; its `main` becomes `pub fn run()`);
   - `explore imu|rumble` → the capture harness (currently the
     `osc-explore` bin; same not-for-release caveats move into the
     subcommand's help text — the SUBCOMMAND ships, dev-tool
     framing stays);
   - `--help`/unknown → usage naming exactly these.
   Std-lib arg matching — no clap, no new crates.
2. - [ ] **Tray → editor**: the tray menu gains/keeps an "Open
   editor" item that spawns `current_exe() editor` detached. The
   editor .desktop file (`osc-editor.desktop`) execs
   `open-steam-controller editor`; add
   `open-steam-controller.desktop` for the daemon itself
   (autostart-appropriate, Exec = the bare binary).
3. - [ ] **Single-instance guard (daemon)**: on startup, if the SNI
   well-known name / D-Bus service name is already owned, print
   which pid owns it and exit nonzero ("already running (pid N) —
   one instance only"). No second tray item can ever appear. Test
   via a fake bus-name probe trait.
4. - [ ] **Tray truth check**: a harness test asserting the ksni
   `icon_name()` is EMPTY and `icon_pixmap()` non-empty for every
   `IconState` — pinning the KDE SNI precedence fix (commit
   7e4e9dc) so a themed name can never silently hide the battery
   pixmaps again.
5. - [ ] **Migration**: `make install` (add the target) installs the
   one binary + both .desktop files and REMOVES stale
   `~/.local/bin/osc-editor` and `~/.local/bin/osc-explore` if
   present. PR.md documents the one-liner for existing installs.

## Warts / traps

- The daemon binary now links egui (editor code) — accepted cost of
  the ruling; do NOT lazy-load, plugin-ize, or split anything to
  "save size". One binary means one binary.
- `docs/design/radial-menus.md` §3.1: amend in this commit —
  `osc-overlay` is NOT a separate binary; it becomes the
  `open-steam-controller overlay` subcommand (daemon spawns
  `current_exe() overlay`). Same for any future helper: subcommands
  of the one binary, never new bins.
- Keep crate boundaries (osc-config / osc-editor-as-lib / daemon) —
  the unification is the SHIPPED artifact, not a code smoosh.
  Preserve every existing test; preview tour keeps working against
  the lib crate.
- PR.md to /workspace/PR.md. Never `git add -A`.

## Finish — PR.md
The dispatch table; guard behavior; install/migration notes; the
radial amendment hunk; untested-here.
