# Loop lua-dev image: Python 3.12 + shapely + Lua 5.1 + claude CLI + nats CLI + kubectl +
# harness. The Lua sibling of images/dev (Go) and images/rust-dev — first consumer is
# loop-bot/ErgoBars (Casey's WoW Forever addon + ErgoDox WoW layer), whose gate is
# `make build test lint`: wow/gen.py (tomllib + shapely) renders the keymap and Layout.lua,
# luac5.1 parses every addon file, and two linters run — the repo's wow/lint.py and the
# forever-addon-dev one, baked in at /opt/forever-addon-dev (pinned). Its reference/ folder is
# also the loop's measured API documentation for the Forever client.
# No game in here: in-game checks are Casey's, listed in each PR (loops/ERGOBARS-CONDUCTOR.md).
# Tag loop-dev:lua-<n> so `loopctl spawn --image lua-<n>` selects it.
#
# Build (house pattern, from repo root; the local buildctl client carries the zot login from
# ~/.docker/config.json — the in-pod buildctl variant has none and gets 401 on push; zot also
# rejects Docker-format manifests with 415, hence oci-mediatypes):
#   kubectl -n buildkit port-forward svc/buildkit 1234:1234 &
#   buildctl --addr tcp://127.0.0.1:1234 build \
#     --frontend dockerfile.v0 \
#     --local context=loops/images/lua-dev --local dockerfile=loops/images/lua-dev \
#     --output type=image,name=zot.phillips-homelab.net/loop-dev:lua-1,push=true,oci-mediatypes=true
# (buildctl v0.18.1 = the server's version: github.com/moby/buildkit/releases)
FROM python:3.12-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
      git make jq curl ca-certificates ripgrep unzip lua5.1 \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir shapely

# forever-addon-dev: measured Forever API reference + regex linter, pinned (2026-09-26)
ARG FAD_REF=9aa6c4d33a0eb7bea47b68336c41823d058197cc
RUN git clone -q https://github.com/imperial64/forever-addon-dev /opt/forever-addon-dev && \
    git -C /opt/forever-addon-dev checkout -q "${FAD_REF}" && rm -rf /opt/forever-addon-dev/.git && \
    chmod -R a+rX /opt/forever-addon-dev

# claude CLI (native installer drops it in ~/.local/bin; promote to PATH)
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    install -m 0755 /root/.local/bin/claude /usr/local/bin/claude && \
    rm -rf /root/.local

# nats CLI (releases ship zips)
RUN NATS_CLI_VERSION=0.4.0 && \
    curl -fsSL -o /tmp/nats.zip "https://github.com/nats-io/natscli/releases/download/v${NATS_CLI_VERSION}/nats-${NATS_CLI_VERSION}-linux-amd64.zip" && \
    unzip -q /tmp/nats.zip -d /tmp/natscli && \
    install -m 0755 /tmp/natscli/nats-*/nats /usr/local/bin/nats && rm -rf /tmp/nats.zip /tmp/natscli

# kubectl (only used to patch the loop's own Sandbox state label)
RUN KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)" && \
    curl -fsSL -o /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    chmod 0755 /usr/local/bin/kubectl

RUN useradd -m -u 1000 -s /bin/bash loop && mkdir -p /workspace && chown loop:loop /workspace
COPY harness.sh /usr/local/bin/harness.sh
RUN chmod 0755 /usr/local/bin/harness.sh
USER loop
ENV HOME=/home/loop
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/harness.sh"]
