# SPEC — webapp-reenrol-state: the setup screen answers the wrong question

Repo: `loop-bot/tychofleet`. Gate: `make build test lint`.

## The failure

The founder hit **Re-enrol** on a scope with existing history. The
setup screen went straight to *"✓ Found your scope — is this right?
[Yes] [No]"*, never showing the new setup code. Yes and No both landed
him back on the same screen. He could not get through, and had to be
handed a hand-minted config out of band.

`resolveSetupMode` (`src/lib/scope-deck.ts`) is correct given its
inputs:

```ts
if (!scope.enrolled)   return "need-code";
if (!scope.attestedAt) return "waiting-attestation";
return "found-it";
```

The scope was still `enrolled` and still `attestedAt` from its
**previous** enrolment. So the screen is answering *"has this scope ever
attested?"* when the question is *"has it attested for **this**
enrolment?"* — the same shape as every other bug this week: a plausible
value, computed from the wrong generation of data.

A sibling loop (`gateway-reenrol-state`) is adding the missing fact
**right now**.

## THE CONTRACT (identical in both specs — do not improvise)

`GET /v1/scopes` gains one field per scope:

```json
{ "scope_id": "...", "enrolled": true, "attested_at": "...",
  "pending_code": true }
```

`pending_code` is a **boolean** — true when a code exists that is
neither redeemed nor expired. Existing fields keep their names and
types. The gateway will also clear the stale attestation when a code is
redeemed, so `attested_at` goes null for the window between redemption
and the new device attesting.

## What to build

### 1. A pending code outranks historical attestation

Setup mode resolves `pending_code` **first**. If a code is outstanding,
the member is mid-setup and must see the code screen — whatever the
scope attested in a previous life.

Order becomes: pending code → not enrolled → not attested → found it.

Say in PR.md what each of the four resolves to, and make sure the
re-enrol path walks screen 3 → 4 exactly as first-time setup does.

### 2. The deck must not claim a re-enrolling scope is fine

A scope with an outstanding code is not simply `online`. Someone is
part-way through replacing its credential, and the card should say so
and link to setup — the same way `setup-not-finished` does today. A
green `● online` on a scope whose owner is mid-re-enrolment is exactly
the reassuring-but-wrong state this project keeps shipping.

Decide whether that is a new card state or a reuse of
`setup-not-finished`, and justify it in PR.md.

### 3. Do not let the confirm screen loop

Screen 4's **No** revokes and reissues. With this fix that returns the
member to a code screen, as intended. Verify it — a No that lands back
on screen 4 is the bug we are fixing.

## Tests

- [ ] `pending_code: true` on an enrolled, attested scope resolves to
  the **code** screen, not `found-it`. This is the regression, and it
  needs a test that names it.
- [ ] The four resolution cases each have their own test.
- [ ] Screen 4's **No** leads to a code screen, not back to screen 4.
- [ ] The deck card for a scope with a pending code does not read
  `● online`.
- [ ] First-time setup is unchanged — assert it, since this touches the
  shared path.

## Warts / traps

- Do not change enrolment, key minting, the download route or the
  session gate — all shipped and verified.
- The gateway field does not exist yet; build against a typed stub. The
  sibling loop is adding it now.
- A degraded gateway read still renders `--` and an honest error, never
  a fabricated state.
- `docs/design/**` is read-only law.

Finish: `/workspace/PR.md` with an ASCII render of the re-enrol path
screen by screen, the four resolution cases, and your decision on the
deck card state.
