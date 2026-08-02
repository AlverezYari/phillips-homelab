# SPEC — webapp-connecting-state: "offline" is hiding a third state

Repo: `loop-bot/tychofleet`. Gate: `make build test lint`.

## The failure

The founder finished setup, watched his deck, and saw his brand-new
scope reported as **offline** — while the client was running fine and
the gateway was recording heartbeats seconds later. He asked, exactly:

> is that offline like my scope is off, or just not broadcasting
> anything?

That is the question the card should already have answered. A minute
later it flipped to online on its own.

Nothing is broken. `resolveScopeCardState` (`src/lib/scope-deck.ts`) is
behaving as written: with `lastHeartbeatAt` null it returns
`{kind: "offline", lastSeenText: null}`. The bug is that **two very
different situations render as the same word**:

| reality | today | what it means |
|---|---|---|
| never heard a heartbeat | `offline` | it is still coming up |
| heard one, but not recently | `offline · last seen 4h ago` | it really is down |

The first happens exactly once per scope — in the minute after setup,
while the member is staring at the screen deciding whether any of this
worked. Telling them "offline" then is the worst possible moment to be
imprecise.

## The fix

A distinct state for **enrolled and attested, but no heartbeat ever
received**. Call it `connecting` unless the design language suggests
better.

- It reads as work in progress, not failure: something like
  `◌ connecting… waiting for the first check-in`. Do not use the word
  offline, and do not use a red/error treatment.
- Once any heartbeat has ever arrived, the existing two states apply
  unchanged: recent → `● online`; stale → `● offline · last seen …`.
- A scope that goes quiet after having been seen is **offline**, never
  back to connecting. `connecting` means "never yet", not "not right
  now" — otherwise it becomes another word for offline and we are back
  where we started.

`HEARTBEAT_STALE_AFTER_MS` (2 minutes) stays as is. Its comment notes
the client's real heartbeat interval was unknown when it was written —
it is **500ms in tests and the production default is set by
`uploader.WithHeartbeatInterval`**; if you can confirm the real interval
from the tycho repo's defaults, say so in PR.md and adjust the constant
only if 2 minutes is clearly wrong. Do not guess.

## Does it need to be reassuring for long?

Consider, and decide deliberately: a scope that has said `connecting…`
for a very long time is not connecting, it is broken. Either leave it
connecting forever (simple, honest about what we know: we have never
heard from it) or degrade to something firmer after a while. If you
degrade, say what the threshold is and why, and make sure the message
still tells the member what to *do* — the setup screen is where they
would go.

State your choice in PR.md either way. Silently picking one is how the
current ambiguity got in.

## Tests

- [ ] Enrolled + attested + `lastHeartbeatAt` null renders `connecting`,
  and specifically **does not** contain the word "offline".
- [ ] A heartbeat within the window renders `online`.
- [ ] A heartbeat older than the window renders `offline` **with** a
  last-seen time.
- [ ] A scope that was online and goes stale renders `offline`, not
  `connecting` — assert this explicitly; it is the regression that
  would make the new state meaningless.
- [ ] The existing `setup-not-finished` and `awaiting-attestation`
  states are unchanged.

Five states now, each with its own test. `src/tests/pages/
scope-deck-cards.test.ts` already has the shape.

## Warts / traps

- This is a **rendering** change. Do not touch the gateway, the scope
  API, enrolment, key minting, or the heartbeat itself.
- The deck polls; do not add a refresh mechanism to make `connecting`
  resolve faster. It resolves on its own within a heartbeat.
- A degraded gateway read must still render `--`, never `0h 00m`, and
  never a fabricated state. If we cannot reach the gateway we do not
  know whether the scope is connecting or offline, and must not claim
  either.
- `docs/design/**` is read-only law.

Finish: `/workspace/PR.md` with an ASCII render of all five card states
as built, your decision on whether `connecting` ever degrades and why,
and whether you were able to confirm the client's real heartbeat
interval.
