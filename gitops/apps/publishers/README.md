# publishers

Non-human `ServiceAccount` `publishers/row-publisher`, so the coordinator can
publish ErgoBars and RoW without Casey's personal (expiring OIDC) login.
No cluster-wide rights; one Role per target namespace.

| Namespace   | Grants | Used by |
|-------------|--------|---------|
| `ergobars`  | `pods` get/list, `pods/exec` create, `secrets` get on `ergobars-board` only | `make publish` (`kubectl cp` into `uploader:/srv/site`), `make announce` (`BOARD_ADMIN_TOKEN`) |
| `row-realm` | `pods` get and `pods/exec` create, both on `row-realm3-0` only | `bin/row-dist-upload` (`row-serve:/dist`, incl. `--via kubectl`) |

Caveats RBAC cannot narrow further:

- Exec cannot be pinned to a container, and the ErgoBars site pod name is
  generated, so in `ergobars` the SA can exec into any pod, including the
  board (whose env holds the board secrets).
- `secrets get` on `ergobars-board` returns every key in it, not only
  `BOARD_ADMIN_TOKEN` (also the TypeSafe key and Discord bot token).

Realm deploys (`kubectl apply -k row-realm`) are not granted here; they stay on
Casey's own credentials.

## Token and kubeconfig

`row-publisher-token` is a `kubernetes.io/service-account-token` Secret: a
long-lived token with no expiry. The kubeconfig lives at
`~/.kube/row-publisher.yaml` (mode 600) on the dev box and is never committed.
To (re)write it:

```sh
TOKEN=$(kubectl -n publishers get secret row-publisher-token -o jsonpath='{.data.token}' | base64 -d)
kubectl -n publishers get secret row-publisher-token -o jsonpath='{.data.ca\.crt}' | base64 -d > /tmp/ca.crt
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
F=~/.kube/row-publisher.yaml; umask 077
kubectl --kubeconfig=$F config set-cluster phillips-homelab --server="$SERVER" --certificate-authority=/tmp/ca.crt --embed-certs
kubectl --kubeconfig=$F config set-credentials row-publisher --token="$TOKEN"
kubectl --kubeconfig=$F config set-context row-publisher --cluster=phillips-homelab --user=row-publisher --namespace=ergobars
kubectl --kubeconfig=$F config use-context row-publisher
rm /tmp/ca.crt
```

Rotate (leak, or routine): `kubectl -n publishers delete secret
row-publisher-token`; Argo recreates it, the token controller mints a new
token, and the old one stops working. Then rerun the block above.

## Check

```sh
export KUBECONFIG=~/.kube/row-publisher.yaml
kubectl auth can-i create pods/exec -n ergobars                 # yes
kubectl auth can-i get secret/ergobars-board -n ergobars        # yes
kubectl auth can-i create pods/exec/row-realm3-0 -n row-realm   # yes
kubectl auth can-i delete pods -n ergobars                      # no
kubectl auth can-i get secrets -n ergobars                      # no
kubectl auth can-i list namespaces                              # no
```

## row-coordinator (2026-11-03)

`publishers/row-coordinator` (`row-coordinator.yaml`) lets the RoW coordinator drive the Sol lanes and read the live
realm with a non-expiring token instead of Casey's OIDC login (which expired overnight and stalled supervision).

| Namespace   | Grants | Used by |
|-------------|--------|---------|
| `loops`     | `pods`, `pods/log` get and `pods/exec` create, all on `row-sol` only | briefs, chain scripts, STATUS, client builds in the Sol pod |
| `row-realm` | `pods`, `pods/log` get/list/watch; `pods/exec` create on `row-realm3-0` and `row-pg-1`; `statefulsets` get on `row-realm3` | rollout checks, startup logs, content reports, read-only SQL and `pg_dump` backups |

Not granted: realm deploys (`kubectl apply -k row-realm`), deleting pods, secrets, anything cluster-wide.
Caveat: exec into `row-pg-1` is a shell in the database pod, so it can write the database; the coordinator's rules
keep live writes to backed-up scripts Casey runs.

Kubeconfig: the same block as above with `row-publisher` replaced by `row-coordinator`, written to
`~/.kube/row-coordinator.yaml` (mode 600, never committed), context namespace `loops`. Rotate the same way
(`kubectl -n publishers delete secret row-coordinator-token`, then rewrite).

```sh
export KUBECONFIG=~/.kube/row-coordinator.yaml
kubectl auth can-i create pods/exec/row-sol -n loops            # yes
kubectl auth can-i create pods/exec/row-pg-1 -n row-realm       # yes
kubectl auth can-i get pods/log -n row-realm                    # yes
kubectl auth can-i patch statefulsets -n row-realm              # no
kubectl auth can-i delete pods -n row-realm                     # no
kubectl auth can-i get secrets -n publishers                    # no
```
