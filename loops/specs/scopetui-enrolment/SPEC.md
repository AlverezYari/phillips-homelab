# SPEC — scopetui-enrolment: download it, run it, find the scope, done

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Implements **ADR 0009** (`docs/adr/0009-scope-credentials.md` — read it
first) on the client side. Two sibling loops are building the gateway
(`gateway-scope-credentials`) and the web UI
(`webapp-scope-management`) against the same contract **right now**.
The contract below is law.

**Stay out of `gateway/`.** The sibling loop owns that tree.

---

## THE WIRE CONTRACT (identical in all three specs — do not improvise)

Scope ids are **server-issued**, opaque: `scp_` + 8 lowercase hex.
Owners never type one.

Setup code: 12 chars from `23456789ABCDEFGHJKMNPQRSTUVWXYZ` (no
`0/O/1/I/L`), formatted `XXXX-XXXX-XXXX`, TTL 30 minutes, single use.

Scope secret: 32 random bytes, base64url, unpadded — issued once at
redemption.

```
POST /v1/enrol   {code}   -> 200 {scope_id, secret}
                          -> 410 expired / already redeemed / unknown
```

Then everything else carries `Authorization: Bearer <scope secret>`:

```
POST /v1/sources/{scope_id}/register     (existing shape + attestation)
POST /v1/sources/{scope_id}/heartbeat
PUT  /v1/uploads/...
```

Downloaded `tycho.yaml`:

```yaml
endpoints:
  - url: https://gateway.tychofleet.com
    setup_code: KX7M-2QN4-8PLD
    label: Backyard S30
```

After redemption scopeTUI **rewrites the file in place**, replacing
`setup_code` with the issued identity:

```yaml
endpoints:
  - url: https://gateway.tychofleet.com
    scope_id: scp_7f3a91c4
    secret: <base64url>
    label: Backyard S30
```

File mode **0600**. The secret is never logged, never rendered in the
TUI, never in an event or a FITS header.

`SOURCE_ID` and `SOURCE_AUTH_TOKEN` are retired as client config.

---

## The user this is for

Someone who has never used Tycho, has a Seestar on their home WiFi, and
has just downloaded a binary and a config file from a website. They do
not know their scope's IP address. They may not know what an IP address
is. They are standing outside in the dark.

Everything below follows from that.

## What to build

### 1. `scopetui -conf tycho.yaml` handles the whole first run

Today `-conf` is field mode and expects a fully-formed config with a
static `SCOPE_HOST`. Now it must:

1. Read `tycho.yaml`. If the endpoint has a `setup_code`, redeem it.
2. Persist the issued `scope_id` + `secret` back into the file, 0600.
3. Find the scope on the local network (section 2).
4. Attest it (`DescribeDevice` already exists — do not modify it).
5. Register, heartbeat, and stream, authenticated with the secret.

A second run finds `scope_id`/`secret` already present and skips
straight to step 3. **Re-running must never re-redeem** — the code is
gone, and a stale `setup_code` left in the file after a successful
redemption is a bug that will strand people.

If redemption returns 410, say so in words a beginner can act on: the
code has expired or already been used, generate a new one from the
website. Do not print the status code alone.

### 2. Find the scope — no IP address typed by a human

This is the worst step in the flow today and it is the reason this loop
exists. `agent/internal/discovery` is static-IP only (`agent/main.go:56`
says so). Build discovery:

- Probe the local subnet(s) for a reachable ZWO control socket on TCP
  **4700**, concurrently and with a short per-host timeout. Bound it —
  scanning a /16 sequentially is not acceptable.
- A host that accepts on 4700 **is not proof** it is a Seestar. Confirm
  by completing the handshake and asking the device what it is
  (`DescribeDevice`) before offering it.
- More than one found: list them with make/model/serial and let the
  person pick. Do not silently take the first.
- None found: fall back to prompting for an address, with a message
  that says what to check — scope powered on, on the same WiFi as this
  computer, not still in its own hotspot mode.
- An explicit address in the config or on the flag skips discovery
  entirely.

Say in PR.md how long a scan takes on a /24 and what it does on a
machine with several interfaces (VPN, docker bridges, tailscale).

### 3. Show state a person can act on

The TUI should make these distinguishable at a glance, because they
have completely different remedies:

| state | what the person does |
|---|---|
| endpoint unreachable | check internet |
| code rejected | get a new code from the site |
| no scope found | check the scope is on and on this WiFi |
| scope found, not answering identity | probably fine, keep going |
| running | nothing |

Note that "no device" currently masquerades as a parse error — with the
scope off, the agent logs `zwo: decoding get_verify_str result:
unexpected end of JSON input`, a decode failure for a connectivity
problem. Do not surface that string to a human. Classify it.

### 4. Failure handling that does not strand anyone

- Losing the endpoint mid-session must not lose frames: the buffer and
  retry behaviour that exists today keeps working, unchanged.
- A **revoked** credential (the owner removed the scope from their deck)
  gets 401/403 from the gateway. Stop cleanly, say why in one plain
  sentence, do not hot-loop, do not delete the buffer.
- A corrupt or partially-written `tycho.yaml` must not brick the next
  run. Write it atomically (temp file + rename), not in place.
- Never print the secret, even at debug level, even in a "here's your
  config" summary.

## Tests

- [ ] Redemption happens exactly once: a second run with a persisted
  credential makes no `/v1/enrol` call.
- [ ] After redemption the file contains `scope_id` + `secret` and **no
  `setup_code`**, at mode 0600.
- [ ] A 410 from `/v1/enrol` produces an actionable message, not a
  status code.
- [ ] Discovery finds a simulated scope on a loopback listener,
  rejects a port-4700 listener that is not a scope, and terminates
  within its bound when nothing is there.
- [ ] The secret appears in no log line and no rendered TUI frame —
  assert against captured output, the way the attestation loop asserted
  against a serialised message.
- [ ] A 403 from a revoked credential stops cleanly without a retry
  storm.

`dummyscope` exists (`docs/dev/simulation.md`) — use it rather than
inventing a second fake.

## Warts / traps

- Do not touch `gateway/` — the sibling loop is editing it now.
- Do not modify `DescribeDevice`, the keys allowlist, or
  `agent/internal/zwo`'s attestation path: shipped and working against
  real hardware last night.
- The scope's ZWO RSA key (`see_start_pem`, `KEY_PATH`) is unrelated to
  any of this and unchanged — it authenticates to the *device*, not to
  Tycho. Do not conflate them.
- Windows is a supported target (`loops/bin/release-build.sh` cross-
  builds it). File modes and network scanning both behave differently
  there — say in PR.md what you did about it.
- `docs/adr/**` is a record, not a scratchpad.

Finish: `/workspace/PR.md` with a transcript of a full first run
(discovery through streaming), the file before and after redemption
with the secret redacted, scan timings, and what each of the five
states above looks like on screen.
