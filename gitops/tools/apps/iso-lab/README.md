# iso-lab

ISO Market Data Lab: public MISO market data, ingested by Dagster into immutable
Parquet on Garage (`s3://iso-market-data/raw/...`), served from ClickHouse. Code and
image: private repo `AlverezYari/iso-market-data-lab` (`zot.phillips-homelab.net/iso-lab:<sha>`).
These manifests are vendored from that repo's `deploy/k8s/`; this copy is what runs.

| App | Wave | What |
|---|---|---|
| `iso-lab-db` | 0 | namespace `iso-lab`, CNPG `iso-lab-pg` (Dagster run/event storage) |
| `iso-lab` | 1 | ClickHouse StatefulSet, ExternalSecret `iso-lab-env`, CiliumNetworkPolicies, tailnet Services |
| `iso-lab-dagster` | 2 | Dagster Helm chart 1.13.25: webserver, daemon, `iso-lab` code server (runs execute in it, DefaultRunLauncher) |

- Secrets: 1Password item `iso-lab` (vault `phillips-homelab`), created with
  `deploy/k8s/provision.sh` in the code repo, which also made Garage bucket `iso-market-data` +
  key `iso-lab`.
- Deploy a new build: bump `tag:` in `../iso-lab-dagster.yml`.
- Access (tailnet): Dagster UI `http://iso-dagster`, ClickHouse HTTP `http://iso-clickhouse:8123`
  (`iso` pipeline user, `iso_ro` read-only for the MCP server).
- ClickHouse is rebuildable from the lake (`SELECT ... FROM s3(lake, filename='raw/miso/...')`), so
  one replica on iSCSI is deliberate. Garage requires SigV4 region `garage`, which
  `clickhouse/lake.xml` sets.
- Network: only the code-server pod (`iso-lab/role: ingest`) has internet egress, limited to
  `*.misoenergy.org` hosts by toFQDNs; ClickHouse can reach Garage only.
