# Loop corten-dev image: rust-dev (Rust toolchain + claude + nats + kubectl + harness)
# plus the pinned dbt and Corten's shared harness cache, so loop-bot/corten's gate
# (`make build test lint`: unit tests, corpus audit against dbt, differential fuzzing)
# runs with no network. Tag loop-dev:corten-<n>; spawn with `--image corten-<n>`.
#
# The build context is NOT in this repo. Produce it from a Corten checkout whose harness
# is bootstrapped (pinned corpus repos + package snapshots present):
#
#   cd /mnt/nix-projects/corten && harness/export_image_context.sh /tmp/corten-ctx
#   cp loops/images/corten-dev/Dockerfile /tmp/corten-ctx/
#
# then build like rust-dev (in-pod buildctl):
#   kubectl -n buildkit cp /tmp/corten-ctx <pod>:/tmp/corten-ctx
#   kubectl -n buildkit exec <pod> -- buildctl build \
#     --frontend dockerfile.v0 \
#     --local context=/tmp/corten-ctx --local dockerfile=/tmp/corten-ctx \
#     --output type=image,name=zot.phillips-homelab.net/loop-dev:corten-1,push=true
#
# Context contents: requirements.lock (dbt's full pinned dependency tree), shared/ (pinned
# corpus repos and installed-package snapshots), shared.sha256 (content hash of shared/,
# also baked into the image for the record).
FROM zot.phillips-homelab.net/loop-dev:rust-2

USER root
RUN apt-get update && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*

# uv fetches the exact CPython the harness was built against (3.12) into /opt; the dbt
# venv comes from the full lock, not just the top-level pins.
ENV UV_PYTHON_INSTALL_DIR=/opt/corten/python
COPY requirements.lock /opt/corten/requirements.lock
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin INSTALLER_NO_MODIFY_PATH=1 sh && \
    uv venv --python 3.12 /opt/corten/venv && \
    uv pip install --python /opt/corten/venv/bin/python -r /opt/corten/requirements.lock && \
    /opt/corten/venv/bin/dbt --version | grep -q 'installed: 1.12.5' && \
    chmod -R a+rX /opt/corten

# Pinned corpus repos + package snapshots (read-only for the loop). The repos are owned by
# root; without safe.directory git refuses to read them as the loop user.
COPY shared /opt/corten/shared
COPY shared.sha256 /opt/corten/shared.sha256
RUN git config --system --add safe.directory '*' && chmod -R a+rX /opt/corten/shared

ENV CORTEN_DBT=/opt/corten/venv/bin/dbt \
    CORTEN_SHARED=/opt/corten/shared \
    DBT_SEND_ANONYMOUS_USAGE_STATS=false
USER loop
