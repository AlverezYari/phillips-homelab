# Haptic integration architecture review

## Verdict

**NO-GO for the haptics build loop as currently scoped in §2.3.5.** The
hardware result in §2.3.4 is sufficient to start a transport-only loop, but
the proposed integration is not yet a complete ownership or mapper contract.
In particular, claiming interface 2 invalidates the landed hidraw-based
enumeration and the proposed yield-to-Steam evidence model; the profile shape
also adds an eighth activator sink without defining its timing semantics.

The transport decision itself is sound with a narrower boundary: accept
`rusb` as a Linux-only dependency and move **only PID `0x1304`, USB interface
2** to a libusb session backend. Keep all existing non-`0x1304` paths,
including cable/Bluetooth, and all unproven Triton interfaces on hidapi. Do not
describe that boundary as “the daemon becomes `hid-steam`.” It assumes a
small, explicit subset of that driver's responsibilities—claim/release
interface 2, apply the proven config, read input, keep lizard disabled while
held, and write feedback. Pairing, firmware, other interfaces, generic Valve
hardware, and kernel-driver parity remain non-goals.

After the folds below, the first transport/discovery loop is **GO**. A single
loop spanning transport, haptic output, profile vocabulary, game rumble, and
the editor is not.

## Findings, ranked

### P0 — A libusb claim breaks the landed discovery and hotplug model

`devices/mod.rs` is not transport-neutral today. `Controller` has only a
`Hid` variant, `DeviceState` owns a concrete `HidDevice`, the `Device` default
read/write methods reach through that concrete field, and the per-device
factory runs only after hidapi has opened every matching interface. Replacing
the byte source inside `SteamController` is therefore not a local edit.

More importantly, the Triton puck exposes five HID interfaces while
`connect_hid_devices` still selects entries positionally with `step_by(3)`.
`count_compatible_devices` counts HID interface entries, not physical
controllers. A libusb claim auto-detaches `hid-generic` from interface 2, so
that hidraw entry disappears; releasing it for Steam makes it reappear. The
main loop treats any such count change as global hotplug, tears down every
controller thread, and reconnects. PARK/reacquire would consequently churn or
race rather than transfer ownership. Positional selection also cannot
associate the correct libusb device with a controller when multiple pucks are
present.

Fold a physical-device discovery layer before adding haptics:

- Identify a physical controller by USB parent (bus plus port path for the
  live instance, USB serial for durable profile selection), group interfaces
  under it, and select interface 2 by descriptor—not enumeration position.
- Let the device factory choose a backend from a discovered descriptor before
  opening it. Put `read_timeout`, feature/control write, interrupt write, and
  release behind one small session/transport boundary. `SteamController`,
  `RawState`, and `osc_config::step` should not know which backend supplied the
  bytes.
- Count and hotplug physical identities, not hidraw nodes. One interface
  detaching or reattaching must not look like a controller add/remove.
- Prove interrupt-IN parity with the committed `0x42` fixture and run the same
  parser/mapper transaction above both backends. This is the clean seam that
  makes “Triton only on rusb” coherent rather than a second device stack.

### P0 — The proposed PARK path cannot observe or release libusb ownership correctly

`overlay-and-services.md` §4 defines authoritative Steam evidence as a Steam
process holding a matching **hidraw fd**. Once this daemon has detached
interface 2 there may be no matching hidraw node, and a Steam process using
the raw USB transport demonstrated by the usbmon capture may hold
`/dev/bus/usb/...`, not hidraw. An EBUSY result with no recognized evidence is
required to remain `ACQUIRING(busy)`, so the current law can make legal
`PARKED` unreachable precisely when Steam owns the interface.

Amend the ownership law to use the physical USB identity and recognize the
relevant usbfs handle as authoritative evidence, while retaining the same-uid
process restriction and loud hidepid degradation. Store identity before
detaching the kernel driver; do not depend on the continued existence of the
claimed hidraw node.

The transition actions also need USB-specific ordering. `HOLDING -> PARKED`,
remove, replacement, and shutdown must stop any latched `0x80` rumble, reset
virtual outputs, stop keepalives, release interface 2, and reattach its kernel
driver before publishing the non-owning state. Acquisition is the reverse:
rescan evidence, claim exactly that physical device/interface, configure it,
start the read session, then publish `HOLDING`. Any partial failure must unwind
the claim. Run this state machine independently per physical controller; a
Steam claim on one puck must not restart or park another.

Yield-to-Steam is design-only in the landed tree, so it cannot be left as a
future integration detail of the transport port. The transport lifecycle and
the §4 state machine must share one owner of the handle.

### P0 — Lizard/watchdog lifecycle is underspecified and the current cadence is unsafe

