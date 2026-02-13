# Crictl Image Cleanup Helm Chart

This Helm chart deploys a DaemonSet for cleaning up unused container images on Kubernetes nodes using `crictl rmi --prune`.

## Overview

The crictl-image-cleanup chart helps manage container image storage on Kubernetes nodes by periodically removing unused images. It runs as a DaemonSet on each node to ensure local image cleanup, with an optional CronJob mode for centralized scheduling.

## Features

- **DaemonSet deployment**: Runs cleanup on all nodes by default
- **Per-node cleanup**: Each node cleans up its own local images
- **Configurable intervals**: Set custom cleanup intervals
- **Node selection**: Target specific nodes with nodeSelector
- **Tolerations**: Schedule on tainted nodes
- **Resource management**: Configurable resource limits and requests
- **Multiple runtime support**: Works with containerd, CRI-O, and other CRI-compatible runtimes
- **Optional CronJob mode**: Alternative centralized scheduling mode available

## Prerequisites

- Kubernetes 1.19+
- Container runtime with CRI support (containerd, CRI-O, etc.)
- `crictl` binary available in the container image

## Installation

### Basic Installation (DaemonSet mode - default)

```bash
helm install crictl-cleanup ./charts/crictl-image-cleanup
```

This will create a DaemonSet that runs on all nodes and cleans up unused images every 24 hours.

### Installation with Custom Cleanup Interval

```bash
helm install crictl-cleanup ./charts/crictl-image-cleanup \
  --set daemonSet.cleanupInterval=43200
```

This runs cleanup on each node every 12 hours (43200 seconds).

### Installation as CronJob (alternative mode)

```bash
helm install crictl-cleanup ./charts/crictl-image-cleanup \
  --set useDaemonSet=false \
  --set schedule="0 */6 * * *"
```

This runs the cleanup every 6 hours as a centralized CronJob (note: may not cover all nodes).

### Installation for CRI-O Runtime

```bash
helm install crictl-cleanup ./charts/crictl-image-cleanup \
  --set runtimeSocket.path=/var/run/crio/crio.sock
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Container image repository | `registry.k8s.io/build-image/distroless-iptables` |
| `image.tag` | Container image tag | `v0.5.10` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `schedule` | CronJob schedule (cron format) | `"0 2 * * *"` (daily at 2 AM) |
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
| `cronJob.successfulJobsHistoryLimit` | Number of successful jobs to retain | `3` |
| `cronJob.failedJobsHistoryLimit` | Number of failed jobs to retain | `1` |
| `cronJob.concurrencyPolicy` | Concurrency policy (Allow, Forbid, Replace) | `Forbid` |
| `cronJob.startingDeadlineSeconds` | Deadline for starting missed jobs | `300` |
| `cronJob.restartPolicy` | Pod restart policy | `OnFailure` |
| `cronJob.backoffLimit` | Number of retries before failure | `3` |
| `cronJob.ttlSecondsAfterFinished` | TTL for completed jobs | `86400` (1 day) |
| `runtimeSocket.path` | Path to container runtime socket | `/var/run/containerd/containerd.sock` |
| `runtimeSocket.type` | Socket type | `unix` |
| `useDaemonSet` | Deploy as DaemonSet instead of CronJob | `true` |
| `daemonSet.cleanupInterval` | Interval between cleanups (seconds, DaemonSet mode) | `86400` (24 hours) |
| `daemonSet.updateStrategy.type` | DaemonSet update strategy | `RollingUpdate` |

## Example Configurations

### Per-node cleanup every 6 hours with specific nodes (DaemonSet - recommended)

```yaml
daemonSet:
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

### CronJob mode for scheduled cleanup (alternative)

```yaml
useDaemonSet: false
schedule: "0 3 * * *"

nodeSelector:
  kubernetes.io/os: linux

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 200m
    memory: 256Mi
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

## How It Works

### DaemonSet Mode (Default)

1. A DaemonSet is created that runs on each node (based on nodeSelector/tolerations)
2. Each pod:
   - Connects to the local node's container runtime via the CRI socket
   - Enters a loop that:
     - Runs `crictl rmi --prune` to remove unused images from that node
     - Sleeps for the configured interval (default: 24 hours)
     - Repeats
3. Pods run continuously on each node, ensuring all nodes are cleaned up locally

### CronJob Mode (Alternative)

1. A CronJob is created with the specified schedule
2. At each scheduled time, a pod is created on a single node
3. The pod:
   - Connects to the container runtime via the CRI socket
   - Runs `crictl rmi --prune` to remove unused images
   - Reports success or failure
   - Terminates
4. **Note**: CronJob mode only cleans up images on the node where the pod runs. For cluster-wide cleanup, DaemonSet mode is recommended.

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

### Cleanup job fails with "crictl command not found"

Ensure your container image includes the `crictl` binary. The default image (`registry.k8s.io/build-image/distroless-iptables`) includes crictl.

### Cannot connect to container runtime

- Verify the `runtimeSocket.path` matches your runtime's socket location
- Check that the socket exists on the node: `ls -la /var/run/containerd/containerd.sock`
- Ensure the pod has the necessary permissions (privileged, hostNetwork, hostPID)

### Job succeeds but images aren't cleaned up

- Verify that images are actually unused (not referenced by running containers)
- Check the job logs for warnings or errors
- Consider adding `cleanup.extraArgs` for more aggressive cleanup

## Uninstallation

```bash
helm uninstall crictl-cleanup
```

## Inspiration

This chart was inspired by https://gist.github.com/alexeldeib/2a02ccb3db02ddb828a9c1ef04f2b955 and follows similar patterns to the `image-preloader` chart in this repository.
