"""
Example of using the Zot KCL module with persistent storage.
"""

# Import with relative paths for local testing
import ...pkg as pkg
import ...templates.serviceaccount as serviceaccount
import ...templates.service as service
import ...templates.deployment as deployment

# Get storage size from options or use default
storageSize = option("storage") or "10Gi"

# Create a custom configuration
_config = pkg.ZotConfig {
    namespace = "zot-storage"
    instance = "storage"
}

# Create a PersistentVolumeClaim resource
pvc = {
    apiVersion = "v1"  # Required
    kind = "PersistentVolumeClaim"  # Required
    metadata = {
        name = _config.fullname(_config)
        namespace = _config.namespace
        labels = _config.labels(_config)
    }
    spec = {
        accessModes = ["ReadWriteOnce"]
        resources = {
            requests = {
                storage = storageSize
            }
        }
        storageClassName = "standard"
    }
}

# Generate base resources
svcAccount = serviceaccount.createServiceAccount(_config)
svc = service.createService(_config)
_deploy = deployment.createDeployment(_config)

# Add volume mount to the deployment
_deploy.spec.template.spec.containers[0] |= {
    volumeMounts = [
        {
            name = "zot-data"
            mountPath = "/var/lib/registry"
        }
    ]
}

# Add volume to the pod
_deploy.spec.template.spec |= {
    volumes = [
        {
            name = "zot-data"
            persistentVolumeClaim = {
                claimName = _config.fullname(_config)
            }
        }
    ]
}

# Output each Kubernetes resource directly
svcAccount  # Direct output
svc  # Direct output
_deploy  # Direct output
pvc  # Direct output