The reference's successful order is material: claim interface 2, send all
three proven configuration transfers (including amplitude registers), then
maintain interrupt-IN plus an output keepalive. §2.3.5 does not say when a
controller becomes visible to the coordinator or what happens if transfer 2
of 3 fails. It should become `HOLDING`/connected only after the entire sequence
succeeds; otherwise release and reattach.

The landed `active_refresh_state` runs every 300 controller-loop turns. With
the usual 50 ms passive read bound that is about 15 seconds, already longer
than the measured 8-second watchdog, and the cadence is turn-count based. The
libusb session needs a monotonic keepalive deadline comfortably below eight
seconds. Check it after every read and write, including a busy stream of input
reports; a timeout is not the only opportunity. A keepalive write is a
timing-engine wake and still owes exactly one mapper tick. Do not use a second
uncoordinated writer thread on the same handle.

Define cleanup rather than relying on `Drop`: send the proven stop/zero frame
for any latched effect, stop scheduling writes, release the interface, and
request kernel-driver reattachment on normal exit, PARK, disconnect, read-loop
failure, and failed startup. If no proven “restore lizard now” command exists,
say explicitly that firmware returns via the watchdog and can take up to eight
seconds; amplitude registers are not claimed to be restored. Also document the
SIGKILL/crash limit and hardware-test whether kernel reattachment occurs after
forced process death. Profile reload changes mapper state but must neither
reclaim nor resend device-global config; it only cancels pending activator
state, while any latched game rumble is stopped when its effective policy is
removed.

### P1 — `haptic` as a new sink contradicts the landed activator and pulse law

The landed activator has seven classification sinks whose slot values resolve
to output contributions. §14.6 then classifies each contribution as stateful
or pulse-on-rising before OR-composition. A sibling `haptic = ...` field that
“fires on the resolved press” is an eighth sink with unanswered behavior for
double-tap, long-press, toggle, start/release, turbo, fire delay, cycles,
fan-out, cancellation, and aliasing. Calling that §14.6 “verbatim” does not
make it so.

Make haptics a pulse-class **output action** usable inside the existing slot
forms instead. Generalize an activator slot from `DigitalOutput` to a closed
action enum containing digital output and `HapticEffect`; return resolved
`FeedbackEvent`s alongside `RelativeEvent`s from `step`. A haptic contribution
emits only when the existing contribution's `rising` flag is true, exactly as
wheel pulses do. Thus `press`, `long_press`, `release_press`, fire delay,
turbo, fan-out, cycles, consumption, transition clearing, and per-path
aliasing need no second timing law. The daemon consumes the feedback vector
for that same physical controller; it is not a global `DaemonCommand` and
never enters `DesiredOutputs`.

Radial-menu §2.3 reinforces this conclusion: it injects a synthetic source
edge through the existing classifier and all existing sinks, and explicitly
forbids a special sink law. Zone-buttons directions, stick/pad rings, and
circular-scroll `cw`/`ccw` are already full binding occurrences. Binding a
haptic action there gives edge ticks; a new behavior-level `tick` option is
redundant and would create a parallel activation path.

The schema amendment must close all remaining vocabulary:

- exact serialized forms, including how a haptic action participates in
  fan-out and cycle;
- side names and admitted actuator set (pad versus internal), with no numeric
  escape hatch outside the proven enum;
- `script` ID `1..=16`, `gain_db` `-23..=24`, and whether gain is admitted on
  presets, scripts, pulses, or only the forms the wire format supports;
- finite integer ranges and checked millisecond-to-microsecond conversion for
  pulse on/off/repeat, including a total-duration safety ceiling;
- deterministic event ordering and error handling when several bindings fire
  in one transaction;
- haptic actions in timing-engine §3's exhaustive schema-2 trigger list, with
  `requires-schema-2` behavior and preservation tests.

`click`, `soft`, and `strong` also need exact, provenance-backed mappings and a
default side. §2.3.4 still says Round 6 must confirm side attribution and gain
scaling, and there is no committed Round-6 result. Keep named presets out of
law until that gate is committed; an implementation must not invent their
frames from the labels.

### P1 — Game rumble has no ingress and does not belong in `RawState`

The current virtual-controller abstraction is output-only. Linux creates a
uinput gamepad and only writes events; it does not advertise/read `EV_FF` or
answer upload/erase/play requests. Windows updates a ViGEm target but does not
register a vibration callback. Therefore there is no XInput/force-feedback
value that can currently “enter the mapper.”

It should not enter `RawState` at all: this is feedback from the OS-facing
virtual device to the owning physical-controller session. Add a typed feedback
channel or nonblocking poll from each virtual backend to its matching
controller thread, then apply the effective mode's passthrough/gain policy and
encode `0x80` there. Specify coalescing, left/right motor mapping, gain and
intensity arithmetic, duration/timer handling, and unconditional zero-rumble
on stop, virtual-device replacement, disconnect, PARK, and exit.

