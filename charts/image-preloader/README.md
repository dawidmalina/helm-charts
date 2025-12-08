# Image Preloader Helm Chart

This Helm chart deploys a DaemonSet that preloads Docker images onto nodes by pulling them and saving them as tar files to a hostPath.

## Overview

The image preloader chart helps optimize container startup times by pre-caching Docker images on nodes. It runs as a DaemonSet and uses Docker-in-Docker to pull specified images and save them as tar files on the host filesystem.

## Features

- **DaemonSet deployment**: Ensures images are preloaded on all matching nodes
- **Node selection**: Supports nodeSelector for targeting specific nodes
- **Tolerations**: Configurable tolerations for scheduling on tainted nodes
- **Automatic tar naming**: Converts image names to standardized tar filenames
  - Example: `selenium/standalone-firefox:4.23.1-20240820` → `selenium/standalone-firefox.tar`

## Installation

```bash
helm install image-preloader ./charts/image-preloader \
  --set images[0]=selenium/standalone-firefox:4.23.1-20240820 \
  --set images[1]=selenium/video:ffmpeg-4.3.1-20230404
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Docker-in-Docker image repository | `docker` |
| `image.tag` | Docker-in-Docker image tag | `27-dind` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `images` | List of Docker images to preload | `[]` |
| `hostPath` | Host path where tar files will be saved | `/opt/runner/images` |
| `nodeSelector` | Node selector for pod scheduling | `{}` |
| `tolerations` | Tolerations for pod scheduling | `[]` |
| `podLabels` | Additional labels for pods | `{}` |
| `podAnnotations` | Additional annotations for pods | `{}` |
| `resources` | Resource limits and requests | `{}` |
| `serviceAccount.create` | Create a service account | `true` |
| `serviceAccount.name` | Service account name | `""` |
| `enableRestartPolicy` | Enable container restartPolicy (requires Kubernetes 1.28+) | `false` |
| `updateStrategy` | DaemonSet update strategy | `RollingUpdate` |

## Example Values

```yaml
images:
  - selenium/standalone-firefox:4.23.1-20240820
  - selenium/video:ffmpeg-4.3.1-20230404

hostPath: /opt/runner/images

nodeSelector:
  kubernetes.io/os: linux

tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"

resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi
```

## How It Works

1. A service account is created for the DaemonSet pods
2. The DaemonSet runs on all matching nodes based on nodeSelector and tolerations
3. A Docker-in-Docker sidecar container runs the Docker daemon
4. An init container waits for Docker to be ready, then for each image in the `images` list:
   - Pulls the image from the registry
   - Saves it as a tar file with a standardized name
   - Stores it in the configured hostPath
5. Once complete, the init container exits and a minimal pause container keeps the pod running (consumes only 10m CPU / 32Mi memory per node)
6. Optionally (with `enableRestartPolicy: true` on Kubernetes 1.28+), the sidecar and pause containers exit after init completion, showing pods as "Completed"

## Usage with gha-runner-scale-set

This chart is designed to work with the `gha-runner-scale-set` chart's preloadImages feature. 

### Step 1: Deploy image-preloader to preload images

```bash
# Create values file for image-preloader
cat > image-preloader-values.yaml << EOF
images:
  - selenium/standalone-firefox:4.23.1-20240820
  - selenium/video:ffmpeg-4.3.1-20230404

hostPath: /opt/runner/images

nodeSelector:
  kubernetes.io/os: linux

resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi
EOF

# Install the chart
helm install image-preloader ./charts/image-preloader -f image-preloader-values.yaml
```

### Step 2: Configure gha-runner-scale-set to use preloaded images

After running this chart to populate the hostPath with tar files, configure the runner scale set to load these images:

```yaml
# gha-runner-scale-set values.yaml
preloadImages:
  enabled: true
  hostPath: /opt/runner/images
  imageTarFiles:
    - selenium/standalone-firefox.tar
    - selenium/video.tar
```

### Optional: Enable Pod Completion (Kubernetes 1.28+)

To make pods complete after successful image preloading instead of running indefinitely, enable the `restartPolicy` feature:

```yaml
enableRestartPolicy: true
```

This requires Kubernetes 1.28+ for per-container `restartPolicy` support. When enabled:
- The dind and pause containers will exit after the init container completes
- Pods will show as "Completed" instead of "Running"
- Resource consumption drops to zero after completion

## Notes

- The DaemonSet requires privileged access to run Docker-in-Docker
- Ensure the hostPath directory has sufficient space for all images
- Images are re-pulled when the image list changes (tracked via pod annotation checksum)
