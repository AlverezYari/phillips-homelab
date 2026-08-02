# SPEC — agent-buffer-retention: nothing ever deletes anything

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

Closes issue **#126**. Scope: `agent/internal/uploader/` and its
callers. Stay out of `gateway/` — a sibling loop
(`gateway-upload-integrity`) is there now.

## The failure

```
grep -rn "os.Remove\|RemoveAll\|retention\|prune\|reap" agent/internal/ agent/main.go
```

excluding tests, returns **nothing**. Files are marked `Shipped: true`
(`uploader/state.go:22`) and left on disk permanently. Nothing prunes
`state.Files`, `state.Previews` or `state.Sessions` either.

A senior review ranked this its worst finding: *"everything else is
recoverable; this one loses data and gets more expensive every night."*

### Three compounding consequences

**1. The `BufferMax*` caps do not guard this.** `pendingLocked`
(`uploader/uploader.go:511-519`) counts only `!rec.Shipped`. So on a
*healthy* agent — where everything ships — backpressure never engages
and the disk fills anyway. The `*int64` nil-vs-zero plumbing behind
those caps is the most heavily commented machinery in the client, and
it guards the wrong number.

**2. `persistLocked` is O(n) per frame, so O(n²) per season.**
`uploader/state.go:109` `json.MarshalIndent`s the entire state map on
every state change. At 50k tracked frames that is a multi-MB
pretty-printed JSON rewritten once per uploaded file — onto whatever SD
card is in the machine beside the telescope. That is write
amplification that kills hardware, not just latency.

**3. `discover()` full-walks the buffer every 60s**
(`uploader.go:895-921`), appending every path to a slice, then doing n
map lookups under the lock.

### How it ends

Disk full → `fetcher.Fetch` fails → `fieldrun.go:573` logs *"will retry
next interval"* forever → the Seestar rotates its own storage →
**frames are lost silently.** The member's night is gone and nothing
said so.

## What to build

### 1. Retention

Delete shipped files. The policy is yours to choose — delete on
`Shipped`, keep N nights, keep until a size ceiling — but say in PR.md
what you chose, what a member loses if the gateway later says it never
received something, and how a member would recover.

Consider that the buffer is also the **resume** story: a file deleted
too eagerly cannot be re-uploaded if the gateway rejects it later.
Deleting only after the gateway has confirmed acceptance is the
conservative reading. Argue your choice.

### 2. Prune the state map

Entries for files no longer on disk must go, or the state file keeps
growing after retention starts working. Prune on the same pass.

### 3. Make the caps guard the real number

`pendingLocked` counting only unshipped files means the caps are
inert on a healthy agent. Either count what is actually on disk, or
rename the fields so they stop implying a guarantee they do not give.
Say which and why — do not leave the current gap with a comment.

### 4. Do not rewrite the whole state on every frame

O(n²) writes are the part that damages hardware. Options include an
append-only journal with periodic compaction, or writing only what
changed. Whatever you pick must survive a crash mid-write — this file
is how the agent knows what it has already uploaded, and
`enrol.Save`'s atomic-write helper has just been fixed to do
`O_EXCL` + fsync + dir-fsync; reuse it rather than writing a third
implementation.

## Tests

- [ ] A shipped file is removed by the retention pass, and its state
  entry with it.
- [ ] An **unshipped** file is never removed, however old.
- [ ] Retention does not remove a file the gateway has not confirmed.
- [ ] The state file does not grow without bound across many
  ship-and-prune cycles — assert on its size or entry count, not on
  the code path.
- [ ] A crash mid-persist leaves a readable state file. This is the
  test that matters most: the buffer's whole job is surviving
  restarts.
- [ ] The buffer caps engage on a healthy agent whose files all ship —
  the regression this loop exists to close.

## Warts / traps

- Do not touch enrolment, the tailnet path, `DescribeDevice`, the keys
  allowlist or the credential handling — all shipped and verified
  against real hardware.
- Do not touch `gateway/` — a sibling loop is editing it now.
- The gate runs `-race -count=1` by default. A retention goroutine
  racing the uploader will be caught, and should be.
- `lost+found` on a PVC-backed ext4 fails a naive walk with EPERM —
  `uploader.go:902-907` already knows this. Do not regress it.
- The deployed headless agent has a PVC-backed buffer that has been
  accumulating since July. Say in PR.md what happens on first start
  after this change: a retention pass that deletes thousands of files
  at once must not stall the pipeline.

Finish: `/workspace/PR.md` with your retention policy and its
justification, what a member loses in the worst case, the state-file
growth measurement before and after, and what happens on the first
start against an existing full buffer.
