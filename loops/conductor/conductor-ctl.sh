#!/usr/bin/env bash
# conductor-ctl.sh — the session-side verbs for the in-cluster conductor
# (loops/conductor/conductor.sh, run by the loop-conductor-<chain> CronJob).
#
#   conductor-ctl.sh install                 push the conductor code (this dir,
#                                            loopctl, the sandbox template) to
#                                            ConfigMap loop-conductor-code
#   conductor-ctl.sh enqueue <chain> <name> <owner/repo> <image> <max_iter> <spec-file> [model]
#                                            append a loop to the chain's queue
#                                            (model: sonnet unless given, e.g. opus)
#   conductor-ctl.sh status <chain>          state, queue, spend, recent runs
#   conductor-ctl.sh cap <chain> <weekly_usd> [loop_usd]
#                                            set the spend caps (estimated USD)
#   conductor-ctl.sh resume <chain> [phase]  clear a halt (phase defaults to
#                                            running if the halted loop's sandbox
#                                            still exists, else idle)
#   conductor-ctl.sh run <chain>             run one step now instead of waiting
#                                            for the next 10-minute tick
#
# The CronJob, its ServiceAccount and Role are gitops
# (gitops/tools/apps/loops/conductor.yaml); the code and queues are runtime
# data pushed from here, like specs are pushed by loopctl spawn.
set -euo pipefail

NS=loops
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
die() { echo "conductor-ctl: $*" >&2; exit 1; }

cmd_install() {
  kubectl -n "$NS" create configmap loop-conductor-code \
    --from-file=conductor.sh="$HERE/conductor.sh" \
    --from-file=review-corten.sh="$HERE/review-corten.sh" \
    --from-file=loopctl="$ROOT/loops/bin/loopctl" \
    --from-file=loop-sandbox.yaml="$ROOT/loops/templates/loop-sandbox.yaml" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  echo "loop-conductor-code updated from $(git -C "$ROOT" rev-parse --short HEAD)$(git -C "$ROOT" diff --quiet -- loops || echo '+dirty')"
}

cmd_enqueue() {
  local chain=${1:?chain} name=${2:?name} repo=${3:?owner/repo} image=${4:?image} max_iter=${5:?max_iter} spec=${6:?spec-file} model=${7:-}
  [ -f "$spec" ] || die "no spec file $spec"
  local q=queue-$chain
  kubectl -n "$NS" get configmap "$q" >/dev/null 2>&1 || kubectl -n "$NS" create configmap "$q" --from-literal=queue= >/dev/null
  local cur
  cur=$(kubectl -n "$NS" get configmap "$q" -o json | jq -r '.data.queue // ""')
  grep -qE "^$name " <<<"$cur" && die "$name is already queued"
  kubectl -n "$NS" patch configmap "$q" --type merge -p "$(jq -cn \
    --arg q "$(printf '%s\n%s %s %s %s %s' "$cur" "$name" "$repo" "$image" "$max_iter" "$model" | sed 's/ *$//; /^$/d')" \
    --arg k "$name.md" --rawfile s "$spec" '{data: ({queue: $q} + {($k): $s})}')" >/dev/null
  echo "queued $name on $chain"
}

cmd_status() {
  local chain=${1:?chain}
  echo "=== conductor-$chain"
  kubectl -n "$NS" get configmap "conductor-$chain" -o json 2>/dev/null | jq -r '.data | to_entries[] | "  \(.key): \(.value)"' || echo "  (no state yet)"
  echo "=== queue-$chain"
  kubectl -n "$NS" get configmap "queue-$chain" -o json 2>/dev/null | jq -r '.data.queue // "" | split("\n")[] | select(length > 0) | "  " + .' || echo "  (no queue)"
  echo "=== spend-$chain (estimated USD; last 7 days count against weekly_cap_usd)"
  kubectl -n "$NS" get configmap "spend-$chain" -o json 2>/dev/null | jq -r '.data.ledger // ""' \
    | awk -v since="$(( $(date +%s) - 604800 ))" 'NF {
        printf "  %s  %-28s $%-8s %s tok\n", strftime("%F %H:%M", $1, 1), $2, $3, $4
        if ($1 >= since) s += $3 }
      END {printf "  7-day total: $%.2f\n", s}' || echo "  (no spend recorded)"
  echo "=== runs"
  kubectl -n "$NS" get jobs -l "loop.phillips.dev/conductor=$chain" --sort-by=.metadata.creationTimestamp 2>/dev/null | tail -6
  kubectl -n "$NS" get jobs -l "app.kubernetes.io/name=loop-conductor" --sort-by=.metadata.creationTimestamp 2>/dev/null | tail -3
}

cmd_resume() {
  local chain=${1:?chain} phase=${2:-}
  local loop
  loop=$(kubectl -n "$NS" get configmap "conductor-$chain" -o jsonpath='{.data.loop}')
  if [ -z "$phase" ]; then
    if [ -n "$loop" ] && kubectl -n "$NS" get sandbox "$loop" >/dev/null 2>&1; then phase=running; else phase=idle; fi
  fi
  kubectl -n "$NS" patch configmap "conductor-$chain" --type merge \
    -p "$(jq -cn --arg p "$phase" '{data: {phase: $p, note: "resumed by conductor-ctl"}}')" >/dev/null
  echo "conductor-$chain resumed in phase $phase"
}

cmd_cap() {
  local chain=${1:?chain} weekly=${2:?weekly_usd} loop=${3:-}
  local num='^[0-9]+(\.[0-9]+)?$'
  [[ $weekly =~ $num ]] && { [ -z "$loop" ] || [[ $loop =~ $num ]]; } || die "caps must be numbers"
  kubectl -n "$NS" patch configmap "conductor-$chain" --type merge -p "$(jq -cn \
    --arg w "$weekly" --arg l "$loop" '{data: ({weekly_cap_usd: $w} + (if $l == "" then {} else {loop_cap_usd: $l} end))}')" >/dev/null
  echo "conductor-$chain caps: weekly \$$weekly${loop:+, per loop \$$loop} (estimated USD)"
}

cmd_run() {
  local chain=${1:?chain} job
  job="loop-conductor-$chain-manual-$(date +%s)"
  kubectl -n "$NS" create job "$job" --from="cronjob/loop-conductor-$chain" >/dev/null
  echo "started $job; follow: kubectl -n $NS logs -f job/$job"
}

cmd=${1:-help}; shift || true
case $cmd in
  install) cmd_install "$@";;
  enqueue) cmd_enqueue "$@";;
  status) cmd_status "$@";;
  resume) cmd_resume "$@";;
  cap) cmd_cap "$@";;
  run) cmd_run "$@";;
  *) sed -n '2,23p' "$0";;
esac
