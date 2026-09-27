# SPEC — ergobars-review-1: hardening review (REVIEW ONLY)

Repo: `loop-bot/ErgoBars`. Gate: `test -s /workspace/repo/REVIEW.md`.
Engine: codex. You change NOTHING except creating `REVIEW.md`.

Read `CLAUDE.md` first: it lists the Forever client's hard rules, each learned from a bug that
reached the game. The addon is `wow/ErgoBars/` (~10k lines of Lua, built in three days, so
expect rough edges). You can't run WoW; judge from code, Blizzard's UI source
(github.com/Gethe/wow-ui-source, branch `forever`; Forever's game type is "camelot", whose
`*/Camelot/*` files override Mainline) and `/opt/forever-addon-dev/reference/` (measured API
facts, including which returns are secret).

## What to review

1. **Combat and taint safety.** Anything that shows, hides, moves or re-attributes a protected
   frame in combat; secure buttons anchored to frames that toggle in combat; Blizzard frames
   touched in ways that taint them (reparenting, hooking, calling their methods); addon code
   calling protected functions. Check `ErgoBars.lua` (the bar, assign mode, stances),
   `QuickBar.lua`, `Stances.lua`, `Bags.lua`/`Bank.lua` (the secure layer), `Social.lua`,
   `UnitFrames.lua`.
2. **Secret values.** Any comparison, arithmetic, string op, table key or boolean test on a
   value that can be secret on Forever (other units' health/power, UnitInRange, enemy casts,
   names, aura data in combat) without an `ns.secret` / `issecretvalue` guard first.
3. **The newer modules** (least tested in game): `Fireside.lua` (chat: composer hooks on
   Blizzard's edit box, name completion, idle fade), `Bank.lua`, `Social.lua`, `Launcher.lua`,
   `Timers.lua`, `EnemyPlates.lua`, `Nameplates.lua`. Look for nil paths, events registered
   but unhandled, state that can get stuck, and hooks that assume Blizzard's call order.
4. **Error blast radius.** Where one error aborts a whole module's setup (a failed call at
   file scope or early in a build function) versus being contained by pcall.

Don't propose redesigns or style changes. `wow/lint.py` already catches its listed patterns;
spend your effort on what regex can't see.

## Output

`REVIEW.md`, findings ranked by severity, each with:
file:line · what goes wrong · the concrete in-game trigger (what the player does or sees) ·
confidence (CONFIRMED from code/Blizzard source, or PLAUSIBLE) · a one-line fix direction.
End with a short "what's solid" section (so the conductor knows what not to touch) and a
one-paragraph verdict on the riskiest area.
