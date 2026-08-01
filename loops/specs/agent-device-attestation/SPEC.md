# SPEC — agent-device-attestation: let a scope say what it is

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Implements **ADR 0008 (scope identity)**, sections 1, 3 and 5. That ADR
may not be in your clone yet — it lands on `docs/adr-scope-identity` in
parallel with this loop. **This SPEC is the authority**; if the ADR is
present and disagrees, follow the SPEC and say so in PR.md.

Sections 2 (refusing a fingerprint mismatch) and 4 (`TELESCOP` audit)
are deliberately **not** in this loop. See "Why recording comes before
enforcing" below — that ordering is a decision, not an oversight, and
you should not implement enforcement even though it will look like the
obvious next line of code.

## The problem

A scope's identity is a string its owner types into an environment
variable, and nothing verifies it:

```go
SourceID: os.Getenv("SOURCE_ID")        // agent/main.go:191
```

Meanwhile `source.model` — a `NOT NULL` column since `0001_init.sql` —
is populated from a hardcoded literal:

```go
uploader.WithAgentInfo(AgentVersion, "seestar", []string{"fetch", "upload"})
//                                    ^^^^^^^^ agent/internal/fieldrun/fieldrun.go:339
```

So every scope in the catalog is model `seestar`, whatever it is, and
the column that should carry typing carries a constant.

The device knows better. `get_device_state` has a wrapper
(`agent/internal/zwo/wrappers.go:60`) that nothing calls. It was run
against the live S30 Pro on 2026-07-31 and it answers everything.

## What the device reports (measured, not assumed)

From the live scope, firmware 8.46:

```
device.sn                  = "5741d34d"
device.cpuId               = "de079cbf89464ff2"
device.product_model       = "Seestar S30 Pro"
device.user_product_model  = "Seestar S30 Pro"
device.firmware_ver_string = "8.46"
device.firmware_ver_int    = 2846
device.ios_ver             = "SEESTAR_v1.08_rv1126b 20260316"
device.focal_len           = 160
device.fnumber             = 5
device.name                = "ASI AIR imager"      <- NOT a model; ignore it
camera        = {pixel_size_um: 2.9, chip_size: [2160,3840], debayer_pattern: "GR"}
second_camera = {pixel_size_um: 1.6, chip_size: [2160,3840], debayer_pattern: "GR"}
focuser        = {max_step: 2600, step: 1242, state: "idle"}
second_focuser = {max_step: 1023, step: 340,  state: "idle"}
```

Two things to notice, because both shape the design:

**`device.sn` is the `TELESCOP` suffix.** Every FITS header carries
`TELESCOP = "S30 Pro_5741d34d"`. The header was never independent
evidence of identity — it is this same serial, laundered through a
capture. That is why identity comes from the device at registration and
not from a frame.

**The device reports two optical trains.** `camera` at 2.9 µm and
`second_camera` at 1.6 µm, with separate focusers — a 27× focal-length
difference on one body. The archive already holds 793 main-train frames
(`WIDECAM=0`) and 5 wide-cam frames (`WIDECAM=1`) under the single
source id `seestar-1`. The wide-cam frames are excluded from combines
today only because they happen to be unsolved; nothing knows they are a
different instrument.

## The security constraint, which is the hard part

The full `get_device_state` response also contains, in the clear:

- `ap.passwd` — the scope's WiFi AP password
- `setting.password` — the device PIN
- `location_lon_lat` — the owner's coordinates to roughly 10 m

**A naive implementation of this SPEC puts a password in the catalog and
a home address one join away from a public website.** That is not a
hypothetical failure mode for this project: a member's email address
reached a public page this month through exactly this shape — a
plausible-looking value nobody audited.

The protocol solves it. `get_device_state` accepts a `keys` argument and
honours it. Verified live:

```
get_device_state {"keys":["device","camera","second_camera"]}
  -> returns exactly those three keys. No ap. No setting. No location.
```

## What to build

### 1. `DescribeDevice` on the agent control API

Add to `tycho.agent.v1.Agent` (`schemas/proto/tycho/agent/v1/agent.proto`,
regenerate — loops have added proto fields here before, see
`bad9bdb`):

- `DeviceDescription`: `make`, `model`, `serial`, `hardware_id`,
  `firmware_version`, `firmware_build`, and a repeated `OpticalTrain`.
- `OpticalTrain`: `id`, `focal_length_mm`, `aperture_f`,
  `pixel_size_um`, `chip_width_px`, `chip_height_px`, `debayer_pattern`.

**The message is vendor-neutral.** Seestar fills it from
`get_device_state`; an INDI or Alpaca driver would fill the same message
from its own properties. Nothing above the agent should be able to tell
which protocol answered. Do not put ZWO-specific field names in the
proto.

Map the two cameras to two `OpticalTrain` entries. `device.focal_len`
and `fnumber` describe the main train. The wide cam's focal length is
**not** in the response — record what is known and leave what is not
unset rather than inventing a number. Say in PR.md what you left unset.

`device.name` is `"ASI AIR imager"`, which is neither the make nor the
model. Do not use it. `product_model` is the model;
`user_product_model` is settable and is not identity.

