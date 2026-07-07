---
name: loopctl
description: Operate the loop rig (autonomous coding loops on agent-sandbox/homelab-04) with single deterministic verbs — spawn, status, logs, answer, pause, resume, reap. Use whenever Casey asks to start/check/answer/stop a loop, or when acting as the loop-rig conductor.
---

# loopctl — conductor verbs for the loop rig

The rig: each loop = one agent-sandbox Sandbox on homelab-04 (gVisor, NVMe
/workspace PVC) running `harness.sh` from the loop-dev image — stateless
`claude -p` per iteration (Casey's Claude Pro OAuth token; ~45 prompts/5h
SHARED with his interactive use → run ONE loop at a time), gated by
`make build test lint`, pushed per green iteration to FJO (Forgejo,
code.phillips-homelab.net) as branch `loop/<name>`. Decisions/events flow
loops.<name>.* over NATS; the bridge pings Casey's phone (ntfy topic
`loops`). Full architecture: `loops/` in this repo + memory file
project-loop-rig.

## Verbs (script: `loops/bin/loopctl`)

```sh
loops/bin/loopctl spawn <name> <owner/repo> --spec <SPEC.md> [--max-iter N] [--image TAG]
loops/bin/loopctl status [name]     # fleet table, or one loop's PROGRESS/decisions
loops/bin/loopctl logs <name> [-f]  # harness stdout
loops/bin/loopctl answer <name> '<json-or-text>'  # -> loops.<name>.inbox (durable)
loops/bin/loopctl pause <name> / resume <name>    # Suspended keeps the PVC
loops/bin/loopctl reap <name> [--no-pr]  # PR (PR.md body + PROGRESS comment + review request) then delete
```

## Conductor session start

1. `loops/bin/loopctl status` — rediscover fleet state (you are stateless).
2. For `blocked` loops: `status <name>` shows unrelayed/relayed decisions;
   batch-present them to Casey with recommendations; `answer` each.
3. Never edit a running loop's /workspace or SPEC.md; never patch code in a
   sandbox. Escalate BLOCKED to Casey.

## Writing SPECs (examples: loops/specs/)

Checkbox items sized one-per-iteration; harness gate is
`make build test lint` (override via GATE_CMD env in the manifest); demand
hermetic gates ("no network, no gh auth"); include repo wart warnings and
"prefer the simplest reading of the repo's CLAUDE.md over filing decisions".
The finishing agent writes /workspace/PR.md (reviewer-facing) — reap uses it
as the PR body.

## Review/merge flow + FJO traps

Loop PRs request review from cphillips-homelab; branch protection needs 1
official approval; Casey approves in FJO UI, conductor merges via API
(helper pod, loop-bot token). Traps: only repo collaborators give OFFICIAL
reviews (site admin ≠ eligible); branch-protection API field is
`approvals_whitelist_username` (SINGULAR — plural is silently ignored =
enabled-but-empty = nobody can approve); official is stamped at submission,
so gate fixes require re-approval. New loop-bot repos: add Casey as admin
collaborator at creation.

## Rig invariants

- Secrets live in 1Password item `loop-rig` → ESO → `loop-secrets`; helper
  pods read them in-cluster; never materialize tokens on the laptop.
- Images: build via buildx remote builder `homelab-bk` → buildkit svc →
  `zot.phillips-homelab.net/loop-dev:<main-sha>`; bump the tag in
  `loops/templates/loop-sandbox.yaml` via PR.
- ResourceQuota on `loops` ns is the hard fleet cap; Pro rate limits are the
  soft one. Harness backs off on rate limits without burning iterations.
