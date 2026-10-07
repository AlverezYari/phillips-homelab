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
  `iso-lab` on the stock-bot ntfy.
- **ClickHouse:** in-cluster only. `iso` is the pipeline user, `iso_ro` the read-only user for the
  MCP server. It's rebuildable from the lake (`dbt build --full-refresh`), so one replica on iSCSI is
  deliberate. Garage requires SigV4 region `garage`, which `clickhouse/lake.xml` sets.
- **Network:** only the code-server pod (`iso-lab/role: ingest`) has internet egress, limited to
  `*.misoenergy.org` by toFQDNs. It may also reach Garage, ClickHouse, its Postgres and ntfy.
  ClickHouse may reach only Garage. Webserver and daemon have no policy yet.
