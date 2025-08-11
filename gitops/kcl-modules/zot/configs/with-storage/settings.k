"""
Default settings for the Zot KCL module.
"""

# Settings for zot
namespace = "zot"
instance = "release-name"
version = "v2.1.2"
replicas = 1
serviceType = "ClusterIP"
port = 5000
resources = {
    "limits": {
        "cpu": "500m",
        "memory": "512Mi"
    },
    "requests": {
        "cpu": "100m",
        "memory": "128Mi"
    }
}
