# Example: Using image-preloader with gha-runner-scale-set

This example demonstrates how to use the image-preloader chart to preload Docker images and then use them with gha-runner-scale-set.

## Step 1: Deploy image-preloader to preload images

```bash
# Create values file for image-preloader
cat > image-preloader-values.yaml << EOF
images:
  - selenium/standalone-firefox:4.23.1-20240820
  - selenium/video:ffmpeg-4.3.1-20230404

hostPath: /opt/runner/images

nodeSelector:
  kubernetes.io/os: linux
  node-role.kubernetes.io/runner: "true"

tolerations:
  - key: "node-role.kubernetes.io/runner"
    operator: "Exists"
    effect: "NoSchedule"

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

# Wait for DaemonSet to complete image preloading
kubectl rollout status daemonset/image-preloader

# Verify images were saved
kubectl exec -it daemonset/image-preloader -c pause -- ls -lh /opt/runner/images/selenium/
```

## Step 2: Configure gha-runner-scale-set to use preloaded images

```yaml
# gha-runner-scale-set values.yaml
containerMode:
  type: "dind"

preloadImages:
  enabled: true
  hostPath: /opt/runner/images
  imageTarFiles:
    - selenium/standalone-firefox.tar
    - selenium/video.tar

template:
  spec:
    nodeSelector:
      kubernetes.io/os: linux
      node-role.kubernetes.io/runner: "true"
    tolerations:
      - key: "node-role.kubernetes.io/runner"
        operator: "Exists"
        effect: "NoSchedule"
```

## Benefits

1. **Faster runner startup**: Images are pre-cached on nodes, eliminating pull time
2. **Reduced registry load**: Images are pulled once per node, not per runner pod
3. **Consistent versions**: Ensures all runners use the same image versions
4. **Bandwidth optimization**: Especially useful for large images like Selenium

## Notes

- The image-preloader DaemonSet runs as an init container that exits after preloading
- A pause container keeps the pod running for Kubernetes to track the DaemonSet
- Images are re-pulled only when the images list changes (tracked via checksum annotation)
- Ensure nodes have sufficient disk space in /opt/runner/images for all tar files
