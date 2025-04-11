"""
ServiceAccount resource template for Zot container registry.
"""

import ..pkg

# Create function for ServiceAccount
createServiceAccount = lambda config {
    # Make sure to include all required Kubernetes fields
    apiVersion = "v1" 
    kind = "ServiceAccount"  # This is critical
    metadata = {
        name = config.fullname(config)
        namespace = config.namespace
        labels = config.labels(config)
    }
}
