#!/usr/bin/env bash
# conductor.sh — chains loops in-cluster, so a queue of written specs keeps
# running when no Claude session is watching. Run by the loop-conductor
# CronJob every 10 minutes; each run advances one chain by at most one step
# and exits. All state is in ConfigMaps, so a run can die anywhere and the
# next one picks up.
#
#   conductor.sh <chain>
#
# ConfigMap queue-<chain>   (written by loops/conductor/enqueue.sh)
#   queue: one loop per line, "name owner/repo image max_iter", run top-down
#   <name>.md: that loop's SPEC
# ConfigMap conductor-<chain>   (owned by this script)
#   phase: idle | running | reviewing | halted
#   loop, job, next_seed, note
#
# The step for each phase:
#   idle       spawn the head of the queue (nothing queued: stay idle)
#   running    sandbox state done -> reap (files the PR), start the review Job
#              blocked / exhausted / gone -> halt
#   reviewing  Job passed -> merge exactly the reviewed sha, go idle and spawn
#              Job failed -> comment the review log on the PR, halt
#   halted     nothing. A person (or a Claude session) reads the note, fixes
#              things and resumes:  conductor-ctl.sh <chain> resume
#
# Every halt and every merge pings the phone. Any unexpected error halts too:
# stopping is always the safe failure.
set -euo pipefail

