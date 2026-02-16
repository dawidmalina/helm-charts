# Crictl Image Cleanup Helm Chart

This Helm chart deploys a DaemonSet for cleaning up unused container images on Kubernetes nodes using `crictl rmi --prune`.

## Overview

The crictl-image-cleanup chart helps manage container image storage on Kubernetes nodes by periodically removing unused images. It runs as a DaemonSet on each node to ensure all nodes perform local image cleanup.

## Features

- **DaemonSet deployment**: Runs cleanup on all nodes
- **Per-node cleanup**: Each node cleans up its own local images
- **Configurable intervals**: Set custom cleanup intervals
- **Node selection**: Target specific nodes with nodeSelector
- **Tolerations**: Schedule on tainted nodes
- **Resource management**: Configurable resource limits and requests
- **Multiple runtime support**: Works with containerd, CRI-O, and other CRI-compatible runtimes

## Prerequisites

- Kubernetes 1.19+
- Container runtime with CRI support (containerd, CRI-O, etc.)
- Access to pull the `rancher/hardened-crictl` image (or use a custom image with crictl pre-installed)

## Installation

### Basic Installation

```bash
helm install crictl-cleanup ./charts/crictl-image-cleanup
```

This will create a DaemonSet that runs on all nodes and cleans up unused images every 24 hours.

### Installation with Custom Cleanup Interval

```bash
helm install crictl-cleanup ./charts/crictl-image-cleanup \
  --set cleanupInterval=43200
```

This runs cleanup on each node every 12 hours (43200 seconds).

### Installation for CRI-O Runtime

```bash
helm install crictl-cleanup ./charts/crictl-image-cleanup \
  --set runtimeSocket.path=/var/run/crio/crio.sock
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Container image repository | `rancher/hardened-crictl` |
| `image.tag` | Container image tag | `v1.31.1-build20251017` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `cleanup.prune` | Enable `--prune` flag for crictl rmi | `true` |
| `cleanup.extraArgs` | Additional arguments for crictl rmi | `[]` |
| `nodeSelector` | Node selector for pod scheduling | `{}` |
| `tolerations` | Tolerations for pod scheduling | `[]` |
| `podLabels` | Additional labels for pods | `{}` |
| `podAnnotations` | Additional annotations for pods | `{}` |
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `512Mi` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |
| `serviceAccount.create` | Create a service account | `true` |
| `serviceAccount.name` | Service account name | `""` |
| `serviceAccount.annotations` | Service account annotations | `{}` |
| `runtimeSocket.path` | Path to container runtime socket | `/var/run/containerd/containerd.sock` |
| `runtimeSocket.type` | Socket type | `unix` |
| `cleanupInterval` | Interval between cleanups (seconds) | `86400` (24 hours) |
| `updateStrategy.type` | DaemonSet update strategy | `RollingUpdate` |

## Example Configurations

### Per-node cleanup every 6 hours with specific nodes

```yaml
cleanupInterval: 21600  # 6 hours in seconds

nodeSelector:
  kubernetes.io/os: linux
  node-type: worker

tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

### CRI-O runtime configuration

```yaml
runtimeSocket:
  path: /var/run/crio/crio.sock
  type: unix

cleanup:
  prune: true
  extraArgs: []
```

### Using a different crictl version

To use a different version of crictl, specify a different image tag from [rancher/hardened-crictl](https://hub.docker.com/r/rancher/hardened-crictl/tags):

```yaml
image:
  repository: rancher/hardened-crictl
  tag: v1.30.1-build20251017  # Use a different crictl version
  pullPolicy: IfNotPresent
```

### Using a custom image with crictl pre-installed

If you need to use a different image or a private registry:

```yaml
image:
  repository: my-registry.com/crictl-image
  tag: latest
  pullPolicy: IfNotPresent
```

## How It Works

### DaemonSet Mode

1. A DaemonSet is created that runs on each node (based on nodeSelector/tolerations)
2. Each pod:
   - Creates a `/etc/crictl.yaml` configuration file with the runtime endpoint to prevent configuration warnings
   - Connects to the local node's container runtime via the CRI socket
   - Enters a loop that:
     - Runs `crictl rmi --prune` to remove unused images from that node
     - Sleeps for the configured interval (default: 24 hours)
     - Repeats
3. Pods run continuously on each node, ensuring all nodes are cleaned up locally

## Runtime Socket Paths

Common container runtime socket paths:

- **containerd**: `/var/run/containerd/containerd.sock` (default)
- **CRI-O**: `/var/run/crio/crio.sock`
- **containerd (alternative)**: `/run/containerd/containerd.sock`

## Security Considerations

This chart requires:
- **Privileged access**: The container runs with `privileged: true` to access the container runtime socket
- **Host networking**: Requires `hostNetwork: true` to access the runtime socket
- **Host PID namespace**: Uses `hostPID: true` for runtime access
- **Root user**: Runs as root (UID 0) to interact with the runtime

These permissions are necessary for `crictl` to communicate with the container runtime but should be deployed with appropriate RBAC controls.

## Troubleshooting

### DaemonSet fails with "crictl command not found"

The chart uses `rancher/hardened-crictl` image which includes the crictl binary. Ensure:
- You can pull the `rancher/hardened-crictl` image from Docker Hub
- If using a custom image, ensure it includes the crictl binary in the PATH
- Check the pod logs for more details: `kubectl logs -l app.kubernetes.io/name=crictl-image-cleanup`

### Cannot connect to container runtime

- Verify the `runtimeSocket.path` matches your runtime's socket location
- Check that the socket exists on the node: `ls -la /var/run/containerd/containerd.sock`
- Ensure the pod has the necessary permissions (privileged, hostNetwork, hostPID)

### DaemonSet succeeds but images aren't cleaned up

- Verify that images are actually unused (not referenced by running containers)
- Check the DaemonSet logs for warnings or errors: `kubectl logs -l app.kubernetes.io/name=crictl-image-cleanup`
- Consider adding `cleanup.extraArgs` for more aggressive cleanup

## Uninstallation

```bash
helm uninstall crictl-cleanup
```

## Inspiration

This chart was inspired by https://gist.github.com/alexeldeib/2a02ccb3db02ddb828a9c1ef04f2b955 and follows similar patterns to the `image-preloader` chart in this repository.
