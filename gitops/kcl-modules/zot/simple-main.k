"""
Simplified Zot configuration generator.
"""

# Define the service account resource
sa = {
    apiVersion = "v1"
    kind = "ServiceAccount"
    metadata = {
        name = "release-name-zot"
        namespace = "zot"
        labels = {
            "helm.sh/chart" = "zot-0.1.67"
            "app.kubernetes.io/name" = "zot"
            "app.kubernetes.io/instance" = "release-name"
            "app.kubernetes.io/version" = "v2.1.2"
            "app.kubernetes.io/managed-by" = "Helm"
        }
    }
}

# Define the service resource
svc = {
    apiVersion = "v1"
    kind = "Service"
    metadata = {
        name = "release-name-zot"
        namespace = "zot"
        labels = {
            "helm.sh/chart" = "zot-0.1.67"
            "app.kubernetes.io/name" = "zot"
            "app.kubernetes.io/instance" = "release-name"
            "app.kubernetes.io/version" = "v2.1.2"
            "app.kubernetes.io/managed-by" = "Helm"
        }
    }
    spec = {
        type = "ClusterIP"
        ports = [
            {
                port = 5000
                targetPort = "zot"
                protocol = "TCP"
                name = "zot"
            }
        ]
        selector = {
            "app.kubernetes.io/name" = "zot"
            "app.kubernetes.io/instance" = "release-name"
        }
    }
}

# Output each resource directly
sa  # Direct output
svc  # Direct output
