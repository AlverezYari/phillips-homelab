# Conductor brief

For an agent picking up the Tycho / TychoFleet work. Read this before
touching anything; it is the working set, not a tutorial.

Your role is **conductor**: you write specs, spawn loops, review what
comes back, and drive deploys. The loop agents write the code. When you
catch yourself implementing a feature by hand, stop and ask whether it
should be a loop — the answer is usually yes for anything beyond a
one-line review fix.

---

## 1 · The three repos

| repo | where | what |
|---|---|---|
| **tycho** | Forgejo `loop-bot/tycho` (`code.phillips-homelab.net`) | The Go pipeline: agent, gateway, operator, combine, scorer, and the `tycho-client` binary. |
| **tychofleet** | Forgejo `loop-bot/tychofleet` | The public site, tychofleet.com. Astro 5 SSR, SQLite + Drizzle, Tailwind v4, Vitest, Biome, pnpm. |
| **phillips-homelab** | GitHub `AlverezYari/phillips-homelab` | Infrastructure. ArgoCD gitops, the loop rig (`loops/`), and this file. |

Local clones live at `/mnt/nix-projects/{tycho,tychofleet,phillips-homelab}`.

Forgejo is **private**, so its API and release assets are unreachable
without a token — that has bitten the product once already (a download
link that 404s for real users).

## 2 · Cluster access

```bash
export KUBECONFIG=/home/casey/.kube/tycho-sa.yaml
```

Do this in **every** shell. The default `~/.kube/config` uses
interactive Omni OAuth and hangs silently when Casey is remote. A
command that appears to freeze is almost always this.

Key namespaces: `tycho` (pipeline + Postgres `tycho-pg-1`), `tychofleet`
(the site), `loops` (loop sandboxes), `tailscale`, `garage`, `argocd`.

## 3 · Secrets: 1Password → ESO → Kubernetes

Nothing secret is in git. External Secrets Operator syncs from 1Password
(`ClusterSecretStore` named `staging`) into Secrets.

- `tycho` item → `tycho-config` in ns `tycho`
- `tychofleet` item → `tychofleet-config` in ns `tychofleet`
- `tailscale-config` item → `operator-oauth` in ns `tailscale`

**Field naming is not consistent** — the `tycho` item mixes lowercase
(`see_start_pem`, `s3_access_key_id`) and uppercase (`SITE_API_TOKEN`).
Guessing costs a failed sync and a round trip; ask.

**Only Casey can write 1Password.** When a change needs a new field,
tell him the exact item, field name and value, then wire the
ExternalSecret. Adding a key to the ExternalSecret before the field
exists puts it in `SecretSyncedError` (existing keys are retained, so it
degrades rather than breaks).

**Never print a secret into the transcript.** Write it to a file and
send it. A Garage key had to be rotated after being echoed once.

`envFrom` resolves at pod start, so a Secret gaining a key does **not**
reach a running pod — restart the Deployment.

## 4 · Gitops

ArgoCD watches `AlverezYari/phillips-homelab`, `selfHeal: true`,
`prune: true`. Editing live objects is pointless; Argo reverts them.

| path | app |
|---|---|
| `gitops/tools/apps/tycho/` | the pipeline (kustomize, sets `namespace: tycho`) |
| `gitops/apps/tychofleet/` | the site |
| `gitops/tools/apps/*.yml` | flat manifests, applied by the `tool-apps` app |

**Deploy loop:** merge to the repo's `main` → `git pull` → `make images`
+ `make push` (tag is the short SHA) → bump `newTag` in the component's
`kustomization.yaml` → PR → Casey merges → Argo syncs in 2–8 minutes.
For tychofleet, `docker build` from its repo root and pin `image:` in
`deployment.yaml`.

**Always verify the rollout reached the pod**, not just that the PR
merged. A merged revert that Argo hasn't synced is not a revert.

## 5 · The loop rig

`loops/bin/loopctl` — sandboxes on `homelab-04`, driven from your shell.

```
loopctl spawn <name> <owner/repo> --spec <file> [--max-iter N]
loopctl status [name]
loopctl logs <name> [-f]
loopctl answer <name> <text>
loopctl reap <name>                # files the PR, PR.md becomes the body
loopctl merge <owner/repo> <pr#>
loopctl pr <owner/repo> <branch> [title]
loopctl release <owner/repo> <tag> [title]
```

