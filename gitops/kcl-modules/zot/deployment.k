# zot/deployment.k
import k8s.io.apps.v1 as apps

fun create_deployment(spec) -> apps.Deployment:
    return apps.Deployment {
        metadata = {
            name: spec.name
            namespace: spec.namespace
            labels: {
                "app.kubernetes.io/name": spec.name
            }
        }
        spec = {
            replicas: spec.replicas
            selector = {
                matchLabels = {
                    "app.kubernetes.io/name": spec.name
                }
            }
            template = {
                metadata = {
                    labels = {
                        "app.kubernetes.io/name": spec.name
                    }
                }
                spec = {
                    containers: [
                        {
                            name: "zot",
                            image: spec.image,
                            ports: [
                                {
                                    name: "zot",
                                    containerPort: spec.servicePort
                                }
                            ]
                            # Example liveness/readiness probes
                            livenessProbe = {
                                initialDelaySeconds: 5
                                httpGet: {
                                    path: "/v2/"
                                    port: spec.servicePort
                                }
                            }
                            readinessProbe = {
                                initialDelaySeconds: 5
                                httpGet: {
                                    path: "/v2/"
                                    port: spec.servicePort
                                }
                            }
                        }
                    ]
                }
            }
        }
    }

