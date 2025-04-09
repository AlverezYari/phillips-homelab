# zot/pvc.k
import k8s.io.core.v1 as core

fun create_pvc(spec) -> core.PersistentVolumeClaim:
    return core.PersistentVolumeClaim {
        metadata = {
            name: "\(spec.name)-data"
            namespace: spec.namespace
            labels: {
                "app.kubernetes.io/name": spec.name
            }
        }
        spec = {
            accessModes = ["ReadWriteOnce"]
            resources.requests = {
                storage: spec.pvcSize
            }
            if spec.storageClassName != None:
                storageClassName: spec.storageClassName
        }
    }