CHAIN=${1:?usage: conductor.sh <chain>}
NS=loops
STATE=conductor-$CHAIN
QUEUE=queue-$CHAIN
LOOPCTL=${LOOPCTL:-loopctl}
REVIEW_IMAGE=${REVIEW_IMAGE:-zot.phillips-homelab.net/loop-dev:corten-1}
REVIEW_SCRIPT=${REVIEW_SCRIPT:-review-$CHAIN.sh}
NTFY_URL=${NTFY_URL:-http://ntfy.stock-bot.svc.cluster.local/loops}
FJO_API=${FJO_API:-http://forgejo-http.forgejo.svc.cluster.local:3000/api/v1}
export NTFY_URL

log() { echo "[conductor $CHAIN $(date -u +%H:%M:%S)] $*"; }
ping_phone() { curl -s -m 10 -H "Title: $1" -H "Tags: $2" -d "$3" "$NTFY_URL" >/dev/null 2>&1 || true; }

get() { kubectl -n "$NS" get configmap "$1" -o json | jq -r --arg k "$2" '.data[$k] // empty'; }
# set k v [k v ...] on the state ConfigMap
set_state() {
  local patch='{}'
  while [ $# -gt 0 ]; do patch=$(jq -c --arg k "$1" --arg v "$2" '.[$k] = $v' <<<"$patch"); shift 2; done
  kubectl -n "$NS" patch configmap "$STATE" --type merge -p "{\"data\": $patch}" >/dev/null
}
halt() {
  trap - EXIT
  log "HALT: $*"
  set_state phase halted note "$*"
  ping_phone "Conductor halted: $CHAIN" "octagonal_sign" "$*"
  exit 0
}
# set -e exits on any unexpected failure; turn that exit into a halt.
trap 'rc=$?; [ $rc -eq 0 ] || halt "conductor error (exit $rc); see: kubectl -n loops logs job/<latest loop-conductor-$CHAIN run>"' EXIT

fjo() { # fjo METHOD path [json]
  curl -s -m 30 -X "$1" "$FJO_API$2" -H "Authorization: token ${FORGEJO_TOKEN}" \
    -H 'Content-Type: application/json' ${3:+-d "$3"}
}

kubectl -n "$NS" get configmap "$STATE" >/dev/null 2>&1 \
  || kubectl -n "$NS" create configmap "$STATE" --from-literal=phase=idle --from-literal=next_seed=100000 >/dev/null
phase=$(get "$STATE" phase)
loop=$(get "$STATE" loop)
log "phase=$phase loop=${loop:-none}"

spawn_next() {
  local line name repo image max_iter rest spec
  line=$(get "$QUEUE" queue | sed '/^[[:space:]]*\(#\|$\)/d' | head -1)
  [ -n "$line" ] || { log "queue empty"; set_state phase idle loop ""; return; }
  read -r name repo image max_iter <<<"$line"
  spec=$(mktemp)
  get "$QUEUE" "$name.md" >"$spec"
  [ -s "$spec" ] || halt "queue head $name has no $name.md in $QUEUE"
  # Pop before spawning: a crash mid-spawn must not spawn the same loop twice.
  rest=$(get "$QUEUE" queue | awk -v l="$line" '!done && $0 == l {done=1; next} {print}')
  kubectl -n "$NS" patch configmap "$QUEUE" --type merge \
    -p "$(jq -cn --arg q "$rest" '{data: {queue: $q}}')" >/dev/null
  set_state phase running loop "$name" job "" note "spawning"
  log "spawning $name ($repo, $image, max $max_iter)"
  "$LOOPCTL" spawn "$name" "$repo" --spec "$spec" --max-iter "$max_iter" --image "$image" \
    || halt "spawn of $name failed"
  set_state note "spawned $(date -u +%FT%TZ)"
}

start_review() {
  local seed job
  seed=$(get "$STATE" next_seed)
  job="review-$loop"
  kubectl -n "$NS" delete job "$job" --ignore-not-found >/dev/null
  cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: $job
  namespace: $NS
  labels: {loop.phillips.dev/conductor: $CHAIN}
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 14400
  ttlSecondsAfterFinished: 604800
  template:
    metadata:
      labels: {loop.phillips.dev/conductor: $CHAIN}
    spec:
      restartPolicy: Never
      nodeSelector: {kubernetes.io/hostname: homelab-04}
      containers:
      - name: review
        image: $REVIEW_IMAGE
        envFrom: [{secretRef: {name: loop-secrets}}]
        env:
        - {name: BRANCH, value: "loop/$loop"}
        - {name: SEED_START, value: "$seed"}
        - {name: JOBS, value: "8"}
        command: [bash, /conductor/$REVIEW_SCRIPT]
        resources:
          requests: {cpu: "4", memory: 8Gi}
          limits: {cpu: "8", memory: 16Gi}
        volumeMounts: [{name: code, mountPath: /conductor}]
      volumes:
      - name: code
        configMap: {name: loop-conductor-code}
EOF
  set_state phase reviewing job "$job" next_seed "$((seed + 1000))" note "review seeds $seed..$((seed + 999))"
  log "review job $job started (seeds $seed..$((seed + 999)))"
}

pr_for() { # open PR number for loop/<name> in repo
  fjo GET "/repos/$1/pulls?state=open&limit=50" | jq -r --arg b "loop/$2" '.[] | select(.head.ref == $b) | .number' | head -1
}

case "$phase" in
  halted)
    log "halted: $(get "$STATE" note)"
    ;;

  idle)
    spawn_next
    ;;

  running)
    state=$(kubectl -n "$NS" get sandbox "$loop" -o jsonpath='{.metadata.labels.loop\.phillips\.dev/state}' 2>/dev/null || echo gone)
    log "sandbox $loop: ${state:-unknown}"
    case "$state" in
      starting|running|"") ;;
      done)
        repo=$(kubectl -n "$NS" get sandbox "$loop" -o jsonpath='{.spec.podTemplate.spec.containers[0].env[?(@.name=="REPO_URL")].value}' \
          | sed -E 's#.*/([^/]+/[^/]+)\.git#\1#')
        set_state repo "$repo"
        "$LOOPCTL" reap "$loop" || halt "reap of $loop failed"
        start_review
        ;;
      *)
        halt "loop $loop ended '$state' (not done); sandbox kept for inspection: loopctl status $loop"
        ;;
    esac
    ;;

  reviewing)
    job=$(get "$STATE" job)
    repo=$(get "$STATE" repo)
    succeeded=$(kubectl -n "$NS" get job "$job" -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "")
    failed=$(kubectl -n "$NS" get job "$job" -o jsonpath='{.status.failed}' 2>/dev/null || echo "")
    if [ -z "$succeeded$failed" ]; then
      kubectl -n "$NS" get job "$job" >/dev/null 2>&1 || halt "review job $job disappeared"
      log "review $job still running"; exit 0
    fi
    out=$(kubectl -n "$NS" logs "job/$job" --tail=4000 2>/dev/null || true)
    verdict=$(grep -E '^REVIEW (PASS|FAIL)' <<<"$out" | tail -1 || true)
    pr=$(pr_for "$repo" "$loop")
    [ -n "$pr" ] || halt "review of $loop finished ($verdict) but no open PR for loop/$loop in $repo"
    # The review log goes on the PR either way: it is the merge's evidence.
    body=$(printf '## Conductor review: %s\n\n```\n%s\n```\n' "$verdict" "$(tail -c 60000 <<<"$out")")
    fjo POST "/repos/$repo/issues/$pr/comments" "$(jq -cn --arg b "$body" '{body: $b}')" >/dev/null
    case "$verdict" in
      "REVIEW PASS "*)
        sha=${verdict#REVIEW PASS }
        # head_commit_id: Forgejo refuses the merge if the PR moved since the review.
        code=$(curl -s -m 60 -o /tmp/merge -w '%{http_code}' -X POST "$FJO_API/repos/$repo/pulls/$pr/merge" \
          -H "Authorization: token ${FORGEJO_TOKEN}" -H 'Content-Type: application/json' \
          -d "$(jq -cn --arg s "$sha" '{Do: "merge", head_commit_id: $s}')")
        [ "$code" = 200 ] || halt "review passed but merge of $repo#$pr refused ($code): $(head -c 200 /tmp/merge)"
        log "merged $repo#$pr at $sha"
        ping_phone "Merged: $loop" "white_check_mark" "$repo#$pr passed the conductor review and merged. Next in queue spawns now."
        set_state phase idle loop "" job "" note "merged $repo#$pr"
        loop=""
        spawn_next
        ;;
      *)
        halt "review of $loop failed: ${verdict:-no verdict (job died?)}. Log is on $repo#$pr"
        ;;
    esac
    ;;

  *)
    halt "unknown phase '$phase'"
    ;;
esac
