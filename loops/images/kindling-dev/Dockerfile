# Loop kindling-dev image: corten-3 (Rust toolchain, claude, harness, uv) plus a pinned
# Python venv for loop-bot/kindling's conformance-driver tests, so `scripts/test_driver.sh`
# runs pytest inside the loop instead of skipping (the sandbox has no PyPI access).
# Tag loop-dev:kindling-<n>; spawn with `--image kindling-<n>`.
#
# No build context beyond this file. Build from the laptop through the in-cluster buildkit
# (see ../corten-dev/Dockerfile for the port-forward, buildctl v0.18.1 and zot notes):
#   buildctl --addr tcp://127.0.0.1:1234 build --frontend dockerfile.v0 \
#     --local context=loops/images/kindling-dev --local dockerfile=loops/images/kindling-dev \
#     --output type=image,name=zot.phillips-homelab.net/loop-dev:kindling-1,push=true,oci-mediatypes=true
FROM zot.phillips-homelab.net/loop-dev:corten-3

USER root
# Same pins as kindling's scripts/test_driver.sh and the driver Job.
RUN uv venv --python 3.12 /opt/kindling/driver-venv && \
    uv pip install --python /opt/kindling/driver-venv/bin/python \
      pytest==8.3.5 httpx==0.28.1 pyparsing==3.2.5 && \
    /opt/kindling/driver-venv/bin/python -c "import pytest, httpx, pyparsing" && \
    chmod -R a+rX /opt/kindling
ENV KINDLING_DRIVER_PY=/opt/kindling/driver-venv/bin/python
USER loop
