# SPEC — sol-review-osc-profiles: adversarial review of the per-game profiles design (REVIEW ONLY)

Repo: `loop-bot/OpenSteamController`. Gate: `test -s /workspace/repo/REVIEW.md`.
Engine: codex (Sol). This is a DESIGN review, before any build loop.
You change NOTHING except creating `REVIEW.md` at the repo root. Any
other file modification is a spec violation.

## What to review

`docs/design/config-profiles.md` on `main` — a per-game profile system
(TOML config model, profile switching, KWin auto-switch, separate egui
editor) — against the codebase it lands in, especially:

- `src/devices/mapper.rs`: the reconciliation transaction the design
  claims needs no changes below `compute_desired_outputs`. The shipped
  three-mode design (`docs/design/input-modes.md` v2) is settled law —
  review the NEW design's fit against it, not the old decisions.
- `src/devices/mod.rs`: DeviceCommand/DeviceProperties/tray descriptor
  plumbing that `SetProfile` and the profile submenu must ride.
- `src/main.rs`, `src/multi_threading.rs`: thread/ownership boundaries
  the ConfigStore and D-Bus reload signal must respect.
- `Cargo.toml`: the dependency reality (dbus 0.9 already present;
  serde/toml/eframe are proposed additions).
- `CLAUDE.md`: sandbox constraints every implementing loop lives under
  (no hardware, no D-Bus session, Windows compiles blind).

## The brief — try to break it

An unattended build loop implements whatever this design
underspecifies. Hunt specifically for:

- **The interpreter refactor's equivalence claim.** "Existing tests
  pass unchanged against the built-in default profile" — is that
  actually achievable given how the current compute functions compose
  (Hybrid building on Gamepad's output, the overlay resolution, the
  Nintendo swap placement)? Find any current behavior that the
  proposed Profile/Mode/Binding data model *cannot express*, which
  would force either a model change or a silent behavior change.
- **Schema soundness.** Typos-as-errors vs. the activator
  warn-and-inert exception: is the boundary crisp enough to implement?
  Version gating (`schema = 1`): what happens to a schema-2 file, a
  missing version, a duplicate mode name, zero modes, 9 modes, two
  overlay modes, an overlay-only profile? Output vocabulary: any
  `ControllerInput` reachable today that the proposed vocabulary can't
  name, or names ambiguously (trigger click vs axis, stick click vs
  stick mode)?
- **Profile lifecycle races.** SetProfile mid-transaction vs. the
  HID-report-first-then-command ordering; reload of the ACTIVE profile
  while a mode within it is latched (mode index still valid? name
  lookup?); last-good semantics when the active profile's file becomes
  invalid; per-controller active profiles when a profile is deleted on
  disk; what the tray shows during each of these.
- **The D-Bus surface.** The design hangs reload-signaling and the
  FocusWatcher on the existing `dbus` 0.9 crate — check what that
  crate actually is (blocking libdbus bindings): does receiving
  signals fit the current thread model without a dedicated D-Bus
  thread, and does the design say who owns it? Is the daemon
  exporting a name/object actually specified (name, path, interface),
  or hand-waved?
- **KWin focus watching.** Is "KWin exposes focus via its
  scripting/D-Bus surface" real and stable enough to spec a loop
  against, or does it need a KWin script installed (user-visible
  setup)? What's the story on X11 games under XWayland — do they get
  usable app-ids? The design must not send a loop to "verify against
  the target system" it doesn't have — the sandbox has no KDE. Flag
  what must be resolved by the conductor on real hardware first.
- **Editor boundary.** Atomic-write + reload-signal on save: TOCTOU
  between editor write and daemon reload? Editor and daemon versions
  drifting (editor writes vocabulary the daemon doesn't know — is the
  shared-crate boundary specified, or will the loop invent two
  vocabularies?). Is "daemon never links egui" actually enforceable in
  one workspace (feature flags / separate crates) as written?
- **Scope-fence integrity.** Anything the design implies but fences
  out (activator timing, hot-reload watching, Windows profiles) that
  will force an implementing loop to violate a fence or file
  avoidable decisions.

## Output

Create `REVIEW.md` at the repo root: ranked findings (most-severe
first), each with the design section or file:line, why it's a problem,
a concrete failure scenario, and a suggested design edit. Separate
genuine correctness/underspecification findings from taste. If parts
are solid, say so plainly — do not invent problems. End with GO /
NO-GO for handing stage-1 (osc-config-model) to a build loop, and note
which findings block only later stages.
