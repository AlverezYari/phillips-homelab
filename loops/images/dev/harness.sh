#!/usr/bin/env bash
# Loop harness: the authoritative layer for loop mechanics.
# The agent proposes, the harness disposes: validation gates and git push
# live here, where the agent cannot rationalize around them.
#
# Contract (from the loop-rig brief):
#   - stateless `claude -p` per iteration
#   - harness-owned gate (GATE_CMD, default "make build test lint")
#   - commit+push on green only; MAX_ITER budget
#   - decisions: agent writes /workspace/decisions/NNN-slug.json, harness
#     relays to NATS; answers drain from loops.<name>.inbox to /workspace/.inbox
#   - done: all boxes checked + gate green -> agent writes /workspace/.loop-done
#   - exit codes: 0 done, 2 blocked-needs-human, 3 budget exhausted
#   - state label loop.phillips.dev/state on own Sandbox CR
set -uo pipefail

: "${LOOP_NAME:?LOOP_NAME required (sandbox name)}"
: "${REPO_URL:?REPO_URL required (Forgejo clone URL, no creds)}"
: "${CLAUDE_CODE_OAUTH_TOKEN:?CLAUDE_CODE_OAUTH_TOKEN required (claude setup-token)}"
: "${FORGEJO_TOKEN:?FORGEJO_TOKEN required}"
# Pro-subscription auth: an API key would take precedence over the OAuth
# token and break auth if both are set.
unset ANTHROPIC_API_KEY
BRANCH="${BRANCH:-loop/${LOOP_NAME}}"
MAX_ITER="${MAX_ITER:-30}"
GATE_CMD="${GATE_CMD:-make build test lint}"
NATS_SERVER="${NATS_SERVER:-nats.loops.svc.cluster.local:4222}"
NATS_URL="nats://loop:${NATS_PASSWORD:-}@${NATS_SERVER}"
WS=/workspace
REPO_DIR="$WS/repo"
MEMORY_URL="${MEMORY_URL:-}"   # optional read-only memory repo

log()  { echo "[harness $(date -u +%H:%M:%S)] $*"; }
term() { echo "$*" > /dev/termination-log 2>/dev/null || true; }

npub() { # npub <subject-suffix> <json> — best-effort, never fatal
  nats --server "$NATS_URL" pub "loops.${LOOP_NAME}.$1" "$2" >/dev/null 2>&1 \
    || log "WARN nats pub $1 failed"
}

set_state() { # running|blocked|done — best-effort
  kubectl -n loops patch sandbox "$LOOP_NAME" --type=merge \
    -p "{\"metadata\":{\"labels\":{\"loop.phillips.dev/state\":\"$1\"}}}" \
    >/dev/null 2>&1 || log "WARN state label patch failed ($1)"
}

ensure_inbox_consumer() { # durable pull consumer: answers persist in the
  # LOOPS stream even when published mid-iteration, drained at iteration start
  nats --server "$NATS_URL" consumer add LOOPS "inbox-${LOOP_NAME}" \
    --filter "loops.${LOOP_NAME}.inbox" --pull --deliver all --ack explicit \
    --defaults >/dev/null 2>&1 || true
}

drain_inbox() { # answers published to loops.<name>.inbox land in .inbox/
  mkdir -p "$WS/.inbox"
  local n=0
  while msg=$(timeout 5 nats --server "$NATS_URL" consumer next LOOPS \
      "inbox-${LOOP_NAME}" --raw 2>/dev/null) && [ -n "$msg" ]; do
    n=$((n+1))
    echo "$msg" > "$WS/.inbox/$(date -u +%s)-$n.json"
  done
  [ "$n" -gt 0 ] && log "drained $n inbox message(s)"
}

