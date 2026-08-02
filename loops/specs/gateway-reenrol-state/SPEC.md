# SPEC — gateway-reenrol-state: re-enrolment leaves stale identity behind

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

## The failure

The founder hit Re-enrol on a scope, and the setup screen jumped
straight to "✓ Found your scope — is this right? [Yes] [No]" without
ever showing the new setup code. Yes and No both returned him to the
same screen. A loop, with no way through.

The site's mode resolution is correct given what we tell it:

```ts
if (!scope.enrolled)   return "need-code";
if (!scope.attestedAt) return "waiting-attestation";
return "found-it";
```

`seestar-1` was already `enrolled` (a credential from an earlier
enrolment) and already `attestedAt` (from the device that enrolled
then). Minting a new code changes **neither**, so every downstream
consumer keeps reading the previous enrolment's identity as though it
described the current one.

The screen is not wrong about what it sees. It is answering *"has this
scope ever attested?"* when the question is *"has it attested for
**this** enrolment?"*

A sibling loop (`webapp-reenrol-state`) is fixing the site half against
the contract below, **right now**.

## THE CONTRACT (identical in both specs — do not improvise)

`GET /v1/scopes` gains one field per scope:

```json
{ "scope_id": "...", "enrolled": true, "attested_at": "...",
  "pending_code": true }
```

- `pending_code` is a **boolean**. True when an enrolment code exists
  for that scope which is neither redeemed nor expired.
- All existing fields keep their current names and types.

## What to build

### 1. Report whether a code is outstanding

`pending_code` on the scope read. It is the only fact that
distinguishes "this scope is set up" from "someone is in the middle of
setting it up again", and nothing currently exposes it.

### 2. Redemption clears the previous identity

When a code is redeemed for a scope that **already has** an
attestation, that attestation describes a device from a previous
enrolment and is no longer evidence about the current one. Clear it —
`attested_at`, `model`, `make`, `serial`, `firmware_version` — as part
of the same transaction that installs the new credential.

The freshly-enrolled client re-attests within seconds, so the blank
window is brief and honest. The alternative is what shipped: a serial
on the screen that may belong to hardware the member no longer owns.

Do **not** clear it when the code is merely *issued*. ADR 0009 §5 is
explicit that the previous credential is invalidated on **redemption**,
not on generating a code — otherwise generating a code by accident
kills a working scope. Same reasoning applies here.

### 3. Do not break the working path

Re-registration by an already-enrolled, already-attested scope with a
matching credential is untouched: no code involved, nothing cleared.
This only fires on redemption.

## Tests

- [ ] A scope with an unredeemed, unexpired code reports
  `pending_code: true`; one with no code, a redeemed code, or an expired
  code reports `false`. Four cases, not one.
- [ ] Redeeming a code for an attested scope clears `attested_at`,
  `model`, `make`, `serial`, `firmware_version` — asserted from the
  database, not the response.
- [ ] The scope's **sessions, subs and results are untouched** by that
  clearing. This is the test that matters most: `seestar-1` carries 8
  sessions, 798 subs and the M13 masters, and re-enrolment must never
  put a member's history at risk.
- [ ] A normal register/heartbeat by an enrolled scope clears nothing.
- [ ] Postgres-backed tests are **skip-gated** without
  `TYCHO_TEST_DATABASE_URL`, so a green gate does not mean they ran.
  Write them anyway and say so in PR.md.

## Warts / traps

- Do not change enrolment code generation, the upload path, the device
  key endpoint, `DescribeDevice` or the keys allowlist — all shipped and
  verified against real hardware.
- `owner_member_id` and `label` are not identity and are never cleared.
- Migration numbering: next after the highest in
  `gateway/internal/catalog/migrations/`.
- `docs/adr/**` is a record, not a scratchpad.

Finish: `/workspace/PR.md` with the four `pending_code` cases, proof the
history survives a re-enrolment, and the exact column list cleared on
redemption.
