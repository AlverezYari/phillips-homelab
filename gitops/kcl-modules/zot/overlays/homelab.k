import "../main.k" as base

base.zotSpec.name = "zot-homelab"
base.zotSpec.namespace = "zot-homelab"
base.zotSpec.replicas = 1
base.zotSpec.enablePVC = True
base.zotSpec.pvcSize = "200Gi"

# Re-export the final resources
service = base.service
deployment = base.deployment
if base.zotSpec.enablePVC:
    volumeClaim = base.volumeClaim

