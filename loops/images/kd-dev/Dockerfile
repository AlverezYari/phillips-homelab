# Loop kd-dev image: corten-3 (Rust toolchain, claude, harness, uv) plus a pinned
# Python venv for the kd repo's conformance-driver tests, so `scripts/test_driver.sh`
# runs pytest inside the loop instead of skipping (the sandbox has no PyPI access).
# kd-2 added headless Chromium, fonts and `websockets` (in the driver venv) so UI loops can
# screenshot the console over CDP and look at the PNGs; the screenshot script lives in the kd repo.
# Tag loop-dev:kd-<n>; spawn with `--image kd-<n>`.
#
# No build context beyond this file. Build from the laptop through the in-cluster buildkit
# (see ../corten-dev/Dockerfile for the port-forward, buildctl v0.18.1 and zot notes):
#   buildctl --addr tcp://127.0.0.1:1234 build --frontend dockerfile.v0 \
#     --local context=loops/images/kd-dev --local dockerfile=loops/images/kd-dev \
#     --output type=image,name=zot.phillips-homelab.net/loop-dev:kd-3,push=true,oci-mediatypes=true
FROM zot.phillips-homelab.net/loop-dev:corten-3

USER root
# Same pins as the kd repo's scripts/test_driver.sh and the driver Job.
RUN uv venv --python 3.12 /opt/kd/driver-venv && \
    uv pip install --python /opt/kd/driver-venv/bin/python \
      pytest==8.3.5 httpx==0.28.1 pyparsing==3.2.5 && \
    /opt/kd/driver-venv/bin/python -c "import pytest, httpx, pyparsing" && \
    chmod -R a+rX /opt/kd
ENV KD_DRIVER_PY=/opt/kd/driver-venv/bin/python
RUN apt-get update && apt-get install -y --no-install-recommends \
      chromium fonts-dejavu-core fonts-liberation fonts-noto-core \
    && rm -rf /var/lib/apt/lists/* && chromium --version && \
    uv pip install --python /opt/kd/driver-venv/bin/python websockets==15.0.1 && \
    /opt/kd/driver-venv/bin/python -c "import websockets"
ENV KD_CHROMIUM=/usr/bin/chromium
USER loop
