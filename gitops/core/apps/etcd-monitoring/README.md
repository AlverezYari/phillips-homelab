# etcd observability & hardening

Follow-up to the 2026-08 etcd NOSPACE incident (the 2 GiB etcd DB quota filled
and froze the cluster). The app-level cause (delivery status churn) is already
fixed. This addresses the residual etcd risks: no db-size metric was scraped,
the DB quota was still the 2 GiB default, and there is no automated defrag.

## What ArgoCD ships here

- **`vmstaticscrape.yaml`** — a `VMStaticScrape` (job `etcd`) that scrapes
  etcd's Prometheus metrics from the control-plane node on `:2381`. This makes
  `etcd_mvcc_db_total_size_in_bytes` and `up{job="etcd"}` populate, giving the
  chart-installed `vmstack-etcd` VMRule real data to alert on.

  The chart's own `vmstack-kube-etcd` VMServiceScrape does **not** work on
  Talos: it selects pods labeled `component: etcd`, but Talos runs etcd as a
  host service, not a pod — so its Service has zero endpoints. Leave it; it's
  harmless (different job name, no targets). This static scrape replaces it.

> **This scrape reads `up=0` until the Talos patch below is applied.** It
> depends on etcd's `listen-metrics-urls` being enabled on `:2381`.

## Talos changes (apply MANUALLY via Omni — NOT ArgoCD)

`cluster/talos/omni/phillips-homelab/patches/etcd-hardening.yml`, wired into the
ControlPlane block of `template.yaml`, sets two etcd flags:

| flag | value | why |
|------|-------|-----|
| `quota-backend-bytes` | `8589934592` (8 GiB) | raise from 2 GiB default; headroom above the incident |
| `listen-metrics-urls` | `http://0.0.0.0:2381` | expose etcd metrics for the scrape above |

Apply (needs the operator's PGP-authed omnictl; restarts etcd on the sole
control-plane member => brief control-plane/API pause — do deliberately):

```bash
omnictl cluster template sync \
  -f cluster/talos/omni/phillips-homelab/template.yaml
```

### Verify after apply

```bash
# metrics listener is up (was Connection-refused before)
kubectl -n monitoring run etcdprobe --rm -it --restart=Never \
  --image=curlimages/curl -- -s http://192.168.10.191:2381/metrics | head

# quota raised to 8 GiB
kubectl -n monitoring exec deploy/vmsingle-vmstack -- \
  wget -qO- 'http://localhost:8429/api/v1/query?query=etcd_server_quota_backend_bytes'
# => 8589934592

# db size + target are now scraped
#   up{job="etcd"} == 1
#   etcd_mvcc_db_total_size_in_bytes present
```

## Defrag — MANUAL, do NOT automate (yet)

etcd's on-disk file only shrinks after a `defrag`, and defrag **blocks the
member it runs against**. This cluster has a **single** etcd member, so a
defrag briefly freezes the entire control plane. An in-cluster CronJob is
deliberately **not** shipped because:

1. `etcdctl defrag` needs the etcd client cert (mutual-TLS on `:2379`) from
   `/system/secrets/etcd/*` on the node. Those certs can't be managed
   declaratively here and they rotate — a stale secret would be a silent
   failure at best.
2. With one member, a wedged/slow defrag takes the whole API down. Not worth
   automating unattended.

Run it manually, deliberately, off-peak, using Talos's native command (it uses
the node's own etcd certs — no secret wrangling):

```bash
# defrag the etcd member on the control-plane node
talosctl -n 192.168.10.191 etcd defrag
```

Revisit an automated weekly, one-member-at-a-time CronJob only if/when the
control plane grows to 3 etcd members (defrag one, wait, next). Until then the
8 GiB quota + the db-size alerting above are the guardrails.
