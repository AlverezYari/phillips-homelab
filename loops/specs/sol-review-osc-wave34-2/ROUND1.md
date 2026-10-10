# Adversarial review: waves 3 and 4

Settled rulings (schema 2, egui, raster + hit-map, pull-based testing,
and hardware gating) are accepted. The question here is whether these
drafts are executable law for unattended build loops.

## `motion-and-feedback.md`

**Verdict: NO-GO.** `osc-explore` and `osc-analog-shaping` are not yet
buildable without inventing protocol or math. Gyro and haptics are
correctly gated and remain NO-GO until a post-capture amendment.

### Findings, ranked

1. **BLOCKER — the proposed schema-2 shape contradicts the closed
   schema contract.** The draft adds `sensitivity`, inversion,
   `deadzone`, `response`, `curve`, and `speed`
   (`motion-and-feedback.md:47-63`), but none appears in timing-engine
   v3's *exhaustive* schema-2 trigger list
   (`timing-engine.md:166-185`), config-profiles' closed behavior
   vocabulary, or its unknown-key validation. A conforming validator
   must currently reject these fields. The draft also does not give
   their exact TOML nesting or which behavior variants admit each key.

2. **BLOCKER — the rumble explorer guesses writes to an unknown
   device, so its safety claims are not derivable.** “Starting from”
   an older controller's `0x8f` family and “systematic variations”
   (`motion-and-feedback.md:37-43`) is neither a finite candidate
   corpus nor evidence that any varied byte is amplitude, duration,
   report ID, checksum, or even haptics. “Amplitudes start minimal”
   and “Esc stops output instantly” therefore assume the very protocol
   being discovered; Esc cannot undo an already accepted latched or
   long-running command. An unattended loop would have to invent
   report bytes and a safety envelope.

3. **HIGH — the captures cannot establish the facts the later
   amendment promises.** IMU capture pre-interprets bytes 30-48 as
   adjacent signed-16 values and records only a timestamped CSV plus a
   best guess (`motion-and-feedback.md:29-36`). It does not preserve
   full raw reports, report length/ID, byte order alternatives,
   controller/transport identity, prompt boundaries, or distinguish
   accelerometer response from angular velocity. The rumble log does
   not normatively include the exact transmitted bytes, feature vs.
   output transport, return status, monotonic send/button times,
   negative trials, or stop outcome. “Structured findings” has no
   schema, version, or fixture location (`motion-and-feedback.md:44-45`).
   Such artifacts cannot provide auditable provenance for normative
   offsets or report constants.

4. **HIGH — analog shaping is parameter names, not a transform.** The
   draft leaves a build loop to choose axial vs. radial deadzone,
   rescaling outside the deadzone, signed-axis inversion order,
   whether sensitivity acts before or after the curve, what
   `quadratic` means for negative inputs, custom-curve endpoint and
   interpolation rules, output clamping, and how `speed` composes with
   the existing stick/pad mouse and linear/circular scroll constants.
   “Monotonicity-validated” does not state x/y bounds, endpoint
   requirements, duplicate-x handling, or finite-number rejection.
   Defaults for deadzone/response/inversion are also absent. The
   reference to trigger clamp-max law (§14.4) does not define a 2-D
   stick/pad pipeline.

5. **MEDIUM — the destination is not compatible law yet.** A
   mode-level gyro entry is absent from timing-engine v3's entry
   ownership graph (`timing-engine.md:227-246`), and `gyro_when =
   "button:<src>"` does not say whether it observes raw physical
   state before consumption or an effective binding contribution.
   `pad_touch` does not select a side. Per-activator `haptic` is absent
   from the schema-2 trigger list, while pad-edge haptics need explicit
   ownership, cancellation, reset, reload, and hotplug rules. The
   draft does promise a later amendment (`motion-and-feedback.md:65-77`);
   these bullets must remain non-authorizing scope until that amendment
   exists.

### Minimal fold list

1. Amend timing-engine §3 and config-profiles §2/§3/§7 with the exact
   schema-2 nesting, eligibility matrix, validation/default rows, old/new
   reader fixtures, and editor preservation/upgrade behavior for every
   shaping field.
2. Specify one ordered shaping function with equations and golden vectors:
   normalization → deadzone/rescale → inversion → response/custom
   interpolation → sensitivity/speed → clamp, including every boundary and
   non-finite input rule.
3. Replace rumble “systematic variations” with a founder-approved,
   finite exact-byte manifest and a protocol-independent safety policy
   (bounded count/rate, timeout, write-result logging, device allowlist,
   explicit warning that abort cannot retract a sent command). Do not claim
   an emergency stop until a stop command is measured.
4. Define versioned raw capture/finding formats that preserve exact input
   and output bytes, transport/device metadata, monotonic timing, prompts,
   acknowledgements/errors, negative trials, and human observations. Axis
   inference must be reproducible from raw captures rather than replace
   them.
5. Keep gyro/haptics fenced; after capture, amend the schema trigger list,
   `BindingPath`/ownership model where needed, activation semantics,
   calibration identity/lifecycle, output cancellation, and
   reload/hotplug/reset behavior before issuing those loops.

## `overlay-and-services.md`

**Verdict: NO-GO.** The architecture choices can stand, but none of the
four tracks is complete enough to hand to an unattended build loop:
diagram **NO-GO**, tester **NO-GO**, radial menus **NO-GO**, and
yield-to-Steam **NO-GO**.

### Findings, ranked