Specs live in `loops/specs/<name>/SPEC.md`. Only `SPEC.md` is uploaded —
the loop cannot see anything else you wrote.

**A loop clones `main` once, at spawn.** Anything merged afterwards is
invisible to it. Sequence spawns against pending PRs, or make the spec
self-contained and say so.

`reap` mounts the workspace PVC in a helper pod, so `PR.md` survives a
completed sandbox. Reap before assuming work is lost.

Loops running against the **same repo** concurrently will produce
branches that must merge cleanly — give each a disjoint tree and say so
in both specs ("stay out of `gateway/`").

## 6 · Writing specs that work

The house style, learned the hard way:

- **Lead with the failure**, concretely — the log line, the wrong value,
  the screenshot. Loops do far better fixing a described symptom than
  implementing a description.
- **Say why, not just what.** Every spec that explained the reasoning got
  a better answer than the ones that listed requirements.
- **Name the trap.** "Do not implement the refusal yet, here is what
  breaks if you do." Loops will otherwise do the obvious next thing.
- **Demand the test that would have caught it**, not just a fix.
- **Put types on the wire.** A contract that names a field and not its
  type is how two green loops shipped a broken flow (`owner_member_id`
  as JSON number vs Go string).
- **Forbid overclaiming.** If something is self-reported, say the word
  "verified" may not appear.
- UI work: green gates cannot see pixels. Require ASCII renders of every
  state in PR.md, and PNGs in `/workspace/renders/` if possible.

Loops land green on iteration 1 more often than not when the spec is
good. Budget 15–20 iterations.

## 7 · Merge protocol

**Casey merges. You do not push to `main`.** File PRs, explain the
change and the risk, and wait. `loopctl merge` is the sanctioned path
for Forgejo once he approves; `gh pr merge` on GitHub is sometimes
blocked for you.

Merges silently fail to land more often than you would expect — **always
re-fetch and confirm the change is actually on `origin/main`** before
watching for a rollout. Three separate times a "merged" PR was still
open.

Never `git add -A`; there is unrelated work in progress in these repos.

## 8 · Current architecture, briefly

Frames flow: **scope → agent/client → gateway → Garage + Postgres
catalog → operator → combine → masters → tychofleet**.

Decisions live in `docs/adr/` in the tycho repo. Most relevant:

- **0008 scope identity** — the client asks the device what it is
  (`DescribeDevice`), through a compile-time keys allowlist because the
  raw response carries the WiFi password, device PIN and owner's
  coordinates. Optical trains are first-class; one S30 Pro reports two.
- **0009 scope credentials** — server-issued scope ids, per-scope
  secrets obtained by redeeming a one-time setup code, auth on the
  upload path. Supersedes 0008 §2.

Enrolment as designed: member adds a scope on the site → downloads
`tycho.yaml` with a one-time code → runs `tycho-client -conf tycho.yaml`
→ it redeems, fetches the device interop key from the gateway (memory
only, never written to disk), discovers the scope on the LAN, attests,
registers, streams.

## 9 · Lessons worth inheriting

**Every serious bug this project has had was two halves disagreeing,
and the disagreement rendered as an empty panel rather than an error.**
An empty `ADDRESS` column. A `0h 00m`. A blank roster. A silent egress
block that looks like "you have no scopes yet". When something renders
as nothing, suspect a broken join before you suspect no data.

Related: **a parse error is often a connectivity error.** With the scope
powered off the agent logs `decoding get_verify_str result: unexpected
end of JSON input`, because the proxy accepts the TCP connection whether
or not the device is behind it.

**Verify the deployed artifact, not the tag.** Grep the running pod's
bundle for the fix. An image tag proves what was built, not what runs.

**Check ownership before deleting.** Cleaning up test rows nearly
removed Casey's real scope; the owner id was the only thing that
distinguished them.

**Fixture-gated tests read green while checking nothing.** The
Postgres-backed tests skip without `TYCHO_TEST_DATABASE_URL`, which CI
never sets. Stand up a throwaway Postgres and run them before trusting
a green gate on anything SQL.

**Correct yourself in public.** Several times the founder was right and
the confident answer was wrong — about operator capabilities, about
architecture that already existed. Go and check.
