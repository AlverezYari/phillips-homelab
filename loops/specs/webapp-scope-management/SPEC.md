# SPEC — webapp-scope-management: add a scope, manage it, remove it

Repo: `loop-bot/tychofleet`. Gate: `make build test lint`.

The site has **no scope surface at all** today. A member can join
fleets and see attribution, but there is nowhere to add the thing that
produces the data. This loop builds it.

Two sibling loops are building the gateway
(`gateway-scope-credentials`) and the client (`scopetui-enrolment`)
against the same contract **right now**. The contract is law: build to
it even though the endpoints will not exist while you work. Stub the
client, test against the stub.

---

## THE WIRE CONTRACT (identical in all three specs — do not improvise)

The site never touches scope credentials or the catalog's scope tables
directly. It calls the gateway, authenticated with a service token
`TYCHO_GATEWAY_URL` + `SITE_API_TOKEN` (new env, add to the ExternalSecret
pattern this repo already uses):

```
POST   /v1/scopes                            {owner_member_id, label}
                                             -> 201 {scope_id}
GET    /v1/scopes?owner_member_id=...
       -> 200 {scopes:[{scope_id, label, model, make, serial,
                        firmware_version, attested_at,
                        last_heartbeat_at, revoked_at, enrolled}]}
PATCH  /v1/scopes/{scope_id}                 {label}   -> 204
DELETE /v1/scopes/{scope_id}                           -> 204
POST   /v1/scopes/{scope_id}/enrolment-code
       -> 201 {code, expires_at}
```

Setup code format: `XXXX-XXXX-XXXX`, TTL 30 minutes, single use.
Scope ids are server-issued (`scp_7f3a91c4`) — **never let a user type
one**, never show it as something they chose.

The generated `tycho.yaml` the user downloads:

```yaml
endpoints:
  - url: https://gateway.tychofleet.com
    setup_code: KX7M-2QN4-8PLD
    label: Backyard S30
```

---

## The screens

These wireframes are the spec. Build them; deviate only where you can
say why in PR.md.

### 1 · Deck, no scopes

```
┌──────────────────────────────────────────────┐
│  YOUR DECK                                   │
│                                              │
│   You haven't added a scope yet.             │
│   Tycho needs one to start collecting.       │
│                                              │
│            [ Add a scope ]                   │
└──────────────────────────────────────────────┘
```

### 2 · Add a scope

One field. **Do not ask for make, model, or serial** — the scope
reports those itself and typing them is how identity got brittle in the
first place.

```
┌──────────────────────────────────────────────┐
│  ADD A SCOPE                          [ × ]  │
│                                              │
│  What do you want to call it?                │
│  ┌────────────────────────────────────────┐  │
│  │ Backyard S30                           │  │
│  └────────────────────────────────────────┘  │
│  Just a label for you. You can change it.    │
│                                              │
│  Your computer:  ( ) macOS  ( ) Linux        │
│                  ( ) Windows                 │
│                                              │
│               [ Continue ]                   │
└──────────────────────────────────────────────┘
```

### 3 · Setup, live

Code shown as text so it can be typed if the download fails. Countdown
is real. Page polls `GET /v1/scopes` and advances by itself.

```
┌──────────────────────────────────────────────┐
│  SET UP "BACKYARD S30"                       │
│                                              │
│  1  Download scopeTUI                        │
│         [ scopetui-macos-arm64.tar.gz ]      │
│                                              │
│  2  Download your config                     │
│         [ tycho.yaml ]                       │
│     Setup code: KX7M-2QN4-8PLD               │
│     Expires in 29:41. One use only.          │
│                                              │
│  3  Run it next to your scope                │
│     ┌────────────────────────────────────┐   │
│     │ ./scopetui -conf tycho.yaml        │   │
│     └────────────────────────────────────┘   │
│                                              │
│  ◌ Waiting for your scope to check in…       │
│                          [ Generate new code ]│
└──────────────────────────────────────────────┘
```

