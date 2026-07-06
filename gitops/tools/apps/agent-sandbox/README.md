# agent-sandbox

[kubernetes-sigs/agent-sandbox](https://github.com/kubernetes-sigs/agent-sandbox) —
Sandbox CRD + controller for isolated, stateful, singleton workloads (AI agent
runtimes). Pinned to **v0.5.0** (first release with `v1beta1` APIs).

## Layout

- `upstream/manifest.yaml` — core release artifact (CRD `sandboxes.agents.x-k8s.io`,
  namespace, RBAC, services). **Modified:** the controller Deployment is removed;
  the `--extensions` variant in `upstream/extensions.yaml` is the one we run
  (upstream applies the files sequentially so extensions wins; kustomize rejects
  the duplicate).
- `upstream/extensions.yaml` — verbatim release artifact: SandboxTemplate /
  SandboxClaim / SandboxWarmPool CRDs + the controller Deployment with
  `--extensions`.
- `gvisor-runtimeclass.yaml` — `runsc` RuntimeClass, scheduled to homelab-04.
  Inert until the `siderolabs/gvisor` system extension is on that node.
- `sandboxes-namespace.yaml`, `python-sandbox-template.yaml` — a `sandboxes`
  namespace with a starter Python runtime SandboxTemplate pinned to homelab-04
  via `nodeSelector`.

## Upgrading

1. Download `manifest.yaml` and `extensions.yaml` from the new release tag.
2. Re-vendor into `upstream/`, re-applying the two local modifications
   (drop the Deployment from manifest.yaml; keep the header comments).
3. `kubectl kustomize gitops/tools/apps/agent-sandbox | kubectl apply --dry-run=server -f -`

## gVisor isolation (pending)

`cluster/talos/omni/phillips-homelab/template.yaml` stages `siderolabs/gvisor`
on the gpu Workers block. It takes effect on the next
`omnictl cluster template sync` **which reboots homelab-04** (Jellyfin /
Open WebUI blip). After that, uncomment `runtimeClassName: gvisor` in
`python-sandbox-template.yaml`. Until then sandboxes run under plain runc.

## Smoke test

```bash
kubectl -n agent-sandbox-system get pods
cat <<'EOF' | kubectl apply -f -
apiVersion: agents.x-k8s.io/v1beta1
kind: Sandbox
metadata:
  name: smoke
  namespace: sandboxes
spec:
  podTemplate:
    spec:
      nodeSelector:
        kubernetes.io/hostname: homelab-04
      containers:
      - name: shell
        image: busybox:1.36
        command: ["sh", "-c", "sleep infinity"]
EOF
kubectl -n sandboxes get sandbox smoke -o wide && kubectl -n sandboxes delete sandbox smoke
```