Capability tier: **`status`**. Reading what a device *is* belongs with
reading what it is *doing*. Do not add a new grant and do not require
`debug` — if learning a model number needed its own grant, owners would
grant `debug` instead, which is the outcome this whole design exists to
prevent.

### 2. The allowlist, and the test that enforces it

The keys requested are a **compile-time constant allowlist**, never a
blocklist over the full response:

```go
{"device", "camera", "second_camera"}
```

A future firmware that adds a new secret-bearing key must be excluded by
construction, not by someone remembering to add it to a deny list.

Required test, and this is the one that matters most in this loop:

- [ ] A fixture of the **full** live response — including realistic
  stand-ins for `ap.passwd`, `setting.password` and `location_lon_lat`
  (invent values; do not use real ones) — fed through the mapping, with
  an assertion that **no value from outside the allowlist appears
  anywhere in the resulting `DeviceDescription`**, serialised. Assert on
  the serialised message, not field by field: field-by-field assertions
  pass while a new field silently carries a secret.
- [ ] An assertion that the request actually sends `keys`. A
  `DescribeDevice` that fetches everything and then filters is a
  regression even if its output looks identical — the secrets would be
  in the agent's memory and in any error log that dumps a response.

No component may persist, log, or transmit a raw `get_device_state`
response. Check the error paths too: a wrapped error that includes the
response body defeats all of the above.

**`location_lon_lat` is not collected by this loop.** It is genuinely
useful and it is the owner's home address. It gets its own consent
surface and precision policy in a later decision; it does not arrive as
a side effect of asking a scope what model it is. Do not add it "since
it's right there".

### 3. Report attestation at registration — record only

`SourceRecord` (`gateway/internal/catalog/catalog.go:43`) and the
`source` table grow the attested fields: `make`, `serial`,
`hardware_id`, `firmware_version`, `attested_at`. The existing `model`
column stops being the literal `"seestar"` and carries
`device.product_model`.

- New columns are **nullable**. Existing rows have no attestation and
  must not break.
- `RegisterSource`'s conflict behaviour is **unchanged in this loop** —
  still upsert. Read the next section before you improve on that.
- An agent that cannot attest — device unreachable, older firmware, a
  driver that exposes no serial — registers **unattested** and is
  recorded as such. It keeps working. Refusing to enrol a scope because
  its firmware is old is a worse failure than recording honestly that we
  do not know what it is.
- Attestation must not block startup. The agent registers with what it
  has; if the scope answers later, the next registration carries it.

Migration numbering: next after the highest in
`gateway/internal/catalog/migrations/`.

## Why recording comes before enforcing

ADR 0008 section 2 says a re-registration whose fingerprint does not
match the recorded one is **refused**, because today's
`ON CONFLICT (id) DO UPDATE` behind a single shared bearer token lets
any agent silently take over any source id.

That is the point of the whole design and it is still not in this loop,
for a concrete reason: **the only real scope in the fleet is already
registered as `seestar-1` with no fingerprint.** Enforcement shipped
today would either refuse the one scope we own or need a special case
carved for it on day one. Fingerprints have to be recorded first, by the
live hardware, before a mismatch means anything.

So: record now, enforce in the next loop once `seestar-1` has attested
at least once. If you implement the refusal anyway you will break the
running deployment, and the gate will not catch it.

## Three states, not a boolean

Every surface that will eventually show a scope has to distinguish:

1. **attested** — the device said what it is
2. **reachable but silent** — a device answered, but not about itself
3. **no device** — nothing there

Today the third impersonates the second. With the scope powered off, the
agent logs `zwo: decoding get_verify_str result: unexpected end of JSON
input` — a *parse* error for a *connectivity* problem, because the proxy
accepts the TCP connection on :4700 whether or not the scope is behind
it. The truth (`Host is unreachable`) is in a different pod's log.

You are not required to fix that here. You **are** required not to
collapse the three states into a boolean in the data you record: an
absent attestation because nothing was there must be distinguishable
from an attestation that failed. Say in PR.md how you represented it.

## Warts / traps

- **Do not re-grant `debug`.** It was granted briefly on 2026-07-31 to
  take the measurements above and withdrawn the same session. The raw
  `Call` passthrough stays withheld. If you find yourself wanting it,
  the answer is a narrower typed RPC.
- Do not change `SOURCE_ID` or how the owner names a scope. The owner
  names the scope; the device says what it is. Both are true.
- The sandbox has no scope. Tests use a fake `zwo` client — follow the
  test doubles already in `agent/internal/zwo`.
- `docs/adr/**` is a record, not a scratchpad: do not edit ADR 0008 to
  match your implementation. If the implementation must diverge, say so
  in PR.md and the ADR gets a status update separately.
- Attestation is **self-reported, not cryptographic**. A modified
  firmware can claim any serial. Do not write a comment, a field name,
  or a PR.md line calling this "verified" or "secure" — it defeats
  accidents and collisions, not a forger. Community firmware is a goal
  of this project, not only a threat.

Finish: `/workspace/PR.md` with the `DeviceDescription` the live
fixture maps to, the exact `keys` list sent, proof that the secret
fields appear nowhere in the output, what you left unset for the wide
cam and why, and how an unattested source is represented distinctly
from a source whose device was absent.
