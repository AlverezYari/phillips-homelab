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

# Generate resources - make sure these are directly in the output
serviceaccount.createServiceAccount(config)  # Direct output
service.createService(config)  # Direct output
deployment.createDeployment(config)  # Direct output
