"""
Deployment resource template for Zot container registry.
"""

import ..pkg

# Create function for Deployment - make sure it returns a COMPLETE K8s resource
createDeployment = lambda config {
    apiVersion = "apps/v1"  # Required
    kind = "Deployment"  # Required
    metadata = {
        name = config.fullname(config)
        namespace = config.namespace
        labels = config.labels(config)
    }
    spec = {
        replicas = config.replicas
        strategy = {
            type = config.deploymentStrategyType
        }
        selector = {
            matchLabels = config.selectorLabels(config)
        }
        template = {
            metadata = {
                annotations = {}
                labels = config.selectorLabels(config)
            }
            spec = {
                serviceAccountName = config.fullname(config)
                securityContext = config.securityContext
                containers = [
                    {
                        name = config.name
                        securityContext = config.containerSecurityContext
                        image = config.image
                        imagePullPolicy = config.imagePullPolicy
                        env = config.env
                        ports = [
                            {
                                name = config.name
                                containerPort = config.port
                                protocol = "TCP"
                            }
                        ]
                        livenessProbe = {
                            initialDelaySeconds = 5
                            httpGet = {
                                path = "/v2/"
                                port = config.port
                                scheme = "HTTP"
                            }
                        }
                        readinessProbe = {
                            initialDelaySeconds = 5
                            httpGet = {
                                path = "/v2/"
                                port = config.port
                                scheme = "HTTP"
                            }
                        }
                        startupProbe = {
                            initialDelaySeconds = 5
                            periodSeconds = 10
                            failureThreshold = 3
                            httpGet = {
                                path = "/v2/"
                                port = config.port
                                scheme = "HTTP"
                            }
                        }
                        resources = config.resources
                    }
                ]
                dnsPolicy = "ClusterFirst"
            }
        }
    }
}
