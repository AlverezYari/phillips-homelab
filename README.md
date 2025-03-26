# Phillips-homelab

## Overview

This is my very WIP Kubernetes homelab setup. I'm currently trying to get the cluster fully bootstrapped, and ready to accept workloads secured behind proper TLS termination. I'm using Talos/Omni as my base OS, and Cilium as my CNI. I'm also using ArgoCD to manage the cluster. I've just gotten ArgoCD's GUI up and running, accessable via the new Kubernetes Gateway API. I'm detail


## Cluster Prep - First Draft Setup Instructions

1. Used the Talos/Omni Ctl to create a new cluster, and bootstrap it without a CNI or Kube-Proxy.
2. Instal the 1.17.2 version of the Cilium Helm chart using our custom values file located in ./cluster/helm/cilium/values.yaml.
3. Install the CRDs for the gateway api + tls routes. Mix of v1 + vbeta1.
    - kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/experimental-install.yaml 
4. This should allow creation of the resources from our gateway.yml from our omni directory. If not feel free to directly re-apply this gateway.yml to the cluster.
5. Create cert-manager NS, and then Install Cert-manager via Helm chart -> 1.17.1 with crds enabled!
6. Setup your Cluster Issuer for LetsEncrypt, I'm using Route53 with a DNS, but you can also just locally generate certs if you don't want to get fancy.
7. Generate a cert for your domain, careful to save it in a secret in the same namespace as the cert-manager resources.
7. Update the gateway and related resources to use the new cert to handle TLS termination.
8. Madness ensues, as you now have a working gateway with TLS termination. MUHA HA HA HA HA!

**Notes:** 
    - Note that we setup ArgoCD to boot into insecure mode, because we handle TLS at the gateway level.

## GitOps - First Draft Setup Instructions

1. If you are following along, you should already have ArgoCD installed in your cluster from the Cluster Prep steps. Now we'll use that badass tool to finish setting up our cluster. Afterwards it will settle into a nice loop of keeping our cluster in sync with our git repo.
2. Move into the ./gitops/core/ directory, and apply our core resources. # This should be replaced with the argo in argo method
    - kubectl apply -f ./gitops/core/core-apps.yml
        - **Note:** This is mostly a short cut to instal all the apps defined in the './gitops/core/apps/' directory in one shot.
3. ...
