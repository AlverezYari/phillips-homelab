# Wave 3/4 v2 verification

Overall: **NO-GO as written.** The two non-authorizing fences are now
sound, and the position-class shaping vectors are correct, but each
nominally buildable track still has at least one contract hole.

## Round-1 resolution

### Motion and feedback

| # | Round-1 finding | Status | v2 result |
|---|---|---|---|
| 1 | Schema contradiction | **PARTIAL** | Same-commit amendment is coherent, and an older schema-2 reader rejecting a shaping key as unknown agrees with existing law. It cannot, however, diagnose every unknown key as `daemon too old for <key>`; config-profiles §3 still classifies unknown keys at any depth as typo-safety errors. The old-editor preservation claim is also incomplete: its canonical parse rejects the key and errors block Save. |
| 2 | Rumble safety honesty | **PARTIAL** | Esc is now honestly only a future-send abort, and consent/pacing/session caps are real. “Self-terminate” and the physical-duration bound still interpret an unmeasured protocol, contradicting the claimed protocol independence. |
| 3 | Capture provenance | **RESOLVED** | Versioned raw-first JSONL records complete reports, exact sends/results, prompt windows, device/descriptor identity, and git revision; later normative constants must cite committed captures. |
| 4 | Shaping totality | **PARTIAL** | The position-class transform is ordered and total, including zero and diagonal corners. But `deadzone` is admitted for stick `scroll` (§3.1) while rate-class law applies steps 1–2 only to stick `mouse` (§3.2), leaving a valid setting without semantics. |
| 5 | Gyro/haptics destination fencing | **RESOLVED** | §4 says no implementation may be derived from it, requires a new reviewed amendment, and enumerates the missing ownership/lifecycle decisions. It is a watertight non-authorizing fence. |

### Overlay and services

| # | Round-1 finding | Status | v2 result |
|---|---|---|---|
| 1 | Radial-menu legality | **RESOLVED** | §3 authorizes no loop and requires the future document to amend both closed schema law and BindingPath grammar in the same commit. |
| 2 | Yield lifecycle | **PARTIAL** | Evidence, grace, capped retry, restart, disconnect, and independent-controller rows are much better, but observation can go permanently idle and failed acquisition does not fit the three declared states. |
| 3 | Snapshot contract | **PARTIAL** | Pull cadence and the valid/connected distinction are specified, but the wire type contradicts the described axes and controller identity/lifecycle is not total. |
| 4 | Radial state machines | **RESOLVED** | The document no longer supplies incomplete executable semantics; it makes complete gesture/ownership/IPC state machines a prerequisite in `radial-menus.md`. |
| 5 | Hit-map semantics | **PARTIAL** | Format, transforms, collision priority, closed targets, and keyboard access are defined. The registry does not match the landed SVG. |
| 6 | Editor preservation | **RESOLVED** | Radial menus are fenced, and the future law must cover preservation/upgrade for their ordered nested bindings before authorization. |

## New/current findings, ranked

### P0 — Yield can become permanently blind and its state invariant can lie

The 5 s scan exists only while a `steam` process is already known to
exist (§4.1). After a scan observes no Steam process and disarms that
timer, a later Steam launch is not guaranteed to produce FocusChanged or
a udev event; opening an existing hidraw node produces no udev add/remove.
The daemon may therefore stay `HOLDING` forever without observing new
evidence.

The state table also has no ownership state for startup EBUSY/no evidence
and no defined result for a failed FORCE_HOLD acquisition. It enters
`FORCE_HOLD` before open succeeds; toggling off can then select `HOLDING`
despite owning no handle. Similarly, PARKED + evidence gone + EBUSY stays
`PARKED`, even though PARKED is defined to mean Steam has the device.
Non-EBUSY open failures and disconnect/reconnect while FORCE_HOLD are
absent. Finally, startup `open ok` wins even if the pre-open scan found
authoritative Steam evidence.

Minimal fold: add a reliable Steam-process-start observation (or a low-rate
baseline scan that never fully disarms); model desired force policy
separately from actual handle ownership with explicit acquiring/busy/away
states; specify every open error, retry timer, disconnect, and toggle row;
never label evidence-free contention PARKED; make startup evidence win
before opening.

### P0 — `GetInputSnapshot` is not a coherent or total wire contract

`an` is an array of signed 16-bit integers, not “i32-widened i16”; the
latter requires `ai`. The landed parser's `RawState` axes are normalized
`f32`, so “raw” also needs an exact source/conversion rule. `t` is the
right D-Bus type for a non-negative `u64` monotonic timestamp (`x` would
be signed), but CLOCK_MONOTONIC does not reset on daemon restart as the
text claims. If reset-per-run is required, `seq` must instead be a
per-run counter or relative epoch.

