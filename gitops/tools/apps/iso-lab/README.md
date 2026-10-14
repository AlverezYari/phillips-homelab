# iso-lab

ISO Market Data Lab: public MISO market data. dlt lands raw Parquet on Garage
(`s3://iso-market-data/raw/miso/...`, every field a string, append-only), dbt builds typed,
tested tables in ClickHouse (database `iso`), and Dagster orchestrates both. Code and image:
private repo `AlverezYari/iso-market-data-lab` (`zot.phillips-homelab.net/iso-lab:<sha>`). These
manifests are vendored from that repo's `deploy/k8s/`; this copy is what runs.

| App | What |
|---|---|
| `iso-lab-db` | namespace `iso-lab`, CNPG `iso-lab-pg` (Dagster run/event storage only) |
| `iso-lab` | ClickHouse StatefulSet, ExternalSecrets `iso-lab-env` / `iso-lab-mcp`, the MCP server (`mcp-clickhouse`), CiliumNetworkPolicies, ReferenceGrant for the gateway routes |
| `iso-lab-dagster` | Dagster Helm chart 1.13.25. Runs execute in the `iso-lab` code-server pod (DefaultRunLauncher): dlt every 2 min, dbt after it, freshness checks every 5 min |

Outside these apps, in core: the blocky mapping, `dagster-tls` Certificate, and the `tls-gateway`
listener https-13 + HTTPRoute for **https://dagster.phillips-homelab.net** (LAN only, not on the
Cloudflare tunnel). Glance has a link.

- **MCP server:** https://iso-mcp.phillips-homelab.net/mcp runs ClickHouse's official `mcp-clickhouse` (tools
  `run_query`, `list_databases`, `list_tables`) as the read-only user `iso_ro`, behind a bearer token
  (1Password `iso-lab` / `mcp_auth_token`). Gateway listener https-14. Connect Claude Code with
  `claude mcp add --transport http iso https://iso-mcp.phillips-homelab.net/mcp --header "Authorization: Bearer <token>"`.
- **Analysis MCP server:** https://iso-analysis.phillips-homelab.net/mcp. `iso-analysis` (code `iso_lab.analysis`, same
  image as the code server) serves fixed-schema tools: `list_metrics`, `rollup`, `regression`,
  `cointegration`, `anomaly` and `seasonality`. None takes SQL or code. It runs under the **gVisor**
  RuntimeClass (homelab-04), reads ClickHouse as `iso_ro`, and its network policy allows gateway in and
  ClickHouse out only. It uses the same bearer token as `iso-mcp`. Gateway listener https-15.
- **Deploy a new build:** bump `tag:` in `../iso-lab-dagster.yml` *and* `images:` in `kustomization.yaml`
  (iso-analysis runs the same image).
- **Secrets:** 1Password item `iso-lab` (vault `phillips-homelab`), created by `deploy/k8s/provision.sh`
  in the code repo. That script also created Garage bucket `iso-market-data` and key `iso-lab`.
- **Alerts:** failed runs (schema drift, MISO down, dbt test failures, stale data) push to ntfy topic
  `iso-lab` on the homelab ntfy (tools/apps/ntfy).
- **ClickHouse:** in-cluster only. `iso` is the pipeline user, `iso_ro` the read-only user for the
  MCP server. It's rebuildable from the lake (`dbt build --full-refresh`), so one replica on iSCSI is
  deliberate. Garage requires SigV4 region `garage`, which `clickhouse/lake.xml` sets.
- **Network:** only the code-server pod (`iso-lab/role: ingest`) has internet egress, limited to
  `*.misoenergy.org` by toFQDNs. It may also reach Garage, ClickHouse, its Postgres and ntfy.
  ClickHouse may reach only Garage. Webserver and daemon have no policy yet.

## Pausing and rehydrating

**History:** paused 2026-10-14 20:43 UTC (#637; tunnel off in #638), rehydrated 2026-10-14 (the revert
PR that added this line). To pause again, re-apply #637 and #638. While paused, the state is as
follows. **No data is deleted:**

- **Still there:** the Garage lake (`s3://iso-market-data`), the ClickHouse PVC `data-clickhouse-0`
  (50Gi), the Postgres PVC `iso-lab-pg-1` (10Gi, Dagster run history and schedule state), the miso-ask
  PVC `miso-ask-data` (5Gi), every ExternalSecret, Service, HTTPRoute and blocky entry.
- **Off:** every iso-lab, miso-lab and miso-ask workload is at 0 replicas, and so is
  `cloudflared-personal`. The Dagster daemon and code server are disabled (`dagsterDaemon.enabled:
  false`, `dagster-user-deployments.enableSubchart: false`: the chart treats a replica count of 0 as
  1, so they're switched off instead). `iso-lab-pg` is hibernated (`cnpg.io/hibernation: "on"`). The
  iso-lab `VMRule` is commented out of `kustomization.yaml`.
- **Cloudflare (personal account):** not touched by gitops. The Access app for
  `miso-lab.phillips-homelab.net`, the tunnel's public hostname and its DNS CNAME may still exist in
  the dashboard. With the tunnel at 0 they lead nowhere.

**To bring it back:**

1. **Internal lab only (LAN/tailnet):** revert #637. Argo brings Postgres out of hibernation, then
   ClickHouse, then Dagster. Argo sync waves don't wait for health, so Dagster's init containers just
   retry until Postgres is up. Don't revert the tunnel PR.
2. **Confirm the next live poll:** in https://dagster.phillips-homelab.net, wait for a green
   `__ASSET_JOB` run (polls start at minute 1 and then every 5 minutes), then `data_freshness_checks`.
   Freshness checks fail until the first poll lands, so expect a burst of ntfy alerts on resume.
3. **Fill the gap:**
   - The daily report jobs (`refresh_*_daily`) are partitioned by market day and only run the newest
     day. Launch a back-fill in the Dagster UI for every day from 2026-10-14 to the resume date. FTR
     (`refresh_ftr_monthly`) does the same per month.
   - The live 5-minute feeds can't be back-filled past MISO's short rolling window: node LMP and fuel
     mix recover only what `/Rolling` still holds. The hub feed's ancillary MCPs are current-interval
     only, so that part of the gap is permanent. The marts show it as missing intervals, which is
     correct (the lake is verbatim).
   - `compact_lake` catches up on its own the next morning (06:20 UTC).
4. **Public demo again (only if someone asks Casey):** set `cloudflared-personal` back to 2 replicas,
   make sure the Access app and its email allowlist still exist (they're required for every hostname
   on the tunnel), then load the portal through the public link signed in as an allowlisted user.
