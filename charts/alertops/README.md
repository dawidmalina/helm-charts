# AlertOps Helm Chart

This Helm chart deploys the AlertOps application.

## Overview

AlertOps is a simple application that runs on port 8080. This chart provides a minimal deployment with service and optional ingress.

## Installation

```bash
helm install alertops ./charts/alertops
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Image repository | `ghcr.io/dawidmalina/alertops` |
| `image.tag` | Image tag | `0.1.0` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `8080` |
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.host` | Ingress host | `alertops.example.com` |
| `ingress.paths` | Ingress paths | `[{"path": "/", "pathType": "Prefix"}]` |
| `ingress.tls` | Ingress TLS configuration | `[]` |
| `resources` | Resource limits and requests | `{}` |
| `nodeSelector` | Node selector for pod scheduling | `{}` |
| `tolerations` | Tolerations for pod scheduling | `[]` |
| `affinity` | Affinity rules for pod scheduling | `{}` |

## Example Values

### Basic deployment

```yaml
replicaCount: 1
```

### With Ingress

```yaml
ingress:
  enabled: true
  className: nginx
  host: alertops.example.com
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  tls:
    - secretName: alertops-tls
      hosts:
        - alertops.example.com
```

### With Resource Limits

```yaml
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

## Usage

### Install with custom values

```bash
helm install alertops ./charts/alertops \
  --set ingress.enabled=true \
  --set ingress.host=alertops.example.com
```

### Upgrade the deployment

```bash
helm upgrade alertops ./charts/alertops
```

### Uninstall

```bash
helm uninstall alertops
```

## Docker Image

The chart uses the official AlertOps Docker image:

```bash
docker pull ghcr.io/dawidmalina/alertops:0.1.0

docker run -d \
  -p 8080:8080 \
  --name alertops \
  ghcr.io/dawidmalina/alertops:0.1.0
```
