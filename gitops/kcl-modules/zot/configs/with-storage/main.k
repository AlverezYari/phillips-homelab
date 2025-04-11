"""
Example of using the Zot KCL module with persistent storage.
"""

# Import with relative paths for local testing
import ...pkg as pkg
import ...templates.serviceaccount as serviceaccount
import ...templates.service as service
import ...templates.deployment as deployment

# Create a custom configuration
_config = pkg.ZotConfig {
    namespace = "zot-storage"
    instance = "storage"
}

# Get storage size from options or use default
storageSize = option("storage") or "10Gi"

# Create a PersistentVolumeClaim for Zot
pvc = {
    apiVersion = "v1"
    kind = "PersistentVolumeClaim"
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

# Generate resources with our custom config
svcAccount = serviceaccount.createServiceAccount(_config)
svc = service.createService(_config)
_deploy = deployment.createDeployment(_config)

# Add volume mount to the deployment - we need to create a modified copy
_container = _deploy.spec.template.spec.containers[0]
_container |= {
    volumeMounts = [
        {
            name = "zot-data"
            mountPath = "/var/lib/registry"
        }
    ]
}

# Add volume to the pod - we need to create a modified copy
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

# Generate resources
svcAccount = serviceaccount.createServiceAccount(config)
svc = service.createService(config)
deploy = deployment.createDeployment(config)

# Output core resources
[svcAccount, svc, deploy]
