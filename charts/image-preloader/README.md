# Image Preloader Helm Chart

This Helm chart deploys a DaemonSet that preloads Docker images onto nodes by pulling them and saving them as tar files to a hostPath.

## Overview

The image preloader chart helps optimize container startup times by pre-caching Docker images on nodes. It runs as a DaemonSet and uses Docker-in-Docker to pull specified images and save them as tar files on the host filesystem.

## Features

- **DaemonSet deployment**: Ensures images are preloaded on all matching nodes
- **Node selection**: Supports nodeSelector for targeting specific nodes
- **Tolerations**: Configurable tolerations for scheduling on tainted nodes
- **Age-based refresh**: Automatically rebuilds image tar files older than the configured age (default: 7 days)
- **Automatic tar naming**: Converts image names to standardized tar filenames
  - Preserves `<user>/<image_name>` format (last two path components)
  - Example: `selenium/standalone-firefox:4.23.1-20240820` → `selenium/standalone-firefox_4.23.1-20240820.tar`
  - Example: `harbor.example.com/hub/selenium/standalone-firefox:4.23.1-20240820` → `selenium/standalone-firefox_4.23.1-20240820.tar`

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
| `maxImageAge` | Maximum age (in days) for cached image tar files. If older, rebuild. Set to 0 to always rebuild, or negative to disable age check | `7` |
| `nodeSelector` | Node selector for pod scheduling | `{}` |
| `tolerations` | Tolerations for pod scheduling | `[]` |
| `podLabels` | Additional labels for pods | `{}` |
| `podAnnotations` | Additional annotations for pods | `{}` |
| `resources` | Resource limits and requests | `{}` |
| `serviceAccount.create` | Create a service account | `true` |
| `serviceAccount.name` | Service account name | `""` |
| `updateStrategy` | DaemonSet update strategy | `RollingUpdate` |
| `dockerd.mtu` | Docker daemon MTU setting | `1450` |
| `dockerd.groupGid` | Docker group GID | `123` |
| `dockerd.resources` | Resource limits and requests for dind sidecar | `{"limits": {"cpu": "500m", "memory": "1Gi"}, "requests": {"cpu": "100m", "memory": "256Mi"}}` |

## Example Values

```yaml
images:
  - selenium/standalone-firefox:4.23.1-20240820
  - selenium/video:ffmpeg-4.3.1-20230404

hostPath: /opt/runner/images

# Rebuild image tar files older than 14 days
maxImageAge: 14

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
3. A Docker-in-Docker (dind) sidecar init container runs the Docker daemon with `restartPolicy: Always`, which keeps it running throughout the pod lifecycle
4. The preload-images regular container waits for Docker to be ready, then for each image in the `images` list:
   - Checks if a tar file already exists for the image
   - If the file exists, checks its age (modification time)
   - If the file is older than `maxImageAge` days (default: 7), pulls the image and rebuilds the tar file
   - If the file is within the age limit, skips pulling
   - If the file doesn't exist, pulls the image and saves it as a tar file
   - Stores it in the configured hostPath
5. After completing the initial preload, the preload-images container enters an hourly check loop:
   - Sleeps for 1 hour
   - Re-checks all images and rebuilds any that exceed the age threshold
   - This ensures images are kept fresh even if the pod runs continuously for extended periods
6. The dind sidecar init container continues providing Docker daemon services throughout the pod lifecycle

### Age-Based Refresh Configuration

The `maxImageAge` parameter controls when tar files are rebuilt:
- **Default (7)**: Rebuilds tar files older than 7 days
- **0**: Always rebuilds tar files, even if they exist
- **Negative value (e.g., -1)**: Disables age check, never rebuilds if file exists (original behavior)
- **Custom value**: Rebuilds tar files older than specified number of days

**Note**: This chart requires Kubernetes 1.29+ for sidecar init container support (`restartPolicy: Always` on init containers).

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
    - selenium/standalone-firefox_4.23.1-20240820.tar
    - selenium/video_ffmpeg-4.3.1-20230404.tar
```

## Requirements

- Kubernetes 1.29+ (for sidecar init container support)
  - Sidecar init containers became beta in Kubernetes 1.29 (enabled by default)
  - Became stable (GA) in Kubernetes 1.30
  - For Kubernetes 1.29, ensure the `SidecarContainers` feature gate is enabled (it should be enabled by default in beta)

## Notes

- The DaemonSet requires privileged access to run Docker-in-Docker
- Ensure the hostPath directory has sufficient space for all images
- Images are re-pulled when the image list changes (tracked via pod annotation checksum)
- Images are automatically re-pulled when tar files exceed the configured age (`maxImageAge`)