On Linux this likely requires replacing or extending `uinput 0.1.3`; the
landed §14.7 audit already records that the crate does not expose the raw fd
needed even for `EV_REP`. That dependency/API decision and Windows callback
parity are separate from controller haptic output. Game-rumble passthrough
must be its own later loop and must not block button-driven haptics.

### P1 — `osc-explore` would lose its daemon-refusal guarantee

The exploration tool currently opens every hidraw node and interprets an open
failure as “the daemon holds it.” Under libusb ownership, interface 2's hidraw
node disappears; the tool can instead see a partial group and fail as “no
activity,” or operate on unrelated remaining nodes. Its existing refusal is
no longer a mutual-exclusion mechanism.

Share the physical discovery and interface-2 claim primitive between daemon
and `explore`. The Triton IMU/rumble paths should use the same interrupt-IN
backend, and a libusb BUSY claim (optionally preceded by the existing daemon
identity probe for better wording) must produce the named refusal. The tool
must never auto-detach or reconfigure an interface owned by the daemon. Keep
the one-physical-device restriction for exploration, but do not copy it into
the multi-controller daemon.

### P2 — Rootless USB access exists in code but is absent from the design contract

The checked-in udev file already has USB-device rules for PIDs `0x1302`–
`0x1304`, not only hidraw rules, and the daemon prompts to install the exact
file. That is the right in-scope mechanism for `/dev/bus/usb` access, so the
daemon should not require root. §2.3.5 must say this explicitly and the
transport loop needs a real non-root hardware acceptance check covering open,
detach, claim, control transfer, interrupt read/write, release, and reattach.

The present `MODE="0666"` grants every local user access to the whole USB
device. Retaining it is the minimal compatibility choice, but it is a security
tradeoff worth an explicit founder call; a group or seat ACL is narrower but
may not fit a persistent user service. Also record `rusb`/libusb packaging and
Windows cross-build behavior: the dependency should be target-gated and must
not silently expand the Windows/macOS support claim.

## Minimal fold list

Before implementation beyond discovery, amend the design with these concrete
contracts:

1. A Linux/PID/interface scope fence and a physical-device discovery plus
   transport boundary; remove `step_by(3)` and interface-count hotplug from
   the ownership model.
2. A USB-aware yield-to-Steam amendment, including usbfs evidence, per-device
   identity, claim/release ordering, partial-acquisition unwind, and all
   disconnect/replacement/exit transitions.
3. A lizard session lifecycle with exact startup order, a monotonic keepalive
   deadline integrated with timing-engine ticks, stop/release behavior, and an
   explicit graceful-versus-crash recovery guarantee.
4. Shared daemon/`osc-explore` acquisition and exclusion, plus the existing
   USB udev rule and non-root acceptance test as stated scope.
5. A schema-2 `HapticEffect` output action and `FeedbackEvent` result using
   existing activator rising-edge law; delete the separate `haptic` and `tick`
   sink concepts. Close every range, default, conversion, and schema/editor
   preservation rule. Commit Round-6 evidence before named presets.
6. A separate virtual-device feedback-ingress design for Linux force feedback
   and Windows ViGEm vibration, including its dependency decision and stop
   semantics.

## Loop split recommendation

Use six independently reviewable loops:

1. **Physical discovery and backend seam** — group by USB parent, fix
   multi-controller/hotplug identity, introduce fakeable HID/USB transport,
   and prove `0x42` input-to-`RawState` parity. No haptic vocabulary.
2. **Triton USB ownership lifecycle** — `rusb`, claim/config/keepalive,
   cleanup/rebind, PARK/reacquire, shared `osc-explore` exclusion, and non-root
   acceptance. No profile changes.
3. **Primitive haptic output** — typed pulse/script commands and Round-6
   hardware attribution/gain evidence, callable by tests or the exploration
   surface only.
4. **Profile vocabulary and runtime feedback events** — schema gate,
   validation, existing activator/pulse composition, preservation tests, and
   daemon dispatch. The editor may display these rows read-only initially.
5. **Editor** — tuning UI and schema-2 upgrade flow, preserving unsupported or
   advanced haptic forms byte-for-byte.
6. **Game rumble passthrough** — virtual force-feedback ingress and `0x80`
   lifecycle, after its platform/dependency decision.

The transport port therefore needs two loops of its own; combining discovery,
ownership/yield, output, schema, and UI would hide the highest-risk lifecycle
changes inside an otherwise unrelated feature diff.

## Required gates

The sandbox gates should use fake transports and pure transition tables for
all claim/config failure points, keepalive deadlines, PARK/reacquire,
disconnect/replacement, two independent controllers, mapper byte parity, and
haptic event traces across every activator sink. Hardware gates are still
required for non-root claim/rebind, forced-exit recovery, Steam handoff, and
Round-6 side/gain/preset attribution; the existing no-hardware CI cannot
establish those facts.
