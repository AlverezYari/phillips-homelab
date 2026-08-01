# SPEC — gateway-identity-enforcement: stop letting any agent claim any scope

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Implements **ADR 0008 (scope identity) section 2**. Unlike the previous
loop, the ADR **is** in your clone: read
`docs/adr/0008-scope-identity.md` before writing anything. If your
implementation must diverge from it, say so in PR.md — do not edit the
ADR to match your code.

## The hole

`RegisterSource` (`gateway/internal/catalog/postgres.go`) is an upsert
behind a **single shared bearer token held by every agent in the
fleet**:

```sql
INSERT INTO source (id, model, agent_version, registered_at, make, serial, ...)
VALUES (...)
ON CONFLICT (id) DO UPDATE SET
    model = COALESCE(EXCLUDED.model, source.model),
    serial = COALESCE(EXCLUDED.serial, source.serial),
    ...
```

An agent that registers under a source id another owner already uses
does not collide, does not error, and does not alert. It takes the row,
and its frames land under the other owner's scope, attributed to them,
pooled into their masters. A typo in `SOURCE_ID` does this. So does
copy-pasting a config between two scopes — which is the *likely* way it
happens, not the adversarial one.

Until last night nothing could tell two devices apart, so the upsert was
the only behaviour available. That changed:

```
id               | seestar-1
model            | Seestar S30 Pro
make             | ZWO
serial           | 5741d34d
hardware_id      | de079cbf89464ff2
firmware_version | 8.46
attested_at      | 2026-08-01 02:08:58+00
```

The live scope now attests. A fingerprint exists to enforce against.

## The decision to implement

**A registration whose fingerprint contradicts the recorded one is
refused.** Not upserted, not warned about, not last-write-wins.

The transitions, all four of which must be handled deliberately:

| recorded | incoming | behaviour |
|---|---|---|
| no attestation | attests | **bind** — trust on first use, record it |
| attested | same fingerprint | update firmware/agent version as today |
| attested | no attestation (device unreachable) | **allowed**, existing attestation untouched — this already works via `COALESCE`, do not regress it |
| attested | *different* fingerprint | **refuse**, loudly |

Decide and state in PR.md: what counts as "different" when `serial`
matches and `hardware_id` does not, or only one of the two is present?
They are independent values (`device.sn` and `device.cpuId`) and a
device can legitimately report one and not the other. Pick a rule,
justify it, and make it a named function with its own tests rather than
an inline `&&` — this is the predicate the whole decision rests on.

## The rebind path is part of this loop, not a follow-up

ADR 0008's consequences say it outright: without a rebind path, **the
first legitimate hardware swap becomes a support incident.** An owner
who genuinely replaces a scope and keeps the id must have a way through
that is explicit and deliberate.

- It must **not** be a flag on the normal registration path that an
  agent can set for itself. If an agent can rebind itself, nothing was
  enforced.
- It must be an operator action against the gateway, or a documented
  catalog operation — your call, argue for it in PR.md.
- Whatever it is, **document it where the person hitting the error will
  look.** The refusal message itself should point at the remedy. An
  error that says "fingerprint mismatch" and nothing else sends someone
  to the source code at 2am.

## Do not turn a refusal into a hot loop

The agent registers on startup and the uploader re-registers over its
lifetime. If the gateway starts refusing, the agent must **back off and
stay loud** — not retry every few seconds forever, and not silently
give up either. A refused agent whose logs scroll one line per second is
a refused agent nobody reads.

Check what the current retry behaviour actually does before changing it,
and say in PR.md what a refused agent does over its first ten minutes.

## Tests

The one that matters most is that **the running fleet keeps working**:

- [ ] A source recorded exactly as `seestar-1` is above, re-registering
  with that same fingerprint, succeeds. If this test fails you have
  broken the only real scope in the fleet.
- [ ] The same source re-registering with no attestation at all (device
  was off) succeeds and leaves the recorded fingerprint intact.
- [ ] A *different* fingerprint under the same id is refused, and the
  recorded row is unchanged afterwards — assert the row, not just the
  error. A refusal that still wrote is worse than no refusal, because
  the error implies nothing happened.
- [ ] An unattested source that attests for the first time binds.
- [ ] The refusal is distinguishable by callers from an ordinary
  failure — a typed error, not a string match on a message.
- [ ] Whatever rebind path you build has a test that it works, and a
  test that an ordinary agent registration **cannot** trigger it.

## What this loop does not do

**ADR 0008 §4 (`TELESCOP` demoted to audit) is not in this loop.**
Comparing the header serial against the attested serial on ingest is the
right thing and it belongs in its own loop: it changes the highest-
throughput path in the system, and a wrong predicate there rejects
every frame from a live scope instead of refusing one registration.
Registration is a once-per-startup event and is where the hole is. Do
not add header checking here.

## Warts / traps

- The gateway is the enforcement point. Do not put the check in the
  agent — an agent enforcing a rule about itself is not enforcement.
- Attestation is **self-reported, not cryptographic**. This refuses
  accidents, collisions and copy-pasted configs. It does not stop a
  modified firmware from claiming any serial, and the shared fleet
  token is still the weak link. Do not write a comment, field name or
  PR.md line calling this "secure" or "verified".
- Do not change `DescribeDevice`, the keys allowlist, or anything in
  `agent/internal/zwo` — that shipped last night and works against real
  hardware.
- `isNew` from `RegisterSource` drives `tycho.source.registered`'s
  emitted-once semantics. Do not break it, and decide whether a refusal
  should emit anything on the bus at all.
- Migration numbering: next after the highest in
  `gateway/internal/catalog/migrations/` (0006 is taken as of last
  night).

Finish: `/workspace/PR.md` with your fingerprint-comparison rule and why,
the four transitions and what each does, the rebind path and how an
owner discovers it, what a refused agent does over ten minutes, and
proof that a `seestar-1`-shaped row still registers cleanly.
