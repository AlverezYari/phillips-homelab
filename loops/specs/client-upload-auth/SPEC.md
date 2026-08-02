# SPEC — client-upload-auth: the client does not authenticate uploads

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

**URGENT.** This breaks ingest. A senior review found it; it is confirmed
in the code and against the live gateway.

## The failure

The gateway now requires the per-scope secret on every upload endpoint
(ADR 0009 §2, shipped and verified live: an unauthenticated upload start
returns **401**). The client does not send it:

```go
Register      -> c.doAuthed(...)   // sets Authorization: Bearer <secret>
Heartbeat     -> c.doAuthed(...)   // sets Authorization
StartUpload   -> c.do(...)         // NO Authorization        client.go:207
UploadStatus  -> c.do(...)         // NO Authorization        client.go:224
UploadPart    -> hand-built req    // NO Authorization        client.go:233-247
CompleteUpload-> c.do(...)         // NO Authorization        client.go:270
```

`do` (`client.go:278`) sets no auth header; only `doAuthed`
(`client.go:288`) does.

**Consequence: the next frame a scope captures cannot be uploaded.** It
401s, the frame stays in the buffer, and — because `retry.go` treats
401/403 as terminal and the enrol-mode logger is discarded unless
`TYCHO_CLIENT_LOG` is set — the member is told nothing. A night of
photons cannot be recaptured.

This has not bitten yet only because no frames have been captured since
the client took over.

## Why it was invisible

`agent/internal/fakegateway` calls `checkAuth` at exactly two sites —
register (`fakegateway.go:372`) and heartbeat (`:386`). The three upload
handlers (`:402`, `:430`, `:464`) never call it. So client and fake
agree perfectly, and every upload test passes.

Worse, the fake's own comments (`fakegateway.go:50-52`, `:334`) claim
`checkAuth` "authenticates register/heartbeat/**upload** calls against
the per-scope secret ADR 0009 actually issues." **The fake documents a
property it does not have**, which is what stopped anyone checking.

## What to build

### 1. Authenticate every upload call

`StartUpload`, `UploadStatus`, `UploadPart`, `CompleteUpload` all carry
`Authorization: Bearer <per-scope secret>`, exactly as register and
heartbeat do. Prefer routing them through the same helper rather than
adding the header in four places — four call sites is four chances for
the next endpoint to be forgotten.

`UploadPart` builds its request by hand for streaming reasons; keep the
streaming, add the header.

### 2. Make the fake enforce it

`fakegateway` must call `checkAuth` on **all** upload handlers, with the
same scope-binding it already applies to register/heartbeat (secret for
scope A must not authenticate a request for scope B — that logic exists
at `fakegateway.go:288-301`, use it).

Correct the two comments that claim upload calls are already
authenticated. A fake that lies is worse than no fake.

### 3. The test that would have caught it

- [ ] An upload attempted **without** a credential is refused by the
  fake, and the client's own upload path is asserted to send
  `Authorization` on all four calls — assert on the request the fake
  received, not on a mock's return value.
- [ ] A full streaming upload still succeeds end to end with a valid
  credential (the existing streaming tests must keep passing).
- [ ] Scope A's secret cannot upload under scope B's path.
- [ ] A 401 on upload surfaces to the member rather than dying in a
  discarded logger. If that needs plumbing beyond this loop, say so in
  PR.md rather than silently leaving it — the review found the enrol
  mode logger goes to `io.Discard` unless `TYCHO_CLIENT_LOG` is set
  (`main.go:2553-2560`) and `fieldrun.go:413` has no error channel back
  to the TUI.

## Warts / traps

- Do not change the gateway. Its behaviour is correct and verified
  against production; the client is the side that is wrong.
- Do not change enrolment, the tailnet path, `DescribeDevice` or the
  keys allowlist.
- The secret is already on `GatewayClient` (`identityToken`,
  `client.go:64`). No new plumbing needed to obtain it.
- Never log the secret, and do not echo response bodies into errors on
  the authed paths — `devicekey.go:78-80` is the discipline to copy.

Finish: `/workspace/PR.md` showing all four calls carrying the header,
the fake refusing an unauthenticated upload, and what a member now sees
when a credential is rejected mid-upload.
