<h1 align="center" style="margin-top: 0px;">Phillips Homelab</h1>

<p align="center">2026 Edition</p>

<p align="center" style="margin-bottom: 0px !important;">
    <img src="https://raw.githubusercontent.com/alverezyari/phillips-homelab/main/img/homelab.png" alt="Phillips Homelab 2026" width="300" align="center">
</p>

## Intro & Overview

Welcome to my Homelab 2026 project repo! I decided to put this together to practice working with Kubernetes and specifically Talos Linux, while not breaking the bank using one of the public clouds. Additionally, I'm currently working in the gaming space, where self-hosting, especially at the fleet scale is always a challenge. I wanted to build a homelab that would allow me to test out some of the latest and greatest tools in the Kubernetes ecosystem, while also being able to run my own game servers, and other workloads.


**Latest Update (May 2026):** Stood up a self-hosted **Forgejo** instance at `code.phillips-homelab.net` — a hedge against GitHub flakiness as coding-agent activity has been hammering it through 2026. 32 of my GitHub repos are now mirrored locally on a 1-hour sync interval, with HTTPS and SSH clone both working over LAN/Tailnet. Backed by a CloudNativePG Postgres cluster with daily Barman→Garage backups. Also a chunky Synology cleanup pass (24 orphan iSCSI LUNs removed, ~2.6 TB reclaimed) and pulled the Synology CSI install out of cluster drift into proper gitops management.

**April 2026:** Major cluster upgrade — Talos Linux v1.9.2 → v1.12.6, Kubernetes v1.31.4 → v1.35.4. GPU node (homelab-04) restored with a new NVMe drive and an AM5 motherboard/CPU upgrade to AMD Ryzen 7 9700X (Zen 5, 8-core). Switched the NVIDIA stack from the proprietary driver to the open-source kernel modules (LTS) per Sidero's 1.10+ recommendations. Networking refresh too — moved from the old Dream Machine + TP-Link unmanaged switch to a **Ubiquiti UCG-Fiber** for routing and a dedicated **USW-Flex-2.5G-8-PoE** for the cluster, with VLAN segmentation finally separating cluster traffic from household.

Currently, the cluster is comprised of 4 active nodes running Talos Linux — three Beelink EQR5 mini PCs for general workloads, plus a fourth custom-built GPU node (homelab-04) running an NVIDIA RTX 2080 SUPER for AI/ML workloads. The cluster sits on its own VLAN behind a Ubiquiti UCG-Fiber gateway through a dedicated 2.5G PoE switch. Storage is mostly provided by a Synology NAS (DS723+), controlled via a CSI driver running in the cluster (love this setup!). The core configuration and management of the cluster is accomplished using a mix of Omni/Talos at the cluster configuration level, and I'm running ArgoCD within the cluster itself to manage everything at the application level.

More details on both the hardware and software setup can be found below.

Thanks for checking out my project, and I hope you find it useful!

### Cluster Details

**Note:** All links are NON-affiliate links, and are provided for reference only. I do not make any money from these links, and they are provided as a convenience to you.

#### Hardware

