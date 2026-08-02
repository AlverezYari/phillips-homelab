# SPEC — webapp-fail-closed: a fake that looks real, and a timeout that lies

Repo: `loop-bot/tychofleet`. Gate: `make build test lint`.

Two defects found by a senior review, both confirmed. They are unrelated
in code and identical in shape: **something reports success while doing
the wrong thing, and a comment says it is fine.**

## 1. Production mints fake Tailscale keys

`src/lib/provision/index.ts:10`

```ts
const kind = process.env.PROVISIONER ?? "fake";
```

`PROVISIONER` is **unset in the live deployment** (verified in the
running pod) and appears in no gitops manifest. So `getProvisioner()`
returns `FakeProvisioner`, whose `mintAuthKey` returns
`tskey-fake-000001` (`src/lib/provision/fake.ts:19`).

The admin approve flow then stores it (`api/admin/approve.ts:82`),
emails a working-looking invite (`:109`), and the member downloads a
`tycho.conf` containing it (`src/lib/tycho-conf-delivery.ts:34`).
Every screen reports success. The member's agent silently never joins
the tailnet. `src/lib/remint.ts:22` has the same exposure.

This contradicts the codebase's own posture everywhere else: the
gateway, tsmint, garage and catalog clients all fail **closed** to an
honest `not-wired`. This one fails **open**, to a fake that looks real.

**Fix:** no default. An unset `PROVISIONER` in a non-test environment is
a configuration error and must fail loudly — at startup if you can
reach it, otherwise on first use, with a message naming the variable.
Selecting the fake must be explicit and impossible to do by omission.

Keep the fake available for tests, and give it a failure mode: it
currently never throws (`fake.ts:16-24`), so every caller's error path
— including `approve.ts:54-56` — has never been exercised.

## 2. The 3-second abort truncates every large download

`src/lib/garage/client.ts:83,150,244` pass
`AbortSignal.timeout(CONNECT_TIMEOUT_MS)` with `CONNECT_TIMEOUT_MS =
3000`. The comment at `:77-83` asserts:

> *"the response is piped through, never buffered, so this timeout only
> guards 'Garage never answered at all'."*

**That is false**, and was demonstrated empirically on this project's
Node version: the signal stays attached to the response body, and
firing it after headers arrive destroys the stream mid-transfer.

Because `fleet/[slug]/master-download.fit.ts:57` and
`api/tycho-client/[platform].ts:50` pipe the stream straight to the
client, client backpressure propagates upstream. An 88 MB FITS on a
10 Mbps link needs ~70 s; the signal fires at 3. `content-length` has
already been sent, so the browser reports a failed download.

**Anyone not on a very fast link cannot complete either download
today** — including the `tycho-client` binary a new member must have to
set up at all.

**Fix:** the timeout must bound *establishing* the response, not
consuming it. Once headers are in hand, the body must stream without a
deadline it cannot meet. Delete the comment that says otherwise — it is
what stopped this being noticed.

Say in PR.md how you bounded a connection that stalls *after* headers,
if you did; "no timeout at all on the body" is an acceptable answer for
now if you say so explicitly rather than leaving it implied.

## Tests

- [ ] An unset `PROVISIONER` fails loudly outside tests. Assert the
  error names the variable — someone hitting this at 2am needs to know
  what to set.
- [ ] Explicitly selecting the fake still works, and the fake can be
  made to fail so `approve.ts`'s error path is exercised at least once.
- [ ] A body that takes **longer than the connect timeout to stream**
  completes intact. This is the regression, and it needs a test that
  names it: serve a slow body from a local server, read it fully,
  assert the bytes are complete rather than truncated.
- [ ] A genuinely unreachable Garage still fails fast, so the fix does
  not simply remove the protection.

## Warts / traps

- Do not change the enrolment flow, scope API, session gate or
  authorization — all shipped and verified.
- Do not "fix" the download by buffering. The 88 MB FITS and the 20 MB
  client must stay streamed.
- `tsmint` (the new enrolment path) does **not** use the provisioner and
  is unaffected — do not refactor it into this.
- `docs/design/**` is read-only law.

Finish: `/workspace/PR.md` with the startup failure a missing
`PROVISIONER` now produces, proof a slow large body streams intact, and
what still bounds a connection that stalls after headers.
