# In-cluster conductor

Chains loops without a Claude session attached. A CronJob
(`gitops/tools/apps/loops/conductor.yaml`, one per chain) runs `conductor.sh <chain>`
every 10 minutes, and each run advances the chain by at most one step:

```
idle --spawn head of queue--> running --sandbox state done--> reap (files PR)
  ^                              |                              |
  |                    blocked / exhausted / gone               v
  |                              v                         reviewing (Job runs review-<chain>.sh)
  +---- merge reviewed sha --- halted <------ FAIL / merge refused / any error
```

- **Spec writing stays with a person or a Claude session.** The queue only holds
  specs that are already written; the conductor never writes one.
- **The review is mechanical.** `review-corten.sh` merges the branch onto main and
  checks: normalization untouched, the gate (`make build test lint`), audit records
  reproduce, every fixture golden matches a fresh capture from the pinned dbt, and 1000
  fuzz seeds the loop never saw (`next_seed` in the state, advancing 1000 per review).
  The full log goes on the PR as a comment, pass or fail.
- **Merges are pinned.** It merges with `head_commit_id` set to the reviewed sha, so a
  PR that moved after review is refused, not merged.
- **Halting is the only failure mode.** Every halt pings the phone (ntfy `loops`) with
  the reason and leaves everything in place for inspection.

## Verbs (`conductor-ctl.sh`)

```
conductor-ctl.sh install                    # push code: this dir + loopctl + sandbox template
conductor-ctl.sh enqueue corten corten-sources loop-bot/corten corten-1 25 loops/specs/corten-sources/SPEC.md
conductor-ctl.sh status corten
conductor-ctl.sh resume corten [phase]      # after fixing whatever halted it
conductor-ctl.sh run corten                 # one step now
```

To hand a loop that a session spawned by hand over to the conductor, set the state
directly: `kubectl -n loops create configmap conductor-corten --from-literal=phase=running
--from-literal=loop=<name> --from-literal=next_seed=100000`.

Code and queues are ConfigMaps, not git clones, because the Forgejo mirror of this
repo syncs every 8 hours and loop-bot can't trigger it. Rerun `install` after
changing anything here, `loops/bin/loopctl` or the sandbox template.
