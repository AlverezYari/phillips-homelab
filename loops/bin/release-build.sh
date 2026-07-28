#!/usr/bin/env bash
# Runs INSIDE a loopctl helper pod (loop-dev image: Go toolchain, jq,
# curl, git). Clones the repo with the in-cluster FJO token, cross-builds
# the client binaries, creates or reuses a release, and attaches the
# archives. Source, toolchain and token all stay in-cluster, matching
# every other loopctl verb's invariant.
#
# Env in: REPO (owner/repo), TAG, TITLE, FORGEJO_TOKEN (from loop-secrets).
set -euo pipefail

F=http://forgejo-http.forgejo.svc.cluster.local:3000/api/v1
git clone -q "https://oauth2:${FORGEJO_TOKEN}@code.phillips-homelab.net/${REPO}.git" /src
cd /src
git checkout -q "$TAG" 2>/dev/null || echo "tag $TAG not a ref yet; building from default branch"
V=$(git describe --tags --always)

mkdir -p /out /stage
for pair in darwin/arm64 darwin/amd64 linux/amd64; do
  os=${pair%/*}; arch=${pair#*/}
  for c in scopetui fleetview; do
    GOOS=$os GOARCH=$arch CGO_ENABLED=0 go build -trimpath \
      -ldflags="-s -w -X tycho.dev/agent/internal/version.Version=$V" \
      -o "/stage/$c" "./agent/cmd/$c"
  done
  tar -czf "/out/tycho-${V}-${os}-${arch}.tar.gz" -C /stage scopetui fleetview
  rm -f /stage/scopetui /stage/fleetview
  echo "built ${os}/${arch}"
done

BODY="Client binaries (scopetui, fleetview) cross-built in-cluster from ${V}."
PAYLOAD=$(jq -n --arg t "$TAG" --arg n "$TITLE" --arg b "$BODY" \
  '{tag_name:$t, name:$n, body:$b, draft:false, prerelease:true}')
code=$(curl -s -o /tmp/r -w '%{http_code}' -X POST "$F/repos/${REPO}/releases" \
  -H "Authorization: token ${FORGEJO_TOKEN}" -H 'Content-Type: application/json' -d "$PAYLOAD")
case "$code" in
  201) id=$(jq -r .id /tmp/r) ;;
  409|422) id=$(curl -s "$F/repos/${REPO}/releases/tags/${TAG}" -H "Authorization: token ${FORGEJO_TOKEN}" | jq -r .id)
           echo "release exists; attaching to it" ;;
  *) echo "release create failed: $code"; head -c 300 /tmp/r; exit 1 ;;
esac

for f in /out/*.tar.gz; do
  curl -s -o /dev/null -X POST "$F/repos/${REPO}/releases/${id}/assets?name=$(basename "$f")" \
    -H "Authorization: token ${FORGEJO_TOKEN}" -F "attachment=@${f}"
  echo "attached $(basename "$f")"
done
echo "release ready: https://code.phillips-homelab.net/${REPO}/releases/tag/${TAG}"
