"""
Service resource template for Zot container registry.
"""

import ..pkg

# Create function for Service
createService = lambda config {
    apiVersion = "v1"
    kind = "Service"
    metadata = {
        name = config.fullname(config)
        namespace = config.namespace
        labels = config.labels(config)
    }
    spec = {
        type = config.serviceType
        ports = [
            {
                port = config.port
                targetPort = config.name
                protocol = "TCP"
                name = config.name
            }
        ]
        selector = config.selectorLabels(config)
    }
}
