"""
ServiceAccount resource template for Zot container registry.
"""

import ..pkg

# Create function for ServiceAccount - make sure it returns a COMPLETE K8s resource
createServiceAccount = lambda config {
    apiVersion = "v1"  # Required
    kind = "ServiceAccount"  # Required
    metadata = {
        name = config.fullname(config)
        namespace = config.namespace
        labels = config.labels(config)
    }
}
