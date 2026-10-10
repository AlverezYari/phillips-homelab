# Wave 3/4 v3 verification

Overall: **NO-GO as a complete wave, with two tracks GO.** The v3 fold
closes the schema, rate-shaping, and diagram-registry findings. The rumble
probe is now honest about unknown hardware effects. Yield and tester still
have lifecycle holes, and `osc-explore` still lacks an implementable exact
interface allowlist.

## Round-2 resolution

| Rank | Round-2 finding | Status | v3 result |
|---|---|---|---|
| P0 | Yield blindness / ownership | **PARTIAL** | The always-on 30 s baseline closes permanent observation blindness, and `HOLDING`/`PARKED`/`ACQUIRING`/`AWAY` separate actual ownership from force policy. The transition table is not total, however: persisted force conflicts with startup and failed-open rows, `AWAY` is incorrectly caught by the force-on `any` row, several entries create an unparameterized `ACQUIRING` state, and the grace period temporarily leaves `PARKED` after evidence is gone. |
| P0 | Snapshot wire contract | **PARTIAL** | `an` now consistently means signed i16, f32 conversion and zeroing exemptions are exact, `seq` is a per-session counter, and `GetControllers` plus the known map covers serial and serial-less discovery. There is no remaining v1 D-Bus signature error. Replacement/restart still has no reliably observable session identity, and the tester selector still ignores `GetControllers`. |
| P1 | Rumble bound honesty / allowlist | **PARTIAL** | The probes are correctly labeled finite, consented, and unverified; Esc is only a future-send abort and latching risk is explicit. The claimed 102 ms worst case combines a period and count that never coexist in the 12-entry corpus, and the alleged VID/PID/interface daemon predicate is not present in the cited code. The arithmetic is P2 polish; the missing exact interface rule gates the harness. |
| P1 | Schema diagnosis | **RESOLVED** | An old reader gives its ordinary unknown-key diagnostic, and an old editor may preserve bytes in memory but cannot Save after canonical validation fails. The seven-key count is also corrected. |
| P1 | Stick-scroll deadzone | **RESOLVED** | Both stick `mouse` and stick `scroll` feed `u × m₁` to their rate mapping outside the deadzone and the zero vector inside it; no position-output step is imported. |
| P1 | Registry gap | **RESOLVED** | `region-select`, `region-menu`, and `region-start` have separate targets. The table accounts for all 22 actual SVG region ids, and generation requires a one-to-one registry/SVG diff. |

## Rewritten-machine hole check

### Yield state/event coverage

The baseline and fast scan cadence is reachable and bounded. `AWAY` re-entry
also explicitly requests a fresh backoff, so stale 30 s retry state does not
survive removal. The row's “pre-open scan applies” needs to be expressed as
an actual branch (`PARKED` on evidence and no force, otherwise initial
acquisition), rather than the unconditional `ACQUIRING` destination shown.

The table is not total over its declared states and events:

| Event class | `HOLDING` | `PARKED` | `ACQUIRING` | `AWAY` |
|---|---|---|---|---|
| scan, evidence present | Defined for force on/off | stay `PARKED` | **Undefined except as a rescan after open failure; that failure row ignores force** | No no-op row |
| scan, no evidence | No explicit stay row | grace then acquire | No explicit stay/retry row | No no-op row |
| open result | Unreachable | Unreachable | Results are present, but EBUSY + evidence incorrectly parks while force is set | Unreachable |
| udev remove | `AWAY` | `AWAY` | `AWAY` | idempotence implicit via `any` |
| udev add | Unreachable/no-op unspecified | Unreachable/no-op unspecified | Unreachable/no-op unspecified | Fresh backoff stated, evidence/force branch ambiguous |
| force on | **Missing flag-only stay row** | acquire | acquire/self-transition | **Incorrectly acquires despite device absence** |
| force off | Defined | Normally unreachable, but unspecified | **Missing normal re-evaluation row** | **Missing flag-only stay row** |
| retry/grace timer expires | Unreachable | **No state/event row for the 2 s grace** | **No explicit retry-attempt row** | Unreachable |

