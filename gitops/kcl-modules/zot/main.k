"""
Main entry point for the Zot KCL module.
This file imports all templates and generates the Kubernetes resources.
"""

import pkg
import templates.serviceaccount as serviceaccount
import templates.service as service
import templates.deployment as deployment

# Create a config instance with settings
config = pkg.ZotConfig {
    # Override defaults with settings
    if option("namespace"):
        namespace = option("namespace")
    
    if option("instance"):
        instance = option("instance")
    
    if option("version"):
        version = option("version")
    
    if option("replicas"):
        replicas = int(option("replicas"))
    
    if option("serviceType"):
        serviceType = option("serviceType")
    
    if option("port"):
        port = int(option("port"))
}

# Generate resources
svcAccount = serviceaccount.createServiceAccount(config)
svc = service.createService(config)
deploy = deployment.createDeployment(config)

# Output resources as individual variables
_output_serviceaccount = svcAccount
_output_service = svc
_output_deployment = deploy
