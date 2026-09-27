# ErgoBars conductor brief

ErgoBars companion to `CONDUCTOR.md` — read that first for the rig itself (loopctl, spec style,
merge protocol). ErgoBars is Casey's WoW Forever UI addon built around his ErgoDox EZ WoW layer.
The loop agents' side of the brief is `CLAUDE.md` in the repo; this file is the conductor side.
Started 2026-09-27.

## 1 · The repo and its remotes

Local clone: `/mnt/nix-projects/cachyos-setup/ergodox`, working branch `master` (tracks
`fjo/main`). The addon folder `wow/ErgoBars/` is **symlinked into the game's AddOns folder**, so
whatever is checked out here is what Casey's client loads on /reload — landing = pulling here.

| remote | where | what |
|---|---|---|
| `fjo` | Forgejo `loop-bot/ErgoBars` | **The** repo. Loops branch/PR here. SSH push works as `cphillips-homelab` (admin collaborator). |

`qmk_firmware/` (≈1 GB, gitignored) and the `.venv` exist only on the desktop.

## 2 · Rig specifics

- Image: `loop-dev:lua-1` (`loops/images/lua-dev`): Python 3.12 + shapely, lua5.1, pinned
  forever-addon-dev at `/opt/forever-addon-dev` (measured Forever API reference + linter).
  Spawn with `--image lua-1`.
- Gate: the repo's `Makefile` — `make build test lint` (gen.py render, luac on every file, both
  linters). Hermetic, ~seconds. Firmware is deliberately outside it.
- Specs: `loops/specs/ergobars-*/SPEC.md` (build) and `loops/specs/ergobars-review-*/SPEC.md`
  (review: `--engine codex --gate 'test -s /workspace/repo/REVIEW.md'`, ChatGPT-sub budget, so
  they don't spend Casey's Claude allowance). Review PRs are read and closed, not merged.
- One Claude loop at a time (shared Pro token); a codex review loop can run beside it.

## 3 · What a loop can't do (and specs must say so)

No game in the sandbox: no /reload, no SavedVariables, no screenshots, no keyboard flashing,
no `wow/sync.py` (it reads the live SavedVariables). So:
- Every build spec ends with an item: "PR.md ends with **In-game checks for Casey**" (what to
  /reload or restart for, where to look, what working looks like).
- Anything uncertain gets a Debug-tab / `ErgoBarsExport` field so the conductor can read the
  result from `WTF/Account/*/*/Pots-Ofpans/SavedVariables/ErgoBars.lua` after Casey's next reload.
  Casey never relays `/run` output.

## 4 · Landing protocol

1. `loopctl reap <name>` → PR on `loop-bot/ErgoBars` (PR.md body).
2. Read the diff; `loopctl merge loop-bot/ErgoBars <pr#>` (the number reap printed).
3. Desktop: `git -C /mnt/nix-projects/cachyos-setup/ergodox pull fjo main` then
   `make build test lint` locally.
4. Tell Casey the in-game checks (full client restart if the .toc gained a file, else /reload).
5. Casey says "check" (read `ErgoBarsExport.debug` from SavedVariables) or "ss" (newest file in
   `_classic_beta_/Screenshots`, crop with magick). Only his confirmation makes it done.

## 5 · Where things stood (2026-09-27)

ErgoBars v0.57.2 on the desktop (bags/bank share `ns.ItemSlot`; `wow/lint.py` in the gate).
First loop planned: `ergobars-review-1` — the hardening review (combat/taint, secret values,
the newer modules), codex engine.