The download link points at the real release asset for the chosen
platform. If the release for a platform does not exist, say so plainly
rather than serving a 404 — check what
`code.phillips-homelab.net/loop-bot/tycho/releases` actually has.

### 4 · Found it

Everything here comes from the device. Nothing is typed.

```
┌──────────────────────────────────────────────┐
│  ✓ FOUND YOUR SCOPE                          │
│                                              │
│     Seestar S30 Pro                          │
│     Firmware 8.46 · Serial 5741d34d          │
│     Two optical trains                       │
│                                              │
│     Is this right?                           │
│         [ Yes, that's mine ]  [ No ]         │
└──────────────────────────────────────────────┘
```

**No** revokes that credential and issues a fresh code — someone else's
device redeemed it, and leaving it enrolled is the whole problem this
design exists to prevent.

### 5 · Deck, populated

```
┌──────────────────────────────────────────────┐
│  BACKYARD S30            ● online     [···]  │
│  Seestar S30 Pro · fw 8.46 · verified        │
│  Last seen 12s ago                           │
│                                              │
│  Fleets     Fleet Zero, Messier Marathon     │
│  Collected  3h 47m over 3 nights             │
└──────────────────────────────────────────────┘
```

`[···]` → **Rename**, **Re-enrol**, **Remove**.

## The states you must render distinctly

The gateway distinguishes these; so must you. Guessing or collapsing
them is how a member ends up staring at a card that says nothing useful:

| state | card reads |
|---|---|
| created, never enrolled | `setup not finished` + a link back to screen 3 |
| enrolled, never attested | `enrolled — we haven't heard from the device yet` |
| attested, heartbeat recent | `● online`, model and firmware |
| attested, heartbeat stale | `● offline · last seen 4h ago` |
| revoked / removed | not on the deck at all |

A degraded read of the integration figures renders `--`, never `0h 00m`
— this repo has shipped that bug twice and the campaign page already
does it correctly. Match it.

## Rename, re-enrol, remove — build all three properly

- **Rename** is inline, optimistic, `PATCH`. A label is cosmetic and
  carries no authority. Two scopes may share a label.
- **Re-enrol** issues a fresh code and returns to screen 3. This is the
  hardware-swap and reinstall path, and it is the *owner's* action —
  there is no operator involved. Warn plainly: the scope stops
  collecting until the new code is redeemed.
- **Remove** needs a confirmation that says what actually happens:
  the device stops being able to upload, and **the frames it already
  contributed stay** — in the archive, in the fleets, in the masters.
  Do not imply data is deleted. Do not use the word "delete".

## Privacy

A scope's serial, model and firmware belong to its owner's deck. Decide
deliberately what, if anything, appears on public surfaces, and say why
in PR.md. This repo leaked a member's email onto a public page this
month via a plausible fallback nobody audited — do not add a second
one. **Never render an email anywhere a signed-out visitor can reach.**

## Tests

- [ ] A member with no scopes sees screen 1, not an empty table.
- [ ] Each of the five card states above renders its own distinct text —
  a test per state, not one happy-path render.
- [ ] The setup code is never rendered for a scope that is already
  enrolled.
- [ ] Remove asks for confirmation and, on confirm, the scope leaves the
  deck while the member's contributed integration total is **unchanged**.
- [ ] A member cannot see, rename, re-enrol or remove another member's
  scope — assert on the authorization, not just the UI.
- [ ] Gateway unreachable renders a stated error, not a blank panel and
  not zeros.

## Warts / traps

- The gateway endpoints **do not exist yet**. Build against a typed
  client with a stub; the sibling loop is implementing them now.
- PR #35's schema fixture test and PR #36's typed array helper still
  apply to any catalog query you touch.
- `docs/design/**` is read-only law. If a screen there governs the deck,
  it wins over the wireframes above — say so in PR.md.
- Migration numbering: next after the highest in `drizzle/`.

Finish: `/workspace/PR.md` with an **ASCII render of every screen and
every card state as actually built** (not copied from this spec), the
privacy decision, and what a member sees when the gateway is down.
Renders in `/workspace/renders/*.png` if you can produce them — a green
gate cannot see pixels.
