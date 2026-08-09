# Loop dev image: Go toolchain + claude CLI + nats CLI + kubectl + harness.
# Build (house pattern, from repo root):
#   kubectl -n buildkit port-forward svc/buildkit 1234:1234 &
#   buildctl --addr tcp://127.0.0.1:1234 build \
#     --frontend dockerfile.v0 \
#     --local context=loops/images/dev --local dockerfile=loops/images/dev \
#     --output type=image,name=zot.phillips-homelab.net/loop-dev:$(git rev-parse --short HEAD),push=true
FROM golang:1.25-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
      git make jq curl ca-certificates ripgrep unzip fonts-dejavu-core \
      chromium \
    && rm -rf /var/lib/apt/lists/*

# claude CLI (native installer drops it in ~/.local/bin; promote to PATH)
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    install -m 0755 /root/.local/bin/claude /usr/local/bin/claude && \
    rm -rf /root/.local

# nats CLI (releases ship zips)
RUN NATS_CLI_VERSION=0.4.0 && \
    curl -fsSL -o /tmp/nats.zip "https://github.com/nats-io/natscli/releases/download/v${NATS_CLI_VERSION}/nats-${NATS_CLI_VERSION}-linux-amd64.zip" && \
    unzip -q /tmp/nats.zip -d /tmp/natscli && \
    install -m 0755 /tmp/natscli/nats-*/nats /usr/local/bin/nats && rm -rf /tmp/nats.zip /tmp/natscli

# Node 20 + pnpm, for JS/TS repos (tychofleet) whose gate runs pnpm via
# make. Baked into the image rather than downloaded per-loop into the
# /workspace PVC: a fresh sandbox must be able to pass the gate on
# iteration 1 with no network luck involved (the fleetorg loop burned 3
# iterations discovering this the hard way). corepack pins pnpm to
# whatever each repo's package.json packageManager field declares.
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    corepack enable

# OpenAI Codex CLI: the harness's ENGINE=codex lane (review-shaped
# loops on the ChatGPT-sub budget, separate from the claude token).
RUN npm install -g @openai/codex && codex --version

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
