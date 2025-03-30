<p align="center">
    <center><h1>- Phillips Homelab - </h1></center>
    <h2> 2025 Edition </h2>
</p>

<img src="https://raw.githubusercontent.com/alverezyari/phillips-homelab/main/img/homelab.png" alt="Phillips Homelab 2025" width="300"/>

## Intro & Overview

Welcome to my Homelab 2025 project repo! I decided to put this together to pratice working with Kubernetes and specifically Talos Linux, while not breaking the bank using one of the public clouds. Additionally, I'm currently working in the gaming space, where self-hosting, espcially at the fleet scale is always a challenge. I wanted to build a homelab that would allow me to test out some of the latest and greatest tools in the Kubernetes ecosystem, while also being able to run my own game servers, and other workloads.

Currently, the cluster in comprised of 3 Beelink EQR5 mini PCs, which are running Talos Linux. The cluster is running on my internal lab network which is manged on a Ubiquiti Dream Machine Pro, thought a TP link switch. The cluster is running on a 1G network, which does share bandwidth with my day to day home network. Storage to the cluster is mostly provided by a Synology NAS, which is controlled via a csi driver running in the cluster (love this setup!). The core configuration and management of the cluster is acomplished using a mix of Ommi/Talos at the cluster configuration level, and I'm running ArgoCD within the cluster itself to manage my application level.

More details on both the hardware and software setup can be founded below.

Thanks for checking out my project, and I hope you find it useful!

### Cluster Details

#### Hardware

- 3x Beelink EQR5 Mini PCs
    - 16GB RAM
    - 512GB SSD
    - 2x 1G NICs

- 1x Synology NAS DS723+
    - 2x 8TB Seagate Ironwolf HDDs
    - 1x 1TB Samsung 970 EVO NVMe SSD (for caching)

- 1x TP-Link TL-SG1016PE
    - 16x 1G Ports
    - 8x PoE Ports

- 1x Ubiquiti Dream Machine Pro
    - 1x 10G SFP+ Port
    - 8x 1G Ports
    - 1x WAN Port

#### Cluster Management

- **Cluster OS:** Talos Linux
- **Cluster Management:** Omni
- **Kubernetes Version:** 1.31.4
- **Talos Version:** 1.9.2

#### Cluster Components

- **CNI:** Cilium
- **Ingress:** Gateway API + Cilium
- **Ingress Controller:** Cilium Gateway
- **Load Balancer:** Cilium LoadBalancer IP Address Management (LBIPAM)
- **Application Management:** ArgoCD
- **Storage Management:** CSI Driver for Synology NAS
- **Metrics:** VictoriaMetrics
- **Logging:** Loki
- **Dashboarding:** Grafana
- **Secret Management:** External Secrets Operator (1Passsword Connection/Sync API)
- **TLS Management:** Cert-Manager backed by AWS Route53 DNS Challenges


## Key Features

- **Cluster Management:** Omni + Talos
    - Omni is a pretty amazing tool that works together with Talos Linux to provide a extremely quick, easy, secure, and most importantly CLEAN way to manage your kubernetes cluster. I highly recommend checking it out if you are looking for a way to get into Kubernetes without the complexity of managing a full blown control plane. While I do think its important that every KubeNaunt go through the age old ritiual and hell of settting up a cluster from scratch (the HARD way), I also think that its important to have a way to get up clusters up cleanly and quickly, on whatever hardware you have available to you. This really helps one to better understand how to appoach Kubernetes as a wholistic platform and not just a collection of complex components.
- **Cilium + Gateway API + Cilium Gateway**
    - Cilium is a powerful CNI that provides a lot of advanced features, such as eBPF based networking, load balancing, and security. The Gateway API is a new API for managing ingress and egress traffic in Kubernetes, of which Cilium already has fantastic support for. This combination provides a powerful and flexible way to manage ingress and egress traffic in Kubernetes. I thought it was important to use this setup in my Homelab, to help me get more familiar with Cilium and its capabilities. At my day job I mostly work with EKS Cluster, which do have the ability to run Cilium but isn't exactly 100% supported by AWS at this time. However I'm excited to see that they now use Cilium as their default CNI for the AWS EKS Anywhere offering, so hopefully the learnings there can be re-applied to the core EKS offering, perhaps as a drop in addon like they have for many of the other cloud native components!
- **ArgoCD**
    - What can we say about ArgoCD that hasn't already been said? It's the GOAT of GitOps for a reason, and in my opinion its the only valid option in the market today. I know, I know what about Flux!? I'm glad that Flux has been saved by being donated to the CNCF, and I think its a great tool for what it does. However, I just don't think it has the same level of community support and adoption as ArgoCD and thus I hesitate to point anyone away from it especially if that tools future is uncertain. Perhaps they will release some killer new revision or some kind of game changer that will make me rethink my position, but for that stronge core GitOps feature set, I think ArgoCD is the best option out there.
- **CSI Driver for Synology NAS**
    - I was surprised at the maturity of the CSI driver that Synology has created for their NAS devives. In retrospect I guess I should have expected anyting less of Synology, as they are a leader in the NAS space and have been for at leas the last 15 years. I won't stay the instation process was easy, but it was pretty straight forward and the documentation was pretty good. I also enjoyed that there seems to be a lot of community support for getting it working in the Talos Linux community. I think this is a great option for anyone looking to add a NAS to their homelab, and I would highly recommend it!
- **VictoriaMetrics**
    - VictoriaMetrics has been choosen as the metrics backend as the cluster for two main reasons. Some of the latest rumblings and actions taking place over at Grafana Labs have me a bit concerned about the future of Prometheus and Grafana as a whole. It's clear that they are trying to move more and more users into their cloud offering and their open source offerings are starting to feel a bit neglected. I'd heard good things about VictoriaMetrics both in terms of open source support and performance, so I thought it would be a good time to give it a try. So far the product seems to be performing extremely well and I've been really happy with the results.
- **Loki**
    - Despite what I said above about Grafana Labs, I still think that Loki is a great product and I'm using it here for my logging storage solution. I might look at swaping it out for something like VictoriaLogs in the future, but to get us off the ground I've decided to stick with Loki for now.
- **Grafana**
    - Grafana is the best dashboarding solution out there, and I don't think anyone would argue with that. Everyone loves it for a reason and they would really have to screw it up to lose that title. I'm using a mix of VictoriaMetric published dashboards along with some custom ones that I've created to monitor the cluster and its components.
- **External Secrets Operator**
    - External Sevcrets Operator is a tool used to sync sercrets from some kind of external secret store (ie AWS Secrets Manager, HashiCorp Vault, etc) into Kubernetes secrets. This is a great way to manage secrets in a secure and scalable way. I'm using the 1Password connection API to sync secrets from my 1Password vault into Kubernetes secrets. The setup honestly was a huge pain to get working and one of the most annoying parts to get working. This is cauased by 1Password requiring you to run a special api connection server in order to connect to their API. This is a bit of a pain, but once you get it working it works well enough. Again, at the day job setting this up with something like AWS Secrets Store is a lot easier in my eexperience. Eitherway you should be using something like this to manage your secrets in Kubernetes! One of the MOST important things to get right in your cluster!
- **Cert-Manager**
    - Maybe just as important as the External Secrets Operator, is Cert-Manager a tool used to manage TLS certificates in Kubernetes. An absolute must have for any cluster, and certainly a core component of my Homelab. I'd recommend learning how to use this guy as soon as possible when getting into Kubernetes. I'm using the AWS Route53 DNS challenge to manage my TLS certificates, but you can also use the ACME challenge if you don't want to use Route53!


## High Level Setup Instructions

Coming soon!

