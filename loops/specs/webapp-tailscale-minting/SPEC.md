# SPEC — webapp-tailscale-minting: hand each scope a key to the fleet tailnet

Repo: `loop-bot/tychofleet`. Gate: `make build test lint`.

## Why

A member's telescope reaches the gateway **over the fleet tailnet** —
that is the whole transport. The gateway is published there and nowhere
else: `https://tycho-gateway.tail92d9b0.ts.net`, unreachable from the
public internet or any LAN.

So the client needs a way onto that tailnet, and it must arrive with the
config the member downloads. A sibling loop (`tycho-client-tailnet`) is
building the client half **right now** against the contract below.

## THE CONTRACT (identical in both specs — do not improvise)

The downloaded `tycho.yaml` gains one field:

```yaml
endpoints:
  - url: https://tycho-gateway.tail92d9b0.ts.net
    setup_code: KX7M-2QN4-8PLD
    tailscale_auth_key: tskey-auth-xxxxxxxxxxxx
    label: Backyard S30
```

- `tailscale_auth_key` is a **string**, always the raw key.
- All four fields are strings. (A field named without its type is how a
  green site and a green gateway shipped a broken flow this week —
  `owner_member_id` went out as a JSON number against a Go `string`.)
- The client consumes the key on first join and rewrites the file
  without it. Nothing reads it back.

## Note on the base you cloned

An earlier version of this loop was respawned because it had cloned a
`main` that predated the `TYCHO_GATEWAY_PUBLIC_URL` split (tychofleet
#48). That work is now on `main`: the member-facing gateway address
comes from `TYCHO_GATEWAY_PUBLIC_URL`, distinct from the in-cluster
`TYCHO_GATEWAY_URL` the site uses server-side, and a missing public URL
means **no config is served at all** rather than a broken one.

Build on that rather than around it — `src/lib/gateway/client.ts` and
`src/pages/api/scopes/[scopeId]/tycho-yaml.ts` already have the shape.
The auth key follows the same rule: no key, no config.

## What to build

### 1. Mint a key when the setup code is minted

The existing enrolment-code call already happens when a member reaches
the setup screen. Mint the tailnet key in the same step, so the
downloaded config is complete or is not offered at all.

Key properties, all required:

- **Pre-authorized** — a member must not need an admin to approve their
  scope.
- **Ephemeral: no.** The node persists; the key is single-use.
- **Reusable: no.** One key, one scope.
- **Tagged `tag:scope`** — this is what the fleet ACL confines to the
  gateway and nothing else. A key minted without the tag lands a
  telescope on the tailnet with no restrictions.
- **Expiry ~7 days.** It is a setup key, not a credential.

Credentials: a Tailscale **OAuth client scoped to `auth_keys` only**,
carrying `tag:scope-minter`. New env, wired from 1Password like every
other secret in this repo:

```
TS_MINTER_CLIENT_ID
TS_MINTER_CLIENT_SECRET
TS_TAILNET          # "-" resolves to the OAuth client's own tailnet
```

The client is deliberately **not** permitted to touch devices. Do not
add scopes, and do not reuse the operator's client.

### 2. Throttle, and handle 429 properly

Minting is a write against someone else's API on a member-triggered
path.

- Per-member rate limit using the repo's existing rate-limit helper.
  Say in PR.md what limit you chose and why.
- A 429 from Tailscale is retried with backoff, and if it persists the
  member sees an honest "try again in a moment", not a broken config.
- Every other failure is **rejected**, not "unreachable" — that
  distinction shipped this week and must not regress.

### 3. Never serve a config that cannot work

If minting fails, **do not fall back to a `tycho.yaml` without a key**.
A member who receives one will get a client that cannot reach anything,
and will have no way to tell why. The screen says setup is temporarily
unavailable and the server logs the reason.

Same rule already applies to `TYCHO_GATEWAY_PUBLIC_URL` — no key, no
config; no public URL, no config.

### 4. Secret handling

The key is a credential. It appears in the downloaded file and nowhere
else: not in a log line, not in an error, not in the session, not in the
site's database. Assert this the way the client asserted the device key
never reaches disk.

Regenerating a setup code mints a **fresh** key. Say in PR.md whether
you can revoke the previous one through the API and, if not, why the
7-day expiry is an acceptable bound.

## Tests

- [ ] A generated `tycho.yaml` contains a `tailscale_auth_key` string,
  asserted against the file's contents.
- [ ] The mint request asks for tag `tag:scope`, pre-authorized,
  non-reusable, non-ephemeral — assert on the request body sent to
  Tailscale, not on a mock's return value. A stub that accepts anything
  is how the last contract bug reached production.
- [ ] Minting failure serves **no** config and an honest message.
- [ ] A 429 is retried and then surfaces as retryable, distinct from a
  rejection.
- [ ] The key appears in no log line and no rendered page.
- [ ] Regenerating a code mints a new key rather than reusing one.

## Warts / traps

- Do not change the enrolment protocol, scope API, download route or
  session gate — all shipped and verified against the live gateway.
- `TYCHO_GATEWAY_PUBLIC_URL` is set by the deployment; do not hardcode
  the tailnet hostname anywhere in this repo.
- The gateway is **not** reachable from the site's pod over the tailnet
  and does not need to be — the site talks to it in-cluster over
  `TYCHO_GATEWAY_URL`. Only the member's client uses the tailnet.
- `docs/design/**` is read-only law.

Finish: `/workspace/PR.md` with a generated `tycho.yaml` (key redacted),
the exact request body sent to Tailscale, your rate limit and why, what
a member sees when minting fails, and the revoke-vs-expiry answer.
