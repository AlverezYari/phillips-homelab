# SPEC — delivery-guard-enforcement: make G1 and G2 compile-time guarantees

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Closes issue **#167**. Small, surgical, and worth doing now while there
is exactly one (fake) adapter.

Read `docs/design/crowdsky-delivery-guards.md` (G1, G2, G8) and ADR
0010 §9 first.

## The problem

`operator/internal/delivery` gets the ordering right:

```go
func Send(ctx context.Context, ledger Ledger, sender Sender, file FileToSend) error {
    if ledger.Acknowledged(key) { return nil }
    if err := sender.SendFile(ctx, file); err != nil { return err }
    return ledger.RecordAck(ctx, key, file.Bytes)
}
```

`SendFile` has exactly one non-test caller, and `deliveryjob/driver.go`
routes through `Send`/`Commit`. **Correct today.**

But `Adapter` embeds `Sender` and `Committer`, both exported. Any
consumer holding an `Adapter` can call `SendFile` or `Commit` directly
and skip the ledger, by writing the obvious thing. The guard is
discipline plus review, not the compiler.

## Why this one earns the stronger form

The failure it prevents is **silent at both ends**. Per the guards doc,
the first real destination has no per-file uniqueness within a session:
a re-sent file becomes two rows and is stacked twice, biasing its
sigma-clip and exposure metadata. Nothing errors. Our delivery reports
success, the far end reports success, and the corruption lands in
someone else's science.

A guard against a silent failure must not itself be silent to violate.

`Commit` is worse: a bypass that blindly resends a lost commit
double-queues an entire session, which is precisely the ambiguity G2's
terminal `Unknown` exists to refuse.

## The constraint that rules out the obvious fix

**Adapters must be able to live in their own package.** The CrowdSky
adapter is a later loop and belongs in its own package with its own
HTTP client, fixtures and tests.

That rules out simply unexporting the interface methods: Go only lets a
type in the *same package* satisfy an interface with unexported
methods, so that fix would force every future adapter into
`package delivery`. Do not take that option, and say in PR.md that you
considered and rejected it.

## What to build

A design where **bypassing the ledger is a compile error**, while an
adapter can still live in an arbitrary package.

One approach that satisfies both — evaluate it, but you are not
required to take it if you find something better:

- `SendFile` takes an additional value of a type declared in
  `delivery` with **no exported fields and no exported constructor**,
  so only `delivery` can mint one. `Send` mints it after the ledger
  check; nothing else can. An adapter in any package can accept the
  type as a parameter, but no consumer can fabricate it.

Whatever you choose:

- it must apply to **both** `Send`/`SendFile` and `Commit`/`Commit`
- it must not require adapters to live in `package delivery`
- it must not make the fake adapter a special case — if the fake needs
  an escape hatch the real ones don't, the design is wrong

**Prove it is a compile error, not a convention.** A test that fails at
runtime is not what this asks for. Demonstrate with a file that does
not compile — the repo has no precedent for that, so pick a mechanism
and justify it in PR.md. A `//go:build ignore` example plus a comment
is acceptable if you cannot do better; showing the exact `go build`
error output in PR.md is the minimum.

## Tests

- [ ] The existing delivery and deliveryjob tests pass unchanged in
  behaviour (signatures may change; semantics must not).
- [ ] G1 still holds: an acknowledged file is not resent across a
  simulated crash and restart.
- [ ] G2 still holds: a lost commit response leaves the Delivery
  terminal `Unknown`, and no path resends.
- [ ] An adapter defined in a **different package** compiles and works
  against the new interface — add one in a test package to prove the
  constraint above is actually satisfied.
- [ ] Full gate green including `-race`, Postgres and S3 legs, 0 skips.

## Warts / traps

- **Behaviour must not change.** This is an API-shape change to make an
  existing guarantee enforceable. If you find yourself altering when
  acks are recorded or how `Unknown` is reached, stop — that is a
  different change.
- Do not touch the CRDs, the controller's admission/metering logic, or
  anything outside `operator/internal/delivery` and its callers unless
  the signature change forces it.
- Do not add a real adapter, a real destination, or any network call.
- `grep -ri crowdsky operator/` must still return nothing.

Finish: `/workspace/PR.md` with the mechanism chosen, the option you
rejected and why, the literal compiler error a bypass now produces, and
confirmation that an out-of-package adapter compiles.