##### Worker Nodes (3x)
- [3x Beelink EQR5 Mini PCs](https://www.amazon.com/dp/B0DLP5P62S?ref=ppx_yo2ov_dt_b_fed_asin_title&th=1)
    - AMD Ryzen 5 5500U
    - 16GB RAM
    - 512GB SSD
    - 2x 1G NICs

##### GPU Node (1x) - homelab-04 (Custom Build)
- Case: [Thermaltake Core V21 Micro ATX Cube](https://www.newegg.com/thermaltake-extreme-micro-atx-cube-chassis-core-v21-spcc-computer-case-black-ca-1d5-00s1wn-00/p/N82E16811133274)
    - Micro ATX cube chassis
    - Excellent airflow for GPU cooling
    - Full-length GPU support
    
- Motherboard & CPU: ASRock board (TODO: confirm model after April 2026 swap)
    - AMD Ryzen 7 9700X (Zen 5, 8-core, AM5 desktop)
    - 2.5G Ethernet (Intel)
    
- Memory: 64GB DDR5 (Patriot)
    - 2x32GB DDR5 DIMMs
    
- Storage: 1TB NVMe SSD (replacement, April 2026)
    
- GPU: NVIDIA RTX 2080 SUPER (repurposed from previous gaming PC)
    - 8GB GDDR6 VRAM
    - CUDA compute capability 7.5
    - Cost-effective reuse of existing hardware
    
- Power Supply: [600W PSU](https://www.amazon.com/dp/B0DCHBGVZK?ref=ppx_yo2ov_dt_b_fed_asin_title&th=1)
    
- Additional Components:
    - [OCuLink Cable](https://www.amazon.com/dp/B0DPR5RZ1T?ref=ppx_yo2ov_dt_b_fed_asin_title) (if needed for connectivity)

- 1x [Synology NAS DS723+](https://www.amazon.com/dp/B0BRN9J1JN?ref=ppx_yo2ov_dt_b_fed_asin_title&th=1)
    - 2x 8TB Seagate Ironwolf HDDs
    - 1x 1TB Samsung 970 EVO NVMe SSD (for caching)

##### Network

- 1x **Ubiquiti UCG-Fiber** (Cloud Gateway Fiber) — primary gateway/router
    - VLAN-segmented internal network (cluster on its own VLAN, separated from household traffic)
- 1x **Ubiquiti USW-Flex-2.5G-8-PoE** — dedicated cluster switch
    - 2.5G ports for the cluster nodes
    - 10G SFP+ uplink to the UCG-Fiber via 1m DAC
    - PoE-powers the downstream household-side switches (no separate adapters needed)

##### Decommissioned

The following gear was retired in the April 2026 network refresh and is no longer in use:

- ~~Ubiquiti Dream Machine~~ — routing role moved to the UCG-Fiber
- ~~TP-Link TL-SG1016PE (1G unmanaged)~~ — replaced for cluster duty by the USW-Flex-2.5G-8-PoE; the upgrade also unblocked VLAN segmentation, which the old dummy switch couldn't carry

#### Cluster Management

- **Cluster OS:** Talos Linux
- **Cluster Management:** Omni
- **Kubernetes Version:** 1.35.4
- **Talos Version:** 1.12.6

#### Cluster Components

**Core Infrastructure:**
- **CNI:** [Cilium](https://github.com/cilium/cilium)
- **Ingress:** [Gateway API + Cilium](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/)
- **Ingress Controller:** [Cilium Ingress Support](https://docs.cilium.io/en/stable/network/servicemesh/ingress/)
- **Load Balancer:** [Cilium LoadBalancer IP Address Management (LBIPAM)](https://docs.cilium.io/en/stable/network/lb-ipam/)
- **Application Management:** [ArgoCD](https://github.com/argoproj/argo-cd)
- **Storage Management:** [CSI Driver for Synology NAS](https://github.com/SynologyOpenSource/synology-csi)
- **Secret Management:** [External Secrets Operator](https://github.com/external-secrets/external-secrets) (1Password Connection/Sync API)
- **TLS Management:** [Cert-Manager](https://github.com/cert-manager/cert-manager) backed by Cloudflare DNS-01 challenges
- **Source Control / Git Mirror:** [Forgejo](https://forgejo.org/) (CNPG-backed, mirrors GitHub repos as a hedge against upstream instability)

**Observability Stack:**
- **Metrics:** [VictoriaMetrics](https://github.com/VictoriaMetrics/VictoriaMetrics)
- **Logging:** [Loki](https://github.com/grafana/loki)
- **Log Storage:** [Garage](https://garagehq.deuxfleurs.fr/) (S3-compatible object storage)
- **Log Collection:** [Vector](https://vector.dev/)
- **Dashboarding:** [Grafana](https://github.com/grafana/grafana)

**Additional Services:**
- **Container Registry:** [Zot](https://zotregistry.io/)
- **Source Control:** [Forgejo](https://forgejo.org/) — `code.phillips-homelab.net`
- **VPN/Networking:** [Tailscale](https://tailscale.com/)
- **Home Automation:** [Home Assistant](https://www.home-assistant.io/)
- **Homepage:** [Glance](https://github.com/glanceapp/glance) — apex `phillips-homelab.net`

## Key Features

- **Cluster Management:** [Omni + Talos](https://www.talos.dev/v1.12/talos-guides/install/omni/)
    - Omni is a pretty amazing tool that works together with Talos Linux to provide a extremely quick, easy, secure, and most importantly CLEAN way to manage your kubernetes cluster. I highly recommend checking it out if you are looking for a way to get into Kubernetes without the complexity of managing a full blown control plane. While I do think its important that every KubeNaunt go through the age old ritual and hell of settting up a cluster from scratch (the HARD way), I also think that its important to have a way to get up clusters up cleanly and quickly, on whatever hardware you have available to you. This really helps one to better understand how to appoach Kubernetes as a wholistic platform and not just a collection of complex components.

- **Cluster networking:** [Cilium + Gateway API](https://docs.cilium.io/)
    - Cilium is a powerful CNI that provides a lot of advanced features, such as eBPF based networking, load balancing, and security. The Gateway API is a new method for managing ingress and egress traffic in Kubernetes, of which Cilium already has fantastic support for. This combination provides a powerful and flexible way to manage ingress and egress traffic in Kubernetes. I thought it was important to use this setup in my Homelab, to help me get more familiar with Cilium and its capabilities. At my day job I mostly work with EKS clusters, which do have the ability to run Cilium but isn't exactly 100% supported by AWS at this time. However I'm excited to see that they now use Cilium as their default CNI for the AWS EKS Anywhere offering, so hopefully the learnings there can be re-applied to the core EKS offering, perhaps as a drop in addon like they have for many of the other cloud native components!

- **Cluster Application Managements:** [ArgoCD](https://argo-cd.readthedocs.io/en/stable/)
    - What can we say about ArgoCD that hasn't already been said? It's the GOAT of GitOps for a reason, and in my opinion its the only valid option in the market today. I know, I know what about Flux? I'm glad that Flux has been saved by being donated to the CNCF, and I think its a great tool for what it does. However, I just don't think it has the same level of community support and adoption as ArgoCD and thus I hesitate to point anyone away from it especially to a tool that has a uncertain future. Perhaps they will release some killer new revision or some kind of game changer feature that will make me rethink my position, but currently I think ArgoCD is the strongest project in this space.

- **Cluster Storage Management:** [Synology CSI Driver](https://github.com/SynologyOpenSource/synology-csi)
    - I was surprised at the maturity of the CSI driver that Synology has created for their NAS devices. In retrospect I guess I should have expected anything less from Synology, as they have been the leader in the NAS space for at least the last 15 years. I won't stay the in cluster instation process was easy, but after getting the container built, I was able to follow the documentation to an sucessful install! I was also pumped to see that there seems to be a lot of community support for getting these devices working in the Talos Linux community! I think this is a great option for anyone looking to add a NAS to their homelab, and I would highly recommend it!

- **Cluster Observability Metrics:** [VictoriaMetrics](https://victoriametrics.com/)
    - VictoriaMetrics has been chosen as the metrics backend for two main reasons. Some of the latest rumblings and actions taking place over at Grafana Labs have me a bit concerned about the future of Prometheus and Grafana as a whole. It's clear that they are trying to move more and more users into their cloud offering and their open source offerings are starting to feel a bit neglected. I'd heard good things about VictoriaMetrics both in terms of open source support and performance, so I thought it would be a good time to give it a try. So far the product seems to be performing extremely well and I've been really happy with the results.

- **Cluster Observability Logs:** [Loki](https://github.com/grafana/loki)
    - Despite what I said above about Grafana Labs, I still think that Loki is a great product and I'm using it here for my logging storage solution. I might look at swapping it out for something like VictoriaLogs in the future, but to get us off the ground I've decided to stick with Loki for now.

- **Log Object Storage:** [Garage](https://garagehq.deuxfleurs.fr/)
    - Garage is a lightweight, self-hosted, S3-compatible distributed object storage system. I switched to Garage from MinIO primarily due to MinIO's license change from Apache 2.0 to AGPL v3, which introduces significant compliance considerations. Garage remains under a permissive license and is far more resource-efficient for homelab use cases. It runs as a single-node StatefulSet with 50Gi of storage on the Synology NAS via iSCSI. S3 credentials are managed securely through External Secrets Operator, pulling from 1Password. Note: Configuring Loki to use external S3 storage requires per-component `extraEnvFrom` injection with `-config.expand-env=true` as documented in [grafana/loki#12249](https://github.com/grafana/loki/issues/12249).

- **Log Collection:** [Vector](https://vector.dev/)
    - Vector is being used as the log collection agent to gather logs from across the cluster and forward them to Loki. Vector is a high-performance observability data pipeline that's designed to be reliable and efficient. I chose Vector over alternatives like Fluent Bit or Filebeat because of its modern architecture and excellent performance characteristics.

- **Cluster Observability Dashboards:** [Grafana](https://grafana.com/grafana/)
    - Grafana is the best dashboarding solution out there, and I don't think anyone would argue with that. Everyone loves it for a reason and they would really have to screw it up to lose that title. I'm using a mix of VictoriaMetric published dashboards along with some custom ones that I've created to monitor the cluster and its components.

- **Cluster Secrets Manager:** [External Secrets Operator](https://external-secrets.io/latest/)
    - External Sevcrets Operator is a tool used to sync sercrets from some kind of external secret store (ie AWS Secrets Manager, HashiCorp Vault, etc) into a Kubernetes Cluster. This is a great way to manage secrets in a secure and scalable way. I'm using the 1Password connection API to sync secrets from my 1Password vault into home homelab cluster. The setup honestly was a huge pain to get working and one of the most annoying parts of my baseline setup. This is caused by 1Password requiring you to run a special API connection server in order to connect to their API. This is a bit of a chore, but once you get it working it works well enough. Again, at my day job setting this up with something like AWS Secrets Store is a lot easier. Eitherway you should be using something like this to manage your secrets in Kubernetes! One of the MOST important things to get right in your cluster!

- **Cluster TLS Manager** [Cert-Manager](https://cert-manager.io/)
    - Maybe just as important as the External Secrets Operator, is Cert-Manager a tool used to manage TLS certificates in Kubernetes. An absolute must have for any cluster, and certainly a core component of my Homelab. I'd recommend learning how to use this guy as soon as possible when getting into learning Kubernetes. I migrated from AWS Route53 to **Cloudflare DNS-01** in April 2026 (consolidated DNS management with the rest of my Cloudflare-served domains), but the same pattern works with any provider cert-manager supports.

- **Container Registry:** [Zot](https://zotregistry.io/)
    - Zot is a lightweight, OCI-compliant container registry that I'm using to store custom container images and cache public images locally. This reduces external bandwidth usage and provides faster image pulls within the cluster.

- **Source Control / Git Mirror:** [Forgejo](https://forgejo.org/)
    - Forgejo is a self-hosted, OCI-compliant Git forge (community-driven Gitea fork). I stood it up in May 2026 specifically as a hedge against the GitHub flakiness that's been happening through 2026 — coding-agent activity has been hammering GitHub at well above their planned capacity, and I wanted my own local copy of the repos I depend on. Backed by a CloudNativePG cluster (1 instance, daily Barman→Garage backups, the same atuin pattern), 200Gi data PVC on the Synology iSCSI CSI, internal-only HTTPS at `code.phillips-homelab.net` and SSH cloning via a LoadBalancer Service. 32 of my GitHub repos auto-mirror on a 1-hour interval. There's a `scripts/forgejo-mirror-github.py` (uv self-contained) for bulk-creating new mirrors via the migration API. The longer-term play is to use it as the source-of-truth forge for CI experiments that don't lock me into the GitHub Actions ecosystem.

- **VPN/Mesh Networking:** [Tailscale](https://tailscale.com/)
    - Tailscale provides secure mesh networking capabilities, allowing me to securely access cluster services from anywhere without exposing them to the public internet. It's particularly useful for accessing internal dashboards and administrative interfaces.

- **Home Automation:** [Home Assistant](https://www.home-assistant.io/)
    - Home Assistant is running as a workload in the cluster to manage various IoT devices and home automation tasks. This demonstrates the cluster's ability to run diverse workloads beyond just development and monitoring tools.

## Architecture Highlights

### GitOps Workflow
The entire cluster configuration is managed through GitOps principles using ArgoCD. Application manifests are stored in the `gitops/` directory and automatically deployed when changes are pushed to the repository.

### Multi-Tenant Structure
Applications are organized into logical groups:
- **Core Apps** (`gitops/core/apps/`): Essential cluster infrastructure
- **Tool Apps** (`gitops/tools/apps/`): Additional services and applications

### Storage Architecture
Persistent storage is provided through the Synology NAS using iSCSI connections managed by the CSI driver, providing reliable and scalable storage for stateful applications.

### Network Security
Cilium's eBPF-based networking provides advanced security features including network policies, load balancing, and observability at the kernel level.

## Services & Applications

### Core Infrastructure

- **ArgoCD:** GitOps continuous deployment for all cluster applications
- **External Secrets Operator:** Secret management with 1Password integration
- **Cert-Manager:** TLS certificate automation with AWS Route53
- **VictoriaMetrics:** High-performance metrics collection and storage
- **Loki:** Log aggregation and storage
- **Grafana:** Observability dashboards and visualization

### Media & Entertainment

- **Jellyfin Media Server:** Self-hosted media streaming platform
  - Hardware accelerated transcoding support
  - Deployed on homelab-04 with dedicated resources
  - Secure HTTPS access via TLS certificates
  - 100Gi persistent storage on Synology NAS
  
- **Filebrowser:** Web-based file management interface
  - Media file organization and management
  - Direct Synology NAS integration
  - Version 1.0.0 with 50Gi persistent storage

### AI & Machine Learning

- **OpenWebUI + Ollama:** Complete local AI platform
  - Modern web interface for Large Language Models
  - Integrated Ollama backend for local LLM inference
  - **GPU Acceleration:** NVIDIA RTX 2080 SUPER with 8GB VRAM
  - Deployed with `runtimeClassName: nvidia` for proper GPU runtime access
  - Performance: ~100+ tokens/sec with GPU vs 12.8 tokens/sec CPU-only
  - Resource allocation:
    - Ollama: 4 CPU cores, 8Gi memory, 1 GPU, 150Gi model storage
    - OpenWebUI: 2 CPU cores, 4Gi memory, 20Gi persistent storage
  - Supports multiple concurrent models including Llama, Mistral, and more

### Network & Connectivity

- **Tailscale:** Zero-trust network access
  - Secure remote access to all homelab services
  - Mesh VPN with automatic NAT traversal
  - Integration with existing cluster networking

### Container Registry

- **Zot Registry:** OCI-compliant container registry
  - Local container image storage and distribution
  - Reduces external bandwidth usage
  - Integrated with cluster authentication

### Source Control

- **Forgejo:** Self-hosted Git forge with GitHub mirror
  - Mirrors 32 GitHub repos on a 1-hour sync interval
  - Internal-only HTTPS at `code.phillips-homelab.net` (LAN/Tailnet)
  - SSH cloning via LoadBalancer (`git@code.phillips-homelab.net:owner/repo.git`)
  - CNPG-backed Postgres with daily Barman backups to Garage (s3://forgejo-backups)
  - 200Gi data PVC on Synology iSCSI CSI; admin creds + DB creds + GitHub PAT all flow from 1Password via External Secrets Operator
  - Hedge against GitHub instability + future home for CI experiments outside the GH Actions ecosystem

## GPU Node Setup

The GPU node (homelab-04) required special configuration to enable NVIDIA GPU support in Talos Linux:

1. **NVIDIA Container Runtime:** Configured with `runtimeClassName: nvidia` in pod specs
2. **GPU Resource Management:** Using nvidia.com/gpu resource requests/limits
3. **Node Affinity:** GPU workloads pinned to homelab-04 using nodeSelector
4. **Driver Configuration:** NVIDIA drivers loaded via Talos system extensions

## Recent Updates

### May 2026
- **Stood up Forgejo** at `code.phillips-homelab.net` — CNPG-backed, internal-only, HTTPS + SSH (LoadBalancer), open registration disabled, 200Gi data PVC. Daily Barman backups to Garage.
- **Mirrored 32 GitHub repos** into Forgejo on a 1-hour sync interval; uv self-contained Python script (`scripts/forgejo-mirror-github.py`) handles bulk mirror creation via Forgejo's migration API + GitHub repos via `gh auth token`.
- **Synology CSI install + StorageClass adopted into gitops** (`gitops/core/apps/synology-csi/`) — was previously `kubectl apply`'d drift; brief misadventure switching to upstream `synology/synology-csi:v1.2.1` revealed that the existing fork specifically bundles `iscsiadm` for Talos compat (upstream image expects host iscsiadm that Talos doesn't expose). Reverted to the fork build.
- **Synology DSM credentials** (`client-info-secret`) moved to an ExternalSecret pulling from 1Password, matching the atuin pattern.
- **Synology orphan LUN cleanup**: 24 LUNs deleted, **~2.6 TB reclaimed** on the NAS pool. Added `scripts/synology-lun-cleanup.py` (uv self-contained) with `--auto-discover` (cross-references kubectl PVs against DSM LUN list to identify orphans), proper timeouts, and per-LUN error handling.
- **Argo CD upgraded v3.3.8 → v3.3.9** for [GHSA-3v3m-wc6v-x4x3](https://github.com/argoproj/argo-cd/security/advisories/GHSA-3v3m-wc6v-x4x3) (CVSS 9.6 — Kubernetes Secret extraction via ServerSideDiff; we actively use ServerSideDiff so were squarely in-scope).
- **Zot helm chart bumped 0.1.91 → 0.1.112** (picks up the maintainers' resolution of the auth-probes issues).
- **Glance homepage** shipped at apex `phillips-homelab.net` with HN, Lobsters, reddit, releases monitor (PR #214).

### April 2026
- **Network refresh:** Replaced the Ubiquiti Dream Machine + TP-Link TL-SG1016PE unmanaged switch with a Ubiquiti UCG-Fiber gateway and a dedicated USW-Flex-2.5G-8-PoE for the cluster (10G DAC uplink). VLANs implemented to separate cluster traffic from household.
- Major cluster upgrade: Talos Linux v1.9.2 → v1.12.6 (stepped through v1.9.6, v1.10.9, v1.11.6)
- Major cluster upgrade: Kubernetes v1.31.4 → v1.35.4 (stepped through v1.32.13, v1.33.11, v1.34.7)
- Synced Omni cluster template to be the single source of truth (captured drift from UI-applied patches)
- Moved system extensions from cluster-wide to per-machine-set configuration
- Added nut-client extension to worker and control plane nodes
- Temporarily removed GPU node (homelab-04) due to failing disk; replacement NVMe on order
- Scaled down GPU workloads (Jellyfin, OpenWebUI, Filebrowser) to 0 replicas until hardware is replaced
- Restored homelab-04 with new NVMe drive + AM5 motherboard/CPU upgrade (Ryzen 9 7940HS → Ryzen 7 9700X)
- Switched NVIDIA stack to open-source kernel modules LTS branch (Sidero's recommendation for Talos 1.10+) and pinned the device plugin DaemonSet to the new extension label
- Re-enrolled homelab-04 in Omni as a separate `gpu` worker machine set with the GPU/firmware extensions isolated from the regular workers
- Scaled GPU workloads back to 1 replica

### December 2025
- Replaced MinIO with Garage for Loki S3 storage (AGPL license concerns)
- Upgraded ArgoCD from v2.14.7 (EOL) to v3.2.1
- Upgraded Cilium from v1.17.2 to v1.17.10 (security patch)
- Upgraded Tailscale operator from v1.82.0 to v1.90.9
- Added DNS entry for Synology NAS via Blocky

### August 2025
- Added 4th node (custom build in Thermaltake Core V21 case) with GPU support for AI/ML workloads
- Reused RTX 2080 SUPER from old gaming PC for cost-effective GPU compute
- Deployed OpenWebUI with Ollama for local LLM inference
- Configured Jellyfin media server with hardware transcoding
- Implemented Filebrowser for media management
- Set up TLS certificates for all public-facing services
- Optimized resource allocation to prevent GPU scheduling conflicts
- Fixed Ollama GPU runtime configuration for proper CUDA access

## High Level Setup Instructions

### Prerequisites
1. Omni account for cluster management
2. Cloudflare-managed DNS zone for cert-manager DNS-01 challenges (was AWS Route53 pre-April 2026)
3. 1Password account with Connect API access
4. Synology NAS with DSM 7.0+

### Cluster Bootstrap
1. Use Omni to provision Talos Linux on the three Beelink nodes
2. Install Cilium as the CNI
3. Bootstrap ArgoCD
4. Apply the core application manifests
5. Configure external secrets integration
6. Deploy additional tools and applications

### Storage Setup
1. Configure iSCSI targets on Synology NAS
2. Install and configure the Synology CSI driver
3. Create storage classes for different workload types

### Monitoring Configuration
1. Deploy VictoriaMetrics stack
2. Configure Grafana with custom dashboards
3. Set up log aggregation with Vector and Loki
4. Configure alerting rules

For detailed setup instructions and troubleshooting guides, see the individual component documentation in each application directory.

## Future Enhancements

- Migration to VictoriaLogs for centralized logging
- Implementation of GitOps for cluster configuration using Talos/Omni integration
- Addition of backup and disaster recovery solutions
- Integration with external monitoring and alerting systems
- Expansion of home automation capabilities

## Contributing

This repository serves as both documentation and configuration for my personal homelab. While primarily for my own use, the configurations and approaches documented here may be useful for others building similar setups.

---

*Last updated: May 2026*
