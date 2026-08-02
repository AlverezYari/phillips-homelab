# SPEC — webapp-process-local-state: three Maps that vanish on restart

Repo: `loop-bot/tychofleet`. Gate: `make build test lint`.

Closes issue **#56**. A sibling loop is in `loop-bot/tycho` — different
repo, no overlap.

## The failure, which already happened

The founder was mid-setup when a deploy restarted the pod. His pending
tailnet key vanished, the config download failed, and he had to be
handed a hand-minted `tycho.yaml` out of band.

Three module-level `Map`s are load-bearing:

| Map | File | Consequence |
|---|---|---|
| `pending` (tailnet keys) | `tsmint/pending-keys.ts:24` | **Lost entirely on restart.** With two replicas: mint on A, download on B → 503. |
| `hits` (rate limit) | `rate-limit.ts:4` | Per-pod limits; the effective limit multiplies by replica count. |
| `cache` (preview bytes) | `garage/preview-cache.ts:32` | Duplicated memory per pod. |

Two of them **never evict**:

- `rate-limit.ts:4` is keyed by client IP and cleared only by a
  test-only function — one entry per unique IP, forever, on a
  **public** waitlist endpoint. That is an unbounded map an anonymous
  visitor can grow.
- `preview-cache.ts:32` deletes only on a 404 — roughly 230 KB per
  master, so a few thousand masters is a GB of resident heap.

## What to build

### 1. Pending setup keys must survive a restart

This is the one that hurt a real member. The key is minted at one
request and consumed at another, so it needs to live somewhere that
outlives a process.

The site already has SQLite. Using it is the obvious answer — but the
key is a **credential**, and `pending-keys.ts:1-4` states the rule that
it must not reach the database. Note that `members.authkey`
(`schema.ts:145`) already stores a raw Tailscale key in plaintext, so
the codebase currently holds two auth-key paths with **opposite**
security postures.

Resolve that contradiction deliberately and say how in PR.md. Options
include: store it encrypted at rest; store only a short-lived
reference and re-mint on demand; accept plaintext with a tight TTL and
mandatory deletion on delivery, matching what `members.authkey`
already does. **Any of these is defensible. Silently picking one is
not.**

Whatever you choose, the existing TOCTOU guard on delivery
(`tycho-conf-delivery.ts:50` nulls the key after handing it over) is
the pattern to match.

### 2. Bound the rate limiter

An unbounded map keyed by client IP on a public endpoint is a memory
leak with a trivial trigger. Give it eviction — a sweep, a TTL, or a
bounded structure. It does not need to be perfect across replicas to
be worth fixing.

While you are there: `clientIpFromRequest` (`rate-limit.ts:16-18`)
trusts the first `X-Forwarded-For` hop when the Cloudflare header is
absent, which anything reaching the pod directly can spoof. Say
whether you fixed that or left it, and why.

### 3. Bound the preview cache

An LRU with a size ceiling, or a TTL. Say what you chose and what the
memory ceiling now is.

### 4. Say what still breaks at two replicas

This loop does not have to make the site horizontally scalable — that
is a deployment decision, not a code change. But the current state is
that **nobody knows** which parts break. Enumerate it in PR.md: for
each of the three, what happens at two replicas after your change.

That list is the deliverable that lets someone decide the topology
later, rather than discovering it in production.

## Tests

- [ ] A pending key survives a simulated process restart — construct
  the store fresh and assert the key is still retrievable.
- [ ] A delivered key is destroyed, and cannot be retrieved twice.
- [ ] The rate-limit map does not grow without bound across many
  distinct client IPs — assert on size, not on the code path.
- [ ] The preview cache evicts at its ceiling.
- [ ] Existing rate-limit and preview behaviour is unchanged for the
  normal case.

## Warts / traps

- Do not change enrolment, the scope API, the download route or
  authorization — all shipped and verified against the live gateway.
- Do not log a key, ever. `tsmint/client.ts` logs status codes and
  never bodies; match that.
- Migration numbering: next after the highest in `drizzle/`.
- `docs/design/**` is read-only law.

Finish: `/workspace/PR.md` with your credential-at-rest decision and
its justification, the memory ceilings, and the enumerated
two-replica behaviour for all three.
