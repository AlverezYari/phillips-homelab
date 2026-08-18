#!/usr/bin/env bash
# publish-client.sh — the ENTIRE client release flow, one command:
#
#   op signin            # the only human step (any tab, once)
#   publish-client.sh v0.10.0
#
# Idempotent: every step checks whether it's already done and skips.
# Steps: verify tag on main -> Forgejo release + assets (loopctl
# release, in-cluster) -> local dist build (scripts/release.sh) ->
# public-bucket publish (release-publish, creds pulled from 1Password
# at exec time, never displayed, never persisted) -> verify the public
# manifest flipped.
#
# Publishing to the public bucket stays a human-KICKED step by design
# (dev dark mode: merged != released); it is no longer a human-ASSEMBLED
# one. Move into CI/Dagger later only with an explicit approval gate.
set -euo pipefail

VERSION=${1:?usage: publish-client.sh vX.Y.Z [title...]}
shift || true
TITLE=${*:-"Tycho client $VERSION"}

REPO_DIR=${TYCHO_REPO:-/mnt/nix-projects/tycho}
LOOPCTL=$(dirname "$0")/loopctl
export KUBECONFIG=${KUBECONFIG:-$HOME/.kube/tycho-sa.yaml}

# 1Password source of the Backblaze B2 releases key. The AWS_* env
# names are the S3-SDK convention release-publish reads; the values are
# the B2 key. Override labels via env if the item changes.
OP_ITEM=${OP_ITEM:-tycho}
OP_FIELD_KEY_ID=${OP_FIELD_KEY_ID:-b2_releases_key_id}
OP_FIELD_APP_KEY=${OP_FIELD_APP_KEY:-b2_releases_application_key}

say() { printf '\n== %s\n' "$*"; }

say "op session"
op whoami >/dev/null 2>&1 || { echo "not signed in — run: op signin"; exit 1; }
op item get "$OP_ITEM" --fields "label=$OP_FIELD_KEY_ID" >/dev/null 2>&1 || {
  echo "field '$OP_FIELD_KEY_ID' not found on item '$OP_ITEM'. Available labels:"
  op item get "$OP_ITEM" --format json | python3 -c 'import json,sys; [print(" -",f.get("label")) for f in json.load(sys.stdin).get("fields",[])]'
  echo "set OP_FIELD_KEY_ID / OP_FIELD_APP_KEY and re-run"; exit 1; }

say "tag $VERSION on origin/main"
cd "$REPO_DIR"
git fetch -q origin main "refs/tags/$VERSION:refs/tags/$VERSION" 2>/dev/null || git fetch -q origin main
if git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null; then
  git merge-base --is-ancestor "refs/tags/$VERSION" origin/main \
    || { echo "tag exists but is NOT on origin/main — refusing"; exit 1; }
  echo "tag exists on main"
else
  echo "tag will be created from origin/main by the release helper"
fi

say "Forgejo release + assets (in-cluster)"
"$LOOPCTL" release loop-bot/tycho "$VERSION" "$TITLE" \
  || { echo "loopctl release failed — see output above"; exit 1; }

say "local dist build"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
git worktree add -q "$WORK" "refs/tags/$VERSION" 2>/dev/null || git worktree add -q "$WORK" origin/main
( cd "$WORK" && make release VERSION="$VERSION" ) || { git worktree remove -f "$WORK"; exit 1; }

say "publish to public bucket (creds via op, not displayed)"
( cd "$WORK" && \
  AWS_ACCESS_KEY_ID=$(op item get "$OP_ITEM" --fields "label=$OP_FIELD_KEY_ID" --reveal) \
  AWS_SECRET_ACCESS_KEY=$(op item get "$OP_ITEM" --fields "label=$OP_FIELD_APP_KEY" --reveal) \
  make release-publish VERSION="$VERSION" )
git worktree remove -f "$WORK" 2>/dev/null || true
trap - EXIT

say "verify public manifest"
for i in 1 2 3; do
  latest=$(curl -s https://tychofleet.com/dl/manifest.json | python3 -c 'import json,sys; print(json.load(sys.stdin).get("latest",""))' 2>/dev/null || true)
  [ "$latest" = "$VERSION" ] && { echo "PUBLIC: latest=$latest — live on tychofleet.com/download"; exit 0; }
  sleep 5
done
echo "manifest still shows '$latest' — check CDN cache or publish output"; exit 1