`PARKED`-implies-evidence does hold for the direct force-on row because it
exits `PARKED`, and evidence-free EBUSY now goes to `ACQUIRING(busy)`.
It does not hold through the evidence-gone grace wording: after that scan,
the last evidence is absent while the row says to wait before entering
`ACQUIRING`. Entering `ACQUIRING` immediately with a `not_before` deadline
would preserve the invariant.

There is also no legal reason value for initial, post-grace, post-add, or
force-triggered acquisition: §4.1 declares `ACQUIRING(reason)` with only
`busy` and `error(errno)`, while five rows enter bare `ACQUIRING`. Finally,
the startup evidence row and `ACQUIRING` EBUSY+evidence row need `not force`
guards; persisted force otherwise enters `PARKED` even though force policy
says parking is forbidden. These are implementation-shaping holes, not
cosmetic omissions.

### Snapshot identity and wire law

The v1 signatures are coherent: `a(sbb)` is an array of structs,
`an` is an array of signed 16-bit values, `u` matches the u32 button bitmap,
and `t` carries the u64 counter. Serial-less devices are addressable while
connected and remain known until daemon exit; after restart they correctly
reappear only if connected. Serial identities in `state.toml` remain known
while away, and merely-seen serial identities remain known for the current
run. Those inclusion and expiry rules are total.

Session identity is not total. A replacement and daemon restart reset
`seq` to 1, but “consumers detect restarts by `seq` decreasing” is false
when the last observed value was 1, when a new session advances past the
old value before the next poll, or when replacement happens between polls
without an observed disconnected/invalid snapshot. The same ident can then
produce an apparently monotone `seq` from a different session. A session or
daemon generation in the discovery/snapshot contract, or a stated D-Bus
name-owner reset plus a per-ident replacement generation, is required.

The editor contract at §2.2 also says the selector appears only when
`state.toml` knows more than one serial. That contradicts `GetControllers`
and makes multiple serial-less controllers, or a serial-less controller
beside a serial controller, undiscoverable in the UI. Selector population
and visibility must use the returned known-map entries.

## Remaining findings, ranked

### P0 — Yield is still not an implementable total machine (gates yield)

The force/startup contradiction, `AWAY -> ACQUIRING` force row, missing
acquisition reasons, and unmodeled grace/retry events admit materially
different implementations. Fold the state/event holes listed above and
make every evidence transition conditional on force policy.

### P1 — Snapshot sessions and tester discovery remain ambiguous (gates tester)

An ident is total, but `(ident, seq)` cannot distinguish every replacement
or restart. Add a session generation and drive the controller selector from
`GetControllers`, not `state.toml` serial count.

### P1 — The exact exploration interface allowlist is undefined (gates `osc-explore`)

The design points to a “VID/PID/interface match in
`devices/steam_controller.rs`.” That file defines the Valve VID and three
PIDs, but no interface predicate; Linux connection code in
`devices/mod.rs` positionally takes every third HID entry. Reuse or define
one explicit claim predicate before authorizing raw probe writes. VID/PID
alone does not satisfy the round-2 acceptance condition.

### P2 — Rumble duration prose uses a non-corpus tuple (does not gate)

All three listed `(period, count)` pairs multiply to 51.2 ms under the
SC-2015 interpretation. The stated `0x14 × 0x1400 ≈ 102 ms` pair is not in
the manifest product. Correct the sentence, but the consent text already
makes physical duration and termination unverified, so this is polish
rather than a build-loop hazard.

## Per-track verdicts

| Track | Verdict | Gate rationale |
|---|---|---|
| `osc-explore` | **NO-GO** | Define the exact reusable VID/PID/interface claim predicate. The 51.2 ms prose correction is non-gating. |
| `osc-analog-shaping` | **GO** | Schema behavior, seven-key vocabulary, and stick mouse/scroll deadzone semantics are complete. |
| diagram | **GO** | All 22 landed ids are accounted for and the one-to-one generation gate prevents drift. |
| tester | **NO-GO** | Add observable session identity and populate the selector from `GetControllers`. The v1 D-Bus types themselves are sound. |
| yield | **NO-GO** | Complete the force/evidence/acquisition/grace matrix while preserving `PARKED`-implies-evidence and `AWAY` fresh-backoff behavior. |
