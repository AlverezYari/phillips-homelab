"""
Test Pod resources template for Zot container registry.
"""

import ..pkg

# Create function for Test Pod
createTestConnection = lambda config, fails=False {
    suffix = "-fails" if fails else ""
    
    apiVersion = "v1"
    kind = "Pod"
    metadata = {
        name = "${config.fullname(config)}-test-connection${suffix}"
        namespace = config.namespace
        labels = config.labels(config)
        annotations = {
            "helm.sh/hook" = "test"
            "helm.sh/hook-delete-policy" = "before-hook-creation,hook-succeeded,hook-failed"
        }
    }
    spec = {
        containers = [
            {
                name = "wget"
                image = "alpine:3.18"
                command = [
                    "sh"
                    "-c"
                    """
                    scheme="http"
                    echo "$scheme"
                      wget --no-check-certificate $scheme://${config.fullname(config)}:${config.port}/v2/_catalog
                    """
                ]
            }
        ]
        restartPolicy = "Never"
    }
}
