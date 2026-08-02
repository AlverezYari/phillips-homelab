# SPEC — device-key-provisioning: serve the interop key, don't ship it

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Read `docs/adr/0009-scope-credentials.md` first — this extends it.

## The failure, which stops onboarding dead

The founder ran the exact command the site tells every new member to
type:

```
$ ./tycho-client -conf tycho.yaml
usage: tycho-client -conf tycho.yaml -key key.pem [-scope host:port]
```

Two problems, both in the way of a working first run.

**1. `-conf` is not sufficient.** Enrol mode still requires `-key` on
the command line (`agent/cmd/tycho-client/main.go`, the
`enrolMode && *keyPath == ""` case), so the client exits on argument
validation before it ever looks for a scope.

**2. The user has no key to give it.** `-key` is the **shared fleet
interop RSA private key** — what the Seestar's `get_verify_str`
challenge-response requires (`agent/internal/zwo/auth.go`,
`docs/seestar-fleet-context.md` §1). It is deliberately absent from
this repo. A member who signed up an hour ago has no way to obtain it,
so even with the flag fixed, the handshake would fail.

## The decision

**The gateway serves the interop key to an authenticated scope. The
client holds it in memory only and never writes it to disk.**

The client authenticates to Tycho *before* it needs to reach the
hardware — it redeems its setup code, gets its per-scope credential,
and only then wants to talk to the scope. That ordering is what makes
this possible.

Why served rather than shipped, so nobody undoes it later: bundling the
key would put it in a published artifact, unrotatable without a
release, identical for everyone, forever. Serving it means it is in
exactly one durable place, is provisioned to identified members rather
than published, is revocable per scope, and — the part that actually
matters operationally — **can be rotated centrally the day ZWO changes
it in firmware, with no client release at all.**

Be honest in comments and PR.md about the limit: anyone who signs up can
obtain it. This is access-controlled provisioning, not secrecy. Do not
write anything claiming the key is protected or secret.

### Gateway

```
GET /v1/device-key
  Authorization: Bearer <scope secret>
  -> 200 {"key_pem": "...", "key_id": "..."}
  -> 403 if the scope's credential is revoked
```

- Authenticated with the **per-scope secret**, exactly like register and
  heartbeat. Reuse that middleware; do not invent a second auth path.
- **A revoked scope is refused.** Removing a scope from a deck must
  actually cut off device access, not merely stop uploads.
- The key comes from configuration (`DEVICE_INTEROP_KEY_PEM`, a new
  required env var fed from the existing secret — the deployment
  already mounts this key material for the agent as `see_start_pem`).
  Follow the precedent already in `gateway/main.go`: fail to start if it
  is missing, and fail to start if it collides with another token.
- Accept an optional `firmware` query parameter and **ignore it for
  now**, returning the single configured key. Record in PR.md that this
  is the seam for serving different material per firmware when ZWO
  rotates it. Do not build multi-key selection this loop.
- The key must never appear in a log line, an error, an event, or a
  metric. Check your error wrapping — this is the same discipline the
  attestation loop applied to `get_device_state`.

### Client

- Enrol mode (`-conf tycho.yaml`) **requires no other flags.** That is
  the headline: the command on the setup screen must work as written.
- After redeeming (or loading a persisted credential), fetch the key
  from the gateway and keep it **in memory only**. Never write it to
  `tycho.yaml`, never to a temp file, never to the buffer directory.
  Refetch on every start.
- `-key` remains an **override** for the field and direct modes that
  legitimately take a local PEM. Passing `-key` in enrol mode uses the
  local file instead of fetching — useful for offline work and for the
  headless deployment, which supplies its own.
- A 403 (revoked) stops cleanly with a plain sentence pointing at the
  owner's deck. Do not hot-loop, do not delete the buffer.
- If the fetch fails transiently, that is "couldn't reach the service" —
  distinct from "rejected". This repo shipped that exact conflation on
  the site today; do not repeat it here.

## Tests

- [ ] `tycho-client -conf tycho.yaml` with **no other flags** proceeds
  past argument validation. This is the regression that sent a real
  user to a usage string; it needs a test naming that.
- [ ] The fetched key never reaches disk — assert against the config
  file's contents after a run, and against the buffer directory.
- [ ] The key appears in no log line and no rendered TUI frame — assert
  against captured output, the way the attestation loop asserted against
  a serialised message.
- [ ] A revoked scope's credential gets 403 from `/v1/device-key`.
- [ ] An unauthenticated request to `/v1/device-key` gets 401.
- [ ] `-key` still overrides in enrol mode, and field/direct modes are
  unchanged.

## Warts / traps

- Do not put the key in `tycho.yaml`, in the repo, in a test fixture, or
  in a release artifact. If you need one in a test, generate a throwaway
  RSA key at test time.
- Do not change enrolment, the setup code, the scope API, the upload
  auth or `DescribeDevice` — all shipped today and verified against a
  live gateway and real hardware.
- The headless `tycho-agent` StatefulSet mounts its own key at
  `KEY_PATH` and must keep working untouched. It is not an enrol-mode
  client.
- `docs/adr/**` is a record. If this warrants an ADR amendment, say so
  in PR.md rather than editing 0009.

Finish: `/workspace/PR.md` with a transcript of `tycho-client -conf
tycho.yaml` running with no other flags, proof the key is absent from
the config file and every log line afterwards, the revoked-scope
behaviour, and a note on the firmware-rotation seam.
