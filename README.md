<h1 align="center" style="margin-top: 0px;">Phillips Homelab</h1>

<p align="center">2025 Edition</p>

<p align="center" style="margin-bottom: 0px !important;">
    <img src="https://raw.githubusercontent.com/alverezyari/phillips-homelab/main/img/homelab.png" alt="Phillips Homelab 2025" width="300" align="center">
</p>

## Intro & Overview

Welcome to my Homelab 2025 project repo! I decided to put this together to practice working with Kubernetes and specifically Talos Linux, while not breaking the bank using one of the public clouds. Additionally, I'm currently working in the gaming space, where self-hosting, especially at the fleet scale is always a challenge. I wanted to build a homelab that would allow me to test out some of the latest and greatest tools in the Kubernetes ecosystem, while also being able to run my own game servers, and other workloads.


**Latest Update (August 2025):** The cluster has been expanded to 4 nodes! Added a custom-built system in a Thermaltake Core V21 case with my existing NVIDIA RTX 2080 SUPER GPU (repurposed from my old gaming rig) to enable AI/ML workloads including local LLM inference with Ollama and OpenWebUI.

Currently, the cluster is comprised of 4 nodes running Talos Linux - three Beelink EQR5 mini PCs for general workloads and one custom-built system for GPU-accelerated tasks. The cluster is running on my internal lab network which is manged on a Ubiquiti Dream Machine Pro, thought a TP link switch. The cluster is running on a 1G network, which does share bandwidth with my day to day home network. Storage to the cluster is mostly provided by a Synology NAS, which is controlled via a csi driver running in the cluster (love this setup!). The core configuration and management of the cluster is acomplished using a mix of Ommi/Talos at the cluster configuration level, and I'm running ArgoCD within the cluster itself to manage my application level.

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
    
