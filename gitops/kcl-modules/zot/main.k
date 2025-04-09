# zot/main.k

# Import our local resource files
import "./service.k" as svc
import "./deployment.k" as dep
import "./pvc.k" as pvc

# Schema for user-facing config
schema ZotSpec:
    name: str = "zot"
    namespace: str = "zot"
    image: str = "ghcr.io/project-zot/zot-linux-amd64:v2.1.2"
    replicas: int = 1

    # Service
    servicePort: int = 5000
    serviceType: str = "ClusterIP"

    # PVC
    enablePVC: bool = False
    pvcSize: str = "10Gi"
    storageClassName?: str

# Instantiate the spec (defaults)
zotSpec = ZotSpec {}

# Create resources using the user-supplied spec
service = svc.create_service(zotSpec)
deployment = dep.create_deployment(zotSpec)

# If PVC is enabled, create and patch the deployment
if zotSpec.enablePVC:
    volumeClaim = pvc.create_pvc(zotSpec)
    # Example: patch the deployment to mount the PVC
    deployment.spec.template.spec.volumes = [
        {
            name: "zot-data",
            persistentVolumeClaim: {
                claimName: volumeClaim.metadata.name
            }
        }
    ]
    deployment.spec.template.spec.containers[0].volumeMounts = [
        {
            name: "zot-data",
            mountPath: "/var/lib/registry"
        }
    ]

# Expose top-level objects
service
deployment
if zotSpec.enablePVC:
    volumeClaim


