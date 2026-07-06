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

## gVisor isolation

The `siderolabs/gvisor` system extension is installed on homelab-04 (via the
gpu Workers block in `cluster/talos/omni/phillips-homelab/template.yaml`;
extension changes there apply via `omnictl cluster template sync`, which
reboots the node). The `python` SandboxTemplate runs sandboxes under the
`gvisor` RuntimeClass. To verify a pod is actually sandboxed, `uname -r`
inside it reports gVisor's emulated kernel, not the Talos host kernel.
Keep GPU workloads on the `nvidia` RuntimeClass — gvisor and nvidia coexist
on the node but a single pod can't use both.

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
