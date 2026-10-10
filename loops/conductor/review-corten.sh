#!/usr/bin/env bash
# review-corten.sh — the mechanical review of a finished Corten loop, run by the
# conductor in a Job on the corten image (pinned dbt + shared cache baked in).
# The same checks the conductor session ran by hand before every merge:
#
#   1. the branch merges cleanly onto main (the merged tree is what gets tested)
#   2. normalization untouched (harness/normalize.py, tests/parity.rs scrub)
#   3. the gate: make build test lint
#   4. audit records reproduce: the gate's audit rewrites audit/; it must be clean
#   5. every fixture golden re-captured from the pinned dbt matches the committed one
#   6. 1000 fuzz seeds the loop never saw: no DIVERGED, no CRASH, no missed refusal
#
# Env: BRANCH, SEED_START, FORGEJO_TOKEN (loop-secrets). Local dry runs: CLONE_URL,
# WORK, and BOOTSTRAP_LINK=<a corten checkout with the harness cache>. The last line is
# "REVIEW PASS <sha>" or "REVIEW FAIL: <why>"; the conductor merges only that sha.
set -uo pipefail

fail() { echo "REVIEW FAIL: $*"; exit 1; }
step() { echo; echo "=== $*"; }
: "${BRANCH:?}" "${SEED_START:?}" "${FORGEJO_TOKEN:?}"
JOBS=${JOBS:-8}
export TZ=UTC LC_ALL=C.UTF-8 PYTHONHASHSEED=0 DBT_SEND_ANONYMOUS_USAGE_STATS=false

export GIT_AUTHOR_NAME=loop-conductor GIT_COMMITTER_NAME=loop-conductor
export GIT_AUTHOR_EMAIL=loop-conductor@phillips-homelab.net GIT_COMMITTER_EMAIL=loop-conductor@phillips-homelab.net
CLONE_URL=${CLONE_URL:-http://loop-bot:${FORGEJO_TOKEN}@forgejo-http.forgejo.svc.cluster.local:3000/loop-bot/corten.git}
WORK=${WORK:-/tmp/corten}
git clone -q "$CLONE_URL" "$WORK" || fail "clone failed"
cd "$WORK"
[ -z "${BOOTSTRAP_LINK:-}" ] || harness/bootstrap.sh --link "$BOOTSTRAP_LINK" >/dev/null  # local runs only
git checkout -q "$BRANCH" || fail "no branch $BRANCH"
SHA=$(git rev-parse HEAD)
echo "reviewing $BRANCH at $SHA (main $(git rev-parse --short origin/main))"

step "1. merge onto main"
if ! git merge-base --is-ancestor origin/main HEAD; then
  git merge -q --no-edit origin/main || fail "$BRANCH does not merge cleanly onto main"
  echo "branch was behind main; testing the merged tree"
fi

step "2. normalization untouched"
git diff --quiet origin/main HEAD -- harness/normalize.py || fail "harness/normalize.py changed"
# parity.rs mirrors normalize.py in everything above copy_dir().
scrub() { git show "$1:tests/parity.rs" | sed '/^fn copy_dir/,$d'; }
diff <(scrub origin/main) <(scrub HEAD) >/dev/null || fail "tests/parity.rs normalization changed"
git diff origin/main HEAD -- tests/parity.rs | grep -E '^[-+][^-+].*(scrub|sort_source_deps)\(' \
  && fail "tests/parity.rs changed how normalization is applied"
echo ok

step "3. gate: make build test lint"
make build test lint || fail "gate red"

step "4. audit records reproduce"
dirty=$(git status --porcelain -- audit/)
[ -z "$dirty" ] || { echo "$dirty"; git diff --stat -- audit/; fail "committed audit records do not reproduce"; }
grep -E '^\| ' audit/*/SUMMARY.md | head -20 || true
echo ok

step "5. fixture goldens re-captured from the pinned dbt"
for fx in tests/fixtures/*/; do
  name=$(basename "$fx")
  [ -f "$fx/expected_manifest.json" ] || continue
  [ -f "$fx/project/profiles.yml" ] || fail "fixture $name has no profiles.yml; cannot re-capture"
  work=$(mktemp -d)
  cp -r "$fx/project/." "$work/"
  ( cd "$work" && "$CORTEN_DBT" parse --quiet --no-partial-parse --project-dir "$work" --profiles-dir "$work" ) \
    || fail "pinned dbt rejects fixture $name"
  python3 -I harness/normalize.py "$work/target/manifest.json" "$work" "$work/golden.json" \
    || fail "normalize failed on fixture $name"
  cmp -s "$work/golden.json" "$fx/expected_manifest.json" || fail "fixture $name golden differs from the pinned dbt"
  echo "$name: matches"
  rm -rf "$work"
done

step "6. unseen fuzz seeds ${SEED_START}..$((SEED_START + 999))"
for off in 0 250 500 750; do
  python3 -I harness/fuzz.py --start $((SEED_START + off)) --seeds 250 --jobs "$JOBS" \
    || fail "fuzz chunk $((SEED_START + off)) failed (DIVERGED, CRASH or missed refusal)"
done

echo
echo "REVIEW PASS $SHA"
