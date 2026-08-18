# Loop rust-dev image: Rust toolchain + claude CLI + nats CLI + kubectl +
# harness. The Rust sibling of images/dev (Go) — first consumer is
# loop-bot/OpenSteamController, whose gate needs cargo + clippy + rustfmt
# and the native headers for hidapi (libudev) and the dbus crate
# (libdbus-1). Same push pattern as images/dev, tag loop-dev:rust-<n> so
# `loopctl spawn --image rust-<n>` selects it.
#
# Build (in-pod variant of the house pattern — no local buildctl needed):
#   kubectl -n buildkit cp loops/images/rust-dev <pod>:/tmp/rust-ctx
#   kubectl -n buildkit exec <pod> -- buildctl build \
#     --frontend dockerfile.v0 \
#     --local context=/tmp/rust-ctx --local dockerfile=/tmp/rust-ctx \
#     --output type=image,name=zot.phillips-homelab.net/loop-dev:rust-1,push=true
FROM rust:1-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
      git make jq curl ca-certificates ripgrep unzip \
      pkg-config libudev-dev libdbus-1-dev \
    && rm -rf /var/lib/apt/lists/*

RUN rustup component add clippy rustfmt

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

# The loop user must own a writable cargo home; the base image's
# /usr/local/cargo is root's. Registry cache lands in /workspace (PVC)
# via CARGO_HOME so iteration 2+ doesn't re-download the world.
RUN useradd -m -u 1000 -s /bin/bash loop && mkdir -p /workspace && chown loop:loop /workspace && \
    chmod -R a+rX /usr/local/rustup /usr/local/cargo
COPY harness.sh /usr/local/bin/harness.sh
RUN chmod 0755 /usr/local/bin/harness.sh
USER loop
ENV HOME=/home/loop
ENV CARGO_HOME=/workspace/.cargo
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/harness.sh"]
