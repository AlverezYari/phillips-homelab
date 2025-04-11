"""
Package zot defines the core schemas for the Zot container registry.
"""

# Schema definitions
schema ZotConfig:
    """Main configuration schema for Zot container registry"""
    name: str = "zot"
    namespace: str = "zot"
    version: str = "v2.1.2"
    instance: str = "release-name"
    image: str = "ghcr.io/project-zot/zot-linux-amd64:v2.1.2"
    imagePullPolicy: str = "IfNotPresent"
    replicas: int = 1
    port: int = 5000
    serviceType: str = "ClusterIP"
    deploymentStrategyType: str = "RollingUpdate"
    securityContext = None
    containerSecurityContext = None
    resources = None
    env = None
    
    # Helper functions for generating labels and names
    labels = lambda self {
        {
            "helm.sh/chart" = "${self.name}-0.1.67"
            "app.kubernetes.io/name" = self.name
            "app.kubernetes.io/instance" = self.instance
            "app.kubernetes.io/version" = self.version
            "app.kubernetes.io/managed-by" = "Helm"
        }
    }
    
    selectorLabels = lambda self {
        {
            "app.kubernetes.io/name" = self.name
            "app.kubernetes.io/instance" = self.instance
        }
    }
    
    fullname = lambda self {
        "${self.instance}-${self.name}"
    }
