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
git clone -q "https://oauth2:${FORGEJO_TOKEN}@code.phillips-homelab.net/${REPO}.git" /tmp/src
cd /tmp/src
git checkout -q "$TAG" 2>/dev/null || echo "tag $TAG not a ref yet; building from default branch"
V=$(git describe --tags --always)

mkdir -p /tmp/out /tmp/stage
for pair in darwin/arm64 darwin/amd64 linux/amd64 windows/amd64; do
  os=${pair%/*}; arch=${pair#*/}
  ext=""; [ "$os" = windows ] && ext=".exe"
  # dummyscope only ships on windows: it is how a tester with no scope
  # reachable from that machine still exercises the TUI end to end
  # (`dummyscope.exe -frames-dir <dir> -launch-tui`). Elsewhere the
  # simulator is a `make mock` concern, not a release artifact.
  cmds="tycho-client fleetview"
  [ "$os" = windows ] && cmds="tycho-client fleetview dummyscope"
  for c in $cmds; do
    GOOS=$os GOARCH=$arch CGO_ENABLED=0 go build -trimpath \
      -ldflags="-s -w -X tycho.dev/agent/internal/version.Version=$V" \
      -o "/tmp/stage/${c}${ext}" "./agent/cmd/$c"
  done
  if [ "$os" = windows ]; then
    # loop-dev has `unzip` but not `zip`. A Go toolchain is guaranteed here
    # (this script cross-compiles with it), so use archive/zip rather than
    # adding an apt package and rebuilding the image for one archive.
    (cd /tmp/stage && cat > /tmp/mkzip.go <<'GOEOF'
package main

import (
	"archive/zip"
	"io"
	"os"
)

func main() {
	out, err := os.Create(os.Args[1])
	if err != nil {
		panic(err)
	}
	defer out.Close()
	w := zip.NewWriter(out)
	for _, name := range os.Args[2:] {
		f, err := os.Open(name)
		if err != nil {
			panic(err)
		}
		hdr, err := w.Create(name)
		if err != nil {
			panic(err)
		}
		if _, err := io.Copy(hdr, f); err != nil {
			panic(err)
		}
		f.Close()
	}
	if err := w.Close(); err != nil {
		panic(err)
	}
}
GOEOF
    go run /tmp/mkzip.go "/tmp/out/tycho-client-${V}-${os}-${arch}.zip" tycho-client.exe fleetview.exe dummyscope.exe)
  else
    tar -czf "/tmp/out/tycho-client-${V}-${os}-${arch}.tar.gz" -C /tmp/stage tycho-client fleetview
  fi
  rm -f /tmp/stage/tycho-client /tmp/stage/fleetview /tmp/stage/*.exe
  echo "built ${os}/${arch}"
done

BODY="Client binaries (tycho-client, fleetview) cross-built in-cluster from ${V}."
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

for f in /tmp/out/*.tar.gz /tmp/out/*.zip; do
  [ -e "$f" ] || continue
  curl -s -o /dev/null -X POST "$F/repos/${REPO}/releases/${id}/assets?name=$(basename "$f")" \
    -H "Authorization: token ${FORGEJO_TOKEN}" -F "attachment=@${f}"
  echo "attached $(basename "$f")"
done
echo "release ready: https://code.phillips-homelab.net/${REPO}/releases/tag/${TAG}"