relay_decisions() { # new decision files -> NATS (file-then-relay per brief)
  mkdir -p "$WS/decisions/.sent"
  local f
  for f in "$WS"/decisions/*.json; do
    [ -e "$f" ] || continue
    if jq -e . "$f" >/dev/null 2>&1; then
      npub decisions "$(jq -c --arg loop "$LOOP_NAME" '. + {loop: $loop}' "$f")"
      mv "$f" "$WS/decisions/.sent/"
      log "relayed decision $(basename "$f")"
    else
      log "WARN malformed decision file $(basename "$f"), leaving in place"
    fi
  done
}

# ---- bootstrap -------------------------------------------------------------
log "loop ${LOOP_NAME} starting; waiting for SPEC.md"
for _ in $(seq 1 360); do [ -f "$WS/SPEC.md" ] && break; sleep 5; done
if [ ! -f "$WS/SPEC.md" ]; then
  term "no SPEC.md after 30m"; set_state blocked; exit 2
fi

git config --global credential.helper store
FORGEJO_SCHEME=$(echo "$REPO_URL" | sed -E 's#^(https?)://.*#\1#')
FORGEJO_HOST=$(echo "$REPO_URL" | sed -E 's#^https?://([^/]+)/.*#\1#')
echo "${FORGEJO_SCHEME}://loop-bot:${FORGEJO_TOKEN}@${FORGEJO_HOST}" > ~/.git-credentials
git config --global user.name "loop-bot"
git config --global user.email "loop-bot@phillips-homelab.net"

if [ ! -d "$REPO_DIR/.git" ]; then
  git clone "$REPO_URL" "$REPO_DIR" || { term "clone failed"; set_state blocked; exit 2; }
  git -C "$REPO_DIR" checkout -B "$BRANCH"
fi
if [ -n "$MEMORY_URL" ] && [ ! -d "$WS/memory/.git" ]; then
  git clone --depth 1 "$MEMORY_URL" "$WS/memory" || log "WARN memory clone failed"
fi
[ -f "$WS/PROGRESS.md" ] || printf '# PROGRESS\n\n(harness: no iterations yet)\n' > "$WS/PROGRESS.md"

PROMPT='You are one iteration of an autonomous coding loop. Read /workspace/SPEC.md (the task, checkboxes, guardrails) and /workspace/PROGRESS.md (state so far), and check /workspace/.inbox/ for operator answers to earlier decisions. Then do exactly ONE thing: the next unchecked SPEC item. Work in /workspace/repo. Follow SPEC guardrails strictly. If an item is blocked after 3 distinct attempts (see PROGRESS), write a decision file to /workspace/decisions/NNN-slug.json (fields: question, context, options[2-3], recommendation, risk) and move to the next item. Update PROGRESS.md: what you did, gate expectations, what is next, any BLOCKED items. If ALL items are done, create /workspace/.loop-done containing a one-paragraph summary, AND /workspace/PR.md: a reviewer-facing pull-request description in markdown (sections: What changed, How it was verified, Review notes — call out any tradeoffs, dependency changes, or deviations a human reviewer should scrutinize). Write PR.md for a human who has NOT read PROGRESS.md; no process narration or iteration numbers. If ALL remaining items are BLOCKED, create /workspace/.loop-blocked with a summary. Never write secrets to logs or files. Do not run git push (the harness pushes). Consult /workspace/memory/ (gotchas, conventions) if present.'

# ---- iteration loop --------------------------------------------------------
ensure_inbox_consumer
set_state running
# iteration budget survives container restarts (the workspace is a PVC)
iter=$(cat "$WS/.iter-count" 2>/dev/null || echo 0)
[ "$iter" -gt 0 ] && log "resuming at iteration $((iter+1)) after restart"
while [ "$iter" -lt "$MAX_ITER" ]; do
  iter=$((iter+1))
  echo "$iter" > "$WS/.iter-count"
  log "=== iteration ${iter}/${MAX_ITER} ==="
  drain_inbox

  claude -p "$PROMPT" \
    --dangerously-skip-permissions \
    --add-dir "$WS" \
    > "$WS/.iter-${iter}.log" 2>&1
  agent_rc=$?
  log "agent exited rc=${agent_rc} ($(wc -l < "$WS/.iter-${iter}.log") log lines)"

  # Pro-plan rate limiting: iterations draw from the shared 5h prompt window.
  # Back off without burning budget; give up after too many in a row.
  if [ "$agent_rc" -ne 0 ] && grep -qiE 'rate.?limit|usage limit|limit (reached|exceeded)' "$WS/.iter-${iter}.log"; then
    rl_count=$(( ${rl_count:-0} + 1 ))
    if [ "$rl_count" -ge "${RATE_LIMIT_MAX_BACKOFFS:-8}" ]; then
      npub done "{\"iter\":${iter},\"exhausted\":true,\"reason\":\"rate-limited\"}"
      set_state blocked; term "persistent rate limiting"; exit 3
    fi
    iter=$((iter-1))
    log "rate limited (${rl_count}); sleeping ${RATE_LIMIT_BACKOFF:-900}s, iteration not counted"
    sleep "${RATE_LIMIT_BACKOFF:-900}"
    continue
  fi
  rl_count=0

  relay_decisions

  gate_result=red
  if (cd "$REPO_DIR" && eval "$GATE_CMD") > "$WS/.gate-${iter}.log" 2>&1; then
    gate_result=green
    if ! git -C "$REPO_DIR" diff --quiet || ! git -C "$REPO_DIR" diff --cached --quiet \
       || [ -n "$(git -C "$REPO_DIR" status --porcelain)" ]; then
      git -C "$REPO_DIR" add -A
      git -C "$REPO_DIR" commit -m "loop(${LOOP_NAME}): iteration ${iter}" >/dev/null
    fi
    git -C "$REPO_DIR" push -u origin "$BRANCH" >/dev/null 2>&1 || log "WARN push failed"
  else
    log "gate RED (tail): $(tail -3 "$WS/.gate-${iter}.log" | tr '\n' ' ')"
    printf '\n> harness: iteration %s gate FAILED:\n```\n%s\n```\n' \
      "$iter" "$(tail -20 "$WS/.gate-${iter}.log")" >> "$WS/PROGRESS.md"
  fi

  npub events "{\"iter\":${iter},\"gate\":\"${gate_result}\",\"agent_rc\":${agent_rc},\"ts\":\"$(date -u +%FT%TZ)\"}"

  if [ -f "$WS/.loop-done" ]; then
    if [ "$gate_result" = green ]; then
      log "done sentinel + green gate: finishing"
      npub done "{\"iter\":${iter},\"summary\":$(jq -Rs . < "$WS/.loop-done")}"
      set_state done; term "done in ${iter} iterations"; exit 0
    fi
    log "done sentinel but gate RED: removing sentinel, continuing"
    rm -f "$WS/.loop-done"
    printf '\n> harness: .loop-done rejected, gate is red.\n' >> "$WS/PROGRESS.md"
  fi
  if [ -f "$WS/.loop-blocked" ]; then
    npub done "{\"iter\":${iter},\"blocked\":true,\"summary\":$(jq -Rs . < "$WS/.loop-blocked")}"
    set_state blocked
    # Wait in-process instead of exiting: exit 2 + restartPolicy OnFailure
    # crashloops, and each relaunch burns prompts re-assessing state. Inbox
    # polling costs nothing. Exit 2 only after the decision timeout.
    log "blocked; polling inbox for operator answers"
    waited=0
    while :; do
      if [ "$waited" -ge "${BLOCKED_TIMEOUT:-172800}" ]; then
        term "blocked after ${iter} iterations; no answer in $((waited/3600))h"
        exit 2
      fi
      sleep "${BLOCKED_POLL:-120}"; waited=$((waited + ${BLOCKED_POLL:-120}))
      before=$(ls "$WS/.inbox" 2>/dev/null | wc -l)
      drain_inbox
      after=$(ls "$WS/.inbox" 2>/dev/null | wc -l)
      if [ "$after" -gt "$before" ]; then
        log "operator answer received after ${waited}s; resuming"
        rm -f "$WS/.loop-blocked"
        set_state running
        break
      fi
    done
  fi
done

npub done "{\"iter\":${iter},\"exhausted\":true}"
set_state blocked
term "budget exhausted (${MAX_ITER} iterations)"
exit 3