- Motherboard & CPU: [ASRock DeskMini X600](https://www.amazon.com/dp/B0FBTFCFMD?ref=ppx_yo2ov_dt_b_fed_asin_title&th=1)
    - AMD Ryzen 9 7940HS
    - Mini-ITX form factor
    - 2.5G Ethernet
    
- Memory: [64GB DDR5-5600](https://www.amazon.com/dp/B09RWVV3XZ?ref=ppx_yo2ov_dt_b_fed_asin_title)
    - 2x32GB DDR5 SO-DIMM
    
- Storage: [1TB NVMe SSD](https://www.amazon.com/dp/B0D6NMDNNX?ref=ppx_yo2ov_dt_b_fed_asin_title)
    
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

- 1x [TP-Link TL-SG1016PE](https://www.amazon.com/TP-Link-Unmanaged-Rackmount-Lifetime-TL-SG1016PE/dp/B0721V1TGV/ref=sr_1_1?crid=2HMDDJXIR8SW9&dib=eyJ2IjoiMSJ9.InmIW091P5DoHy4swhfKjbKOIb8n7GQGwMOtAwvUVUe4shbTDDKxYcy3VbZvZ7mwNI4kdwBYsrdQ31qqNpz5fRbXsEqEH4aqOUesekfZPDOMNQ9qSfqHfn57mzdQtdZzgsC1YB7kIF6XwnNw8eLBZnpduYlhhYa1Br6O40jDL4icYqANMNESJpT6QVzlSVG9ZLRdxEq0i3ClkHcxf2q1Ow1580qwOGljy-dnUmILKb0sCFeUG265X4MN0Y9nB4miN1W9KX6dxgZea8kdjHLyQMX6cI9x-y9HEo65Kn-rE8EVGDc2QxDAZTYrTiB_UFxv9TG-waKa6fuSCkkv7gdn6SHhUdlHykdtqzYPgD6QM8s.lT34CHavGsQl0gvXhwXR2qImMNvLA8hPQkjWDg8vQYA&dib_tag=se&keywords=tp%2Blink%2Bsg1016pe&qid=1743357065&s=electronics&sprefix=tplink%2Bsg1016pe%2Celectronics%2C85&sr=1-1&th=1)
    - 16x 1G Ports
    - 8x PoE Ports

- 1x [Ubiquiti Dream Machine](https://www.amazon.com/Machine-MU-MIMO-Dual-Band-Gigabit-UDM-US/dp/B0DDDP93YX/ref=sr_1_4?crid=8CDBD4207294&dib=eyJ2IjoiMSJ9.li_aweq7xoRuO9PhKkIVZ7kcu27B-NjyGPvdlX9wiwvFUGWASNDzIHwZweszDN8C1xGnzFXq3TvliCt5_o1gS2PdoWi0t1MfobUd2teMwEWT7NjvxB2F4dFWJsZSwlqovfR1jcY1NkT1u5QUM-RK7Z1Qnm1oT9wRRpc3UOUq3hdgePesTFX7t6qZb50v6vSMMfEBOINbCgDBJgeG1BFQOcGt09qRukkBmB_AKjvTn62wBvp2xKOC-taB4TlQCz0p-zB-0Xs2bRB8VWauANa_x_9V55tbox6SLUqlkGSRqnbOrwyFWWRiyY6whaqa9FofmQrLYl2H9HyFnqwDeyuQj0rFl9dAOow4tM1WgcVI4Cho.Xd1uCOFvhbu-BMDeoPt3eZBrF_88fzmWm4-KVZzxyhE&dib_tag=se&keywords=ubiquiti%2Bdream%2Bmachine%2Bpro&qid=1743357111&s=electronics&sprefix=Ubiquiti%2BDrea%2Celectronics%2C106&sr=1-4&th=1)
    - 1x 10G SFP+ Port
    - 8x 1G Ports
    - 1x WAN Port

#### Cluster Management

- **Cluster OS:** Talos Linux
- **Cluster Management:** Omni
- **Kubernetes Version:** 1.31.4
- **Talos Version:** 1.9.2

#### Cluster Components

**Core Infrastructure:**
- **CNI:** [Cilium](https://github.com/cilium/cilium)
- **Ingress:** [Gateway API + Cilium](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/)
- **Ingress Controller:** [Cilium Ingress Support](https://docs.cilium.io/en/stable/network/servicemesh/ingress/)
- **Load Balancer:** [Cilium LoadBalancer IP Address Management (LBIPAM)](https://docs.cilium.io/en/stable/network/lb-ipam/)
- **Application Management:** [ArgoCD](https://github.com/argoproj/argo-cd)
- **Storage Management:** [CSI Driver for Synology NAS](https://github.com/SynologyOpenSource/synology-csi)
- **Secret Management:** [External Secrets Operator](https://github.com/external-secrets/external-secrets) (1Password Connection/Sync API)
- **TLS Management:** [Cert-Manager](https://github.com/cert-manager/cert-manager) backed by AWS Route53 DNS Challenges

**Observability Stack:**
- **Metrics:** [VictoriaMetrics](https://github.com/VictoriaMetrics/VictoriaMetrics)
- **Logging:** [Loki](https://github.com/grafana/loki)
- **Log Collection:** [Vector](https://vector.dev/)
- **Dashboarding:** [Grafana](https://github.com/grafana/grafana)

**Additional Services:**
- **Container Registry:** [Zot](https://zotregistry.io/)
- **VPN/Networking:** [Tailscale](https://tailscale.com/)
- **Home Automation:** [Home Assistant](https://www.home-assistant.io/)

## Key Features

- **Cluster Management:** [Omni + Talos](https://www.talos.dev/v1.9/talos-guides/install/omni/)
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

- **Log Collection:** [Vector](https://vector.dev/)
    - Vector is being used as the log collection agent to gather logs from across the cluster and forward them to Loki. Vector is a high-performance observability data pipeline that's designed to be reliable and efficient. I chose Vector over alternatives like Fluent Bit or Filebeat because of its modern architecture and excellent performance characteristics.

- **Cluster Observability Dashboards:** [Grafana](https://grafana.com/grafana/)
    - Grafana is the best dashboarding solution out there, and I don't think anyone would argue with that. Everyone loves it for a reason and they would really have to screw it up to lose that title. I'm using a mix of VictoriaMetric published dashboards along with some custom ones that I've created to monitor the cluster and its components.

- **Cluster Secrets Manager:** [External Secrets Operator](https://external-secrets.io/latest/)
    - External Sevcrets Operator is a tool used to sync sercrets from some kind of external secret store (ie AWS Secrets Manager, HashiCorp Vault, etc) into a Kubernetes Cluster. This is a great way to manage secrets in a secure and scalable way. I'm using the 1Password connection API to sync secrets from my 1Password vault into home homelab cluster. The setup honestly was a huge pain to get working and one of the most annoying parts of my baseline setup. This is caused by 1Password requiring you to run a special API connection server in order to connect to their API. This is a bit of a chore, but once you get it working it works well enough. Again, at my day job setting this up with something like AWS Secrets Store is a lot easier. Eitherway you should be using something like this to manage your secrets in Kubernetes! One of the MOST important things to get right in your cluster!

- **Cluster TLS Manager** [Cert-Manager](https://cert-manager.io/)
    - Maybe just as important as the External Secrets Operator, is Cert-Manager a tool used to manage TLS certificates in Kubernetes. An absolute must have for any cluster, and certainly a core component of my Homelab. I'd recommend learning how to use this guy as soon as possible when getting into learning Kubernetes. I'm using the AWS Route53 DNS challenge method to manage my TLS certificates, but you can also use the ACME challenge if you don't want to use Route53!

- **Container Registry:** [Zot](https://zotregistry.io/)
    - Zot is a lightweight, OCI-compliant container registry that I'm using to store custom container images and cache public images locally. This reduces external bandwidth usage and provides faster image pulls within the cluster.

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

## GPU Node Setup

The GPU node (homelab-04) required special configuration to enable NVIDIA GPU support in Talos Linux:

1. **NVIDIA Container Runtime:** Configured with `runtimeClassName: nvidia` in pod specs
2. **GPU Resource Management:** Using nvidia.com/gpu resource requests/limits
3. **Node Affinity:** GPU workloads pinned to homelab-04 using nodeSelector
4. **Driver Configuration:** NVIDIA drivers loaded via Talos system extensions

## Recent Updates (August 2025)

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
2. AWS Route53 domain for DNS challenges
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

*Last updated: June 2025*
