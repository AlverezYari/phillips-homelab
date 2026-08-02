# SPEC — tycho-client-tailnet: join the tailnet, then dial

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

## Why

The gateway is published **only** on the Tycho fleet tailnet:
`https://tycho-gateway.tail92d9b0.ts.net`. Not on the public internet,
not on any LAN. A client that dials it as an ordinary HTTPS endpoint
resolves nothing — which is exactly what a real member hit:

```
$ ./tycho-client -conf tycho.yaml
tycho-client: couldn't reach http://tycho-gateway.tycho.svc.cluster.local
              — check this computer's internet connection
```

The tailnet path already exists in this repo and enrolment was built
without it. `agent/internal/tailnet` brings the binary up as an
**embedded tsnet node** — no tailscaled, no root — and everything
northbound goes through its dialer. `agent/internal/fieldconf` already
carries an `authkey`. Enrol mode invented a second config format and a
second, non-tailnet path.

**This loop puts enrolment back on the tailnet.** A sibling loop is
building the site half right now against the contract below.

## THE CONTRACT (identical in both specs — do not improvise)

The downloaded `tycho.yaml` gains one field:

```yaml
endpoints:
  - url: https://tycho-gateway.tail92d9b0.ts.net
    setup_code: KX7M-2QN4-8PLD
    tailscale_auth_key: tskey-auth-xxxxxxxxxxxx
    label: Backyard S30
```

All four are **strings**. (A contract that named a field and not its
type is how two green loops shipped a broken flow this week.)

After a successful first run the file is rewritten with the issued
identity and **without** either single-use secret:

```yaml
endpoints:
  - url: https://tycho-gateway.tail92d9b0.ts.net
    scope_id: scp_7f3a91c4
    secret: <base64url>
    label: Backyard S30
```

Mode 0600, written atomically (temp file + rename).

## What to build

### 1. Join the tailnet before anything else

Order matters and is not negotiable: **tsnet up → redeem → device key →
attest → register → stream.** Every one of those needs the gateway, and
the gateway is only reachable through the tailnet.

- Bring the node up from `tailscale_auth_key` using
  `agent/internal/tailnet` — the package that already exists. **Do not
  write a second tailnet implementation.** The whole reason this loop
  exists is that enrolment grew a parallel path.
- tsnet state persists under the buffer directory
  (`fieldboot.TailnetStateDirName` is already the convention), so a
  second run rejoins without a key.
- The auth key is **single-use**. Once the node has joined, remove it
  from `tycho.yaml`. A stale key left in the file is a dead credential
  that will confuse the next run and the next reader.
- Every northbound dial — redeem, device-key, register, heartbeat,
  upload — goes through the tsnet dialer. Assert this; a call that
  accidentally uses the default transport will work on your machine and
  fail on a member's.

### 2. Keep the existing modes working

- **Field mode** (`tycho.conf`, `-scope`, `-key`) is unchanged. The
  headless `tycho-agent` StatefulSet depends on it and is running in
  production right now.
- The two config formats may stay separate **only if** they share one
  tailnet bring-up path. If you can converge them cleanly, do — and if
  you cannot, say precisely why in PR.md. Two formats is tolerable; two
  implementations of joining a tailnet is what caused this.
- `-key` still overrides the served device key. Unrelated to the
  tailnet key — do not conflate them. One authenticates to the *scope*
  over the local network; the other joins *Tycho's* network.

### 3. States a person can act on

Four failures, four different remedies. Do not collapse them:

| state | what the person must do |
|---|---|
| tailnet key rejected/expired | get a new config from the website |
| joined, but gateway unreachable | check internet; the tailnet is up |
| setup code rejected (410) | get a new code |
| credential revoked (403) | the scope was removed from their deck |

"Couldn't reach the service" for a rejected request shipped this week
and had to be fixed. Do not reintroduce it here.

### 4. Secret handling

Neither the tailnet auth key nor the scope secret nor the device interop
key may appear in a log line, an error, a rendered TUI frame, an event,
or a FITS header. `TestEnrolMode_DeviceKeyNeverLeaks` is the pattern —
extend it to cover the tailnet key.

## Tests

- [ ] `tycho-client -conf tycho.yaml` with **no other flags** joins the
  tailnet and proceeds. This is the command the setup screen prints.
- [ ] A second run makes no `/v1/enrol` call and needs no auth key —
  tsnet state is reused.
- [ ] After a successful first run the file has `scope_id` + `secret`
  and **neither** `setup_code` nor `tailscale_auth_key`, at 0600.
- [ ] Northbound requests go through the tsnet dialer, asserted — not
  the process default transport.
- [ ] Each of the four states above produces its own distinct,
  actionable message.
- [ ] No secret in captured output.

`agent/internal/tailnet`'s tests run fully offline (tsnet only dials
lazily). Keep that property — the gate has no network.

## Warts / traps

- Do not modify `DescribeDevice`, the keys allowlist, `agent/internal/
  zwo`, the enrolment protocol, or the device-key endpoint — all shipped
  and verified against real hardware and a live gateway today.
- Do not hardcode the tailnet hostname. It comes from the config.
- Discovery of the scope on the local network is unchanged and stays
  local — the telescope is on the member's LAN, not the tailnet.
- The fleet ACL confines `tag:scope` to the gateway alone. If you find
  yourself needing to reach anything else on the tailnet, stop: that is
  a design change, not an implementation detail.
- `docs/adr/**` is a record, not a scratchpad.

Finish: `/workspace/PR.md` with a transcript of a full first run from
tailnet join through streaming, the config file before and after with
secrets redacted, proof the dialer is tsnet's, and what each of the four
failure states looks like on screen.