The zeroing rules say “all other fields,” which would zero `version` and,
for `valid=false`, potentially `connected`; those fields must be excluded
explicitly. A required string serial cannot address controllers that
report no serial, even though existing law supports them. Nor does current
`state.toml` remember every merely-seen serial, so a disconnected device
can become UnknownController after restart, and the editor has no total
controller-discovery contract. These gaps cover no-report-yet,
disconnect, replacement, and daemon restart; resetting the slot on
replacement alone is sound.

Minimal fold: choose `an` + signed-i16 wording or `ai` + widening; pin the
raw-value source; retain `version=1` and `connected` while zeroing payload;
define timestamp/counter restart behavior; add discovery and an address
for serial-less devices; define when seen serials enter/leave the known
map across disconnect and restart.

### P1 — The rumble corpus is finite, but its safety bound is not

The product is indeed `2 × 2 × 3 = 12` candidate sends. Under the text's
own `period_µs × count` names, all three tuples imply 51.2 ms, not
approximately 100 ms. More importantly, Triton is explicitly allowed to
interpret the same bytes differently, so neither the count byte nor a
self-terminating effect is known before discovery. A rule saying future
exact byte strings “MUST self-terminate” is not mechanically checkable
without a known protocol. The VID-only allowlist also permits unrelated
Valve HID devices rather than the project's known controller PIDs and
interfaces.

Minimal fold: describe the 12 entries as finite, consented, unverified
SC-2015-derived probes; remove the protocol-independent termination claim
and make the residual hardware risk explicit; correct or justify the
duration calculation from measured semantics; restrict opening by the
known VID/PID/interface allowlist.

### P1 — Schema rejection is consistent; the promised diagnosis is not

Appending shaping keys to timing-engine §3 and config-profiles §3 in the
implementation commit is a valid law amendment. Before that amendment,
an older schema-2 daemon must apply the existing “unknown key, any nesting
depth” rule. It cannot distinguish a future shaping key from a typo, so
`daemon too old for <key>` is unsupported versioning-by-error. Likewise,
an older editor may preserve the bytes internally, but its canonical
validation rejects them and blocks Save; §3.3 overstates usable
preservation.

Minimal fold: keep the ordinary unknown-key diagnostic (or introduce an
explicit feature/schema version that makes “too old” knowable), and state
that older editors preserve unsupported bytes but cannot save the
otherwise-invalid document unless a defined raw/compatibility path is
added.

### P1 — One admitted shaping combination has no transform

`deadzone` admits stick `scroll`, but the rate-class clause applies the
radial deadzone only to stick `mouse`. It also refers to “steps 1–2,” whose
inside-deadzone branch says “skip to 6,” a position-output step that a
rate behavior does not have.

Minimal fold: define the shaped vector handed to each stick mouse/scroll
rate mapping, including the zero result inside the deadzone and `u × m₁`
outside it. The heading also says six keys while the table contains seven.

### P1 — The semantic registry misses a landed region

The SVG contains separate `region-select`, `region-menu`, and
`region-start` ids. §1.2 names only `region-select/start`; its parenthetical
“view/menu” does not assign a target to the actual `region-menu` id.
Everything else in the asset's 22-region id set is covered by the table's
explicit ids/patterns.

Minimal fold: add `region-menu → button:menu` and spell the three center
ids as separate registry rows (or explicitly patch and account for every
removed/renamed id).

## Buildable-track gates

| Track | Verdict | Minimal fold before build |
|---|---|---|
| `osc-explore` | **NO-GO** | Make the probe risk honest and the device allowlist exact; remove the unmeasured self-termination guarantee and fix/justify duration. |
| `osc-analog-shaping` | **NO-GO** | Resolve old-reader diagnostics/preservation and define stick-scroll deadzone output; fix the seven-key count. The golden rows need no numeric changes. |
| diagram | **NO-GO** | Add an exact `region-menu` registry entry and gate a one-to-one diff of all landed `region-*` ids against generated entries. |
| tester | **NO-GO** | Correct the D-Bus axes type, raw conversion, zeroing, clock semantics, discovery, serial-less identity, and lifecycle map. |
| yield | **NO-GO** | Add non-idling process-start observation and a total ownership/acquisition state machine, especially failed FORCE_HOLD acquisition. |

## Numeric and fence checks

- Position shaping recomputes correctly: `19660.2 → 19660`,
  `26213.6 → 26214`, and `(2/9) × 32767 = 7281.555… → 7282` under
  half-away-from-zero. The custom interpolation is
  `0.25 + ((0.6-0.5)/(0.75-0.5)) × (0.75-0.25) = 0.45`.
- The zero vector takes the `m ≤ deadzone` branch before `n/m`; all
  `|n| > 1` corners retain `u = n/|n|` and clamp only magnitude, so the
  position pipeline is total. Strictly increasing `in`, non-decreasing
  bounded `out`, and endpoints `(0,0)`/`(1,1)` make the PWL law continuous,
  total on `[0,1]`, and onto `[0,1]`.
- Overlay §3 and motion §4 are now watertight non-authorizing fences.
  Their architecture sketches cannot authorize schema, ownership, IPC,
  gyro, or haptic implementation without the expressly required new law
  and review.