1. **BLOCKER — radial menus are illegal under timing-engine v3.** The
   draft declares schema-2 `TrackpadBehavior::RadialMenu` items and
   `trackpads.<side>.menu.<n>` paths
   (`overlay-and-services.md:51-55`), but the closed `BindingPath`
   grammar admits only zone/click/ring/circular-scroll pad paths
   (`timing-engine.md:44-65`), and the exhaustive schema-2 trigger list
   has no radial-menu construct (`timing-engine.md:166-185`).
   `{label, output}` also conflicts with “standard activator pipeline”:
   it is unclear whether `output` is a `DigitalOutput`, full
   `DigitalBinding`, fan-out, cycle, or control action. Ownership under
   shifts/layers and every reachable-fold validation are consequently
   undefined.

2. **BLOCKER — yield detection cannot produce the promised lifecycle.**
   A `/proc` scan only “once per focus change” cannot notice Steam
   exiting or its virtual pads vanishing when focus does not change, so
   it cannot drive the stated automatic reacquire
   (`overlay-and-services.md:61-68`). The draft alternates between Steam
   owning hidraw paths and named virtual pads without defining whether
   either or both cause parking, how devices/PIDs are authenticated, or
   behavior when `/proc` is hidden or races. It omits a state machine for
   startup, Steam already running, simultaneous claim, park, backoff,
   force-hold precedence, Steam crash, daemon restart, controller
   disconnect/reconnect, and multiple controllers. The acknowledged
   reacquire race (`overlay-and-services.md:71-72`) is a required part of
   the contract, not a loop-time choice.

3. **HIGH — `GetInputSnapshot` is not a D-Bus contract.** The proposed
   no-argument method cannot select among the per-controller caches it
   names (`overlay-and-services.md:26-30`). “axes, pad samples” gives no
   D-Bus signature, field order, normalized ranges, or versioning. A
   last value needs controller identity plus connected/valid status,
   monotonic sample time or sequence, and an explicit rule for reset,
   disconnect, replacement, no-report-yet, and stale values. The design
   also does not say how controller-thread transaction state is published
   to the coordinator, linearized against hotplug, and read without
   turning a 30 Hz editor poll into controller commands. Poll failure,
   daemon restart, panel close, and selected-controller change need total
   UI behavior.

4. **HIGH — radial selection and overlay IPC have no total state
   machine.** Missing law includes activation gesture, allowed item count,
   center/dead zone, angle zero/direction/order, exact sector boundaries
   and hysteresis, out-of-bounds motion, touch loss/regain, release with no
   sector, cancellation/dismissal, transitions/reload/reset/hotplug, and
   compositor/overlay crash. The D-Bus exchange lacks controller ID,
   program generation, menu instance ID, ordering, acknowledgement, and
   stale-reply rejection. “Input-transparent except during selection” is
   also underspecified: daemon-fed pad selection needs no pointer/keyboard
   capture, while changing layer-shell interactivity can steal unrelated
   desktop input. “Unavailable” is a runtime capability, so its diagnostic
   owner/lifetime and exact off/cancel behavior must be stated rather than
   left to config validation (`overlay-and-services.md:42-57`).

5. **MEDIUM — the diagram asset and generated hit-map lack a semantic
   contract.** The draft gives no JSON schema, coordinate space, scaling/
   letterboxing rule, overlap priority, deterministic generator gate, or
   source-to-editor-row map. The landed SVG is not “one stable id per
   input”: it uses aggregate `region-dpad`/`region-face`, nested overlapping
   face regions, `region-l2` where the bindable source is `l2_click`, and
   one stick/pad region where click, touch, axis, and behavior are distinct
   editor concepts. `region-steam` is present although Steam is expressly
   unbindable. A loop must not infer which row a click opens. Binding
   summaries also need a declared base-vs-effective (shift/layer) view and
   accessible keyboard navigation; raster hit-testing cannot be the only
   navigation path.

6. **MEDIUM — editor preservation/validation consequences are absent.**
   Radial items introduce labeled, ordered nested bindings, schema upgrade,
   unknown-key preservation, output/control validation, and reorder/delete
   effects on path identity. None is folded into config-profiles' shared
   model or the editor's preservation contract. Diagram and tester must
   remain projections over that shared model; they must not invent a second
   binding vocabulary.

### Minimal fold list

1. Amend timing-engine and config-profiles for radial menus: exact TOML,
   schema-2 trigger, full item binding form, closed path grammar, stable
   identity, ownership/reachable-fold validation, bounds, editor upgrade,
   and syntax preservation.
2. Give radial input and daemon↔overlay IPC total state machines, including
   geometry, dismissal/commit, cancellation, generation/instance IDs,
   crash/unavailable behavior, and reload/hotplug/reset traces. Pin the
   dependency only after that contract determines the required surface API.
3. Define a versioned `GetInputSnapshot(controller_id)` wire tuple with
   exact types/ranges, validity/connected state, sequence/timestamp, cache
   publication ownership, staleness/reset rules, errors, and multi-controller
   UI behavior.
4. Define the hit-map JSON and semantic region registry, resolve the landed
   SVG's aggregate/overlapping/non-bindable IDs explicitly, specify geometry
   transforms and overlap order, and gate generation deterministically.
   State what binding summary is shown and preserve keyboard-accessible
   navigation.
5. Specify yield-to-Steam as an observed-event/state table with authoritative
   evidence, monitoring cadence, permission/race degradation, per-controller
   scope, force-hold precedence, bounded reacquire backoff, hotplug/restart
   behavior, and tests over a fake process/device observer.
