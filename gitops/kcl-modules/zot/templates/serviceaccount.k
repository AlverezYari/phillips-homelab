"""
ServiceAccount resource template for Zot container registry.
"""

import ..pkg

# Create function for ServiceAccount
createServiceAccount = lambda config {
    apiVersion = "v1"
    kind = "ServiceAccount"
    metadata = {
        name = config.fullname(config)
        namespace = config.namespace
        labels = config.labels(config)
    }
}
