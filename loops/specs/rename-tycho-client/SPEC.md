# SPEC — rename-tycho-client: one name for the thing users run

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

## Why

The binary a user downloads and runs is called `scopetui`. It is the
**client** — the thing that connects a scope to Tycho. The TUI is how
it happens to present itself, not what it is for, and naming it after
its rendering layer is why every doc has to explain what it does.

Decision (the founder's, taken today): it is **`tycho-client`**.

```
$ tycho-client -conf tycho.yaml
```

This matters now rather than later because the enrolment flow shipped
today puts that command in front of every new user, on a setup screen,
as the one thing they must type. Renaming it after people have it in
their shell history is a worse day than renaming it this afternoon.

## What to rename

- `agent/cmd/scopetui/` → `agent/cmd/tycho-client/`, and the binary it
  produces.
- Every reference: `README.md`, `docs/**` (except `docs/adr/**`, see
  traps), Makefile targets, CI workflow, package docs, comments, test
  names, log lines, help text, and the TUI's own header.
- Anything user-visible that says "scopeTUI" in prose becomes "the
  Tycho client" or `tycho-client` as the sentence needs.

## Audit the rest of the names, and mostly leave them alone

The founder's ask was broader than one binary: *"we're getting to the
point that we might need to unite the naming"*. So audit — but change
only what is actually inconsistent, and say why in PR.md for each.

Current state, for reference:

| name | what it is |
|---|---|
| `tycho-agent`, `tycho-gateway`, `tycho-operator`, `tycho-combine`, `tycho-scorer` | services — already consistent |
| `scopetui` | the client — **renaming** |
| `scopectl` | one-shot ZWO debug CLI |
| `fleetview` | fleet-wide ingest view over JetStream |
| `dummyscope`, `simfleet` | simulators (`docs/dev/simulation.md`) |

Guidance, not orders:

- The **services** are already `tycho-*`. Do not touch them: their names
  are in Kubernetes manifests, image tags and gitops in another repo
  that this loop cannot see, and renaming them breaks a live deployment
  for zero user benefit.
- `scopectl` and `fleetview` ship to operators, so consistency has some
  value. Weigh it against the same breakage risk and argue your call.
- `dummyscope`/`simfleet` are dev-only. Renaming them is churn.
- README already frames these as "supporting binaries, deliberately not
  part of 'one client'". That distinction is deliberate — preserve it or
  explain why it should go.

**Do not rename anything whose name appears in a Kubernetes manifest,
an image tag, or a gitops repo.** You cannot see those, and a green
gate here will not tell you it broke.

## Traps

- `docs/adr/**` is a historical record. ADRs 0008 and 0009 were written
  today and mention the client. **Do not rewrite them.** An ADR records
  what was decided when it was decided; the rename is later context.
  If a reference genuinely misleads, the fix is a note, not an edit.
- The `tycho.yaml` config filename does **not** change.
- The `-conf`/`-scope`/`-agent`/`-key` flags do **not** change. This is a
  rename, not a CLI redesign, and the setup screen live on the site
  right now tells users to type `-conf tycho.yaml`.
- Do not touch the enrolment code, the keys allowlist, `DescribeDevice`,
  or the credential handling — all shipped today and verified against
  real hardware and a live gateway. This loop moves names, nothing else.
- Release asset filenames are produced by a build script in a different
  repo. Do not try to fix them here; note in PR.md what the new binary
  name means for them.

## Tests

- [ ] `make build test lint` green, which is table stakes.
- [ ] No occurrence of `scopetui` or `scopeTUI` survives outside
  `docs/adr/**` and any CHANGELOG-style history — grep for both spellings,
  case-insensitively, and put the grep output in PR.md.
- [ ] The existing client tests still pass under the new package path,
  unchanged in substance. If you find yourself editing what a test
  asserts, you are no longer doing a rename.

Finish: `/workspace/PR.md` with the grep proving the old name is gone,
your decision and reasoning for each other binary, and anything you
deliberately left alone because it reaches outside this repo.
