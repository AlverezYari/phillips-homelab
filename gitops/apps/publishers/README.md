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
# Straight to the API server: the Omni proxy URL in the default kubeconfig only
# accepts Omni identities and rejects SA tokens (x509 / Unauthorized).
SERVER=https://192.168.10.191:6443
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
# `can-i create pods/exec` means "a pod named exec"; use --subresource.
kubectl auth can-i create pods --subresource=exec -n ergobars               # yes
kubectl auth can-i get secret/ergobars-board -n ergobars                    # yes
kubectl auth can-i create pods/row-realm3-0 --subresource=exec -n row-realm # yes
kubectl auth can-i create pods/row-pg-1 --subresource=exec -n row-realm     # no
kubectl auth can-i delete pods -n ergobars                      # no
kubectl auth can-i get secrets -n ergobars                      # no
kubectl auth can-i list namespaces                              # no
```
