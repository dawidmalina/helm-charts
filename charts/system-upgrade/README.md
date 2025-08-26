# System Upgrade Controller

A Helm chart for the [system-upgrade-controller](https://github.com/rancher/system-upgrade-controller) that manages automated upgrades of K3s and RKE2 clusters.

## Description

The system-upgrade-controller is a Kubernetes operator that manages the upgrade of nodes in a cluster. It is designed to upgrade K3s and RKE2 clusters by managing the upgrade of both control-plane (server) nodes and worker (agent) nodes.

## Prerequisites

- Kubernetes 1.16+
- Helm 3.0+
- Cluster-admin permissions to create CRDs and cluster-scoped resources

## Installation

```bash
# Add the repository
helm repo add dawidmalina https://dawidmalina.github.io/helm-charts
helm repo update

# Install the chart
helm install system-upgrade dawidmalina/system-upgrade \
  --create-namespace \
  --namespace system-upgrade
```

## Configuration

The following table lists the configurable parameters and their default values.

### Global Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nameOverride` | Override the name of the chart | `""` |
| `fullnameOverride` | Override the full name of the chart | `""` |
| `namespaceOverride` | Override the namespace for all resources | `""` |
| `createNamespace` | Create the namespace if it doesn't exist | `true` |
| `imagePullSecrets` | Image pull secrets for all images | `[]` |
| `nodeSelector` | Node selector for all pods | `{"kubernetes.io/os": "linux"}` |
| `tolerations` | Tolerations for all pods | See values.yaml |
| `priorityClassName` | Priority class name for all pods | `"system-node-critical"` |

### Controller Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `controller.replicaCount` | Number of controller replicas | `1` |
| `controller.image.registry` | Container registry for controller image | `""` |
| `controller.image.repository` | Controller image repository | `"rancher/system-upgrade-controller"` |
| `controller.image.pullPolicy` | Controller image pull policy | `"IfNotPresent"` |
| `controller.image.tag` | Controller image tag | `""` (uses chart appVersion) |
| `controller.debug` | Enable debug mode | `false` |
| `controller.threads` | Number of worker threads | `2` |
| `controller.planPollingInterval` | Plan polling interval | `"15m"` |
| `controller.resources` | Resource limits and requests | See values.yaml |

### RBAC Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `rbac.create` | Create RBAC resources | `true` |
| `rbac.additionalRules` | Additional rules for the ClusterRole | `[]` |

### Service Account Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `controller.serviceAccount.create` | Create a service account | `true` |
| `controller.serviceAccount.name` | Name of the service account | `""` (generated) |
| `controller.serviceAccount.annotations` | Annotations for the service account | `{}` |

### Plan Configuration

#### System Plan (Control-plane nodes)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `plans.system.enabled` | Enable system plan | `true` |
| `plans.system.concurrency` | Concurrency for system plan upgrades | `1` |
| `plans.system.version` | K3s/RKE2 version to upgrade to | `"v1.29.0+k3s1"` |
| `plans.system.cordon` | Cordon nodes during upgrade | `true` |
| `plans.system.drain` | Drain configuration | See values.yaml |
| `plans.system.tolerations` | Tolerations for system plan jobs | See values.yaml |
| `plans.system.upgrade.image` | Image for system upgrade job | `"rancher/k3s-upgrade"` |

#### Agent Plan (Worker nodes)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `plans.agent.enabled` | Enable agent plan | `true` |
| `plans.agent.concurrency` | Concurrency for agent plan upgrades | `2` |
| `plans.agent.version` | K3s/RKE2 version to upgrade to | `"v1.29.0+k3s1"` |
| `plans.agent.cordon` | Cordon nodes during upgrade | `true` |
| `plans.agent.drain` | Drain configuration | See values.yaml |
| `plans.agent.tolerations` | Tolerations for agent plan jobs | See values.yaml |
| `plans.agent.upgrade.image` | Image for agent upgrade job | `"rancher/k3s-upgrade"` |

## Usage Examples

### Basic Installation

```bash
helm install system-upgrade dawidmalina/system-upgrade \
  --create-namespace \
  --namespace system-upgrade
```

### Custom K3s Version

```bash
helm install system-upgrade dawidmalina/system-upgrade \
  --create-namespace \
  --namespace system-upgrade \
  --set plans.system.version="v1.28.5+k3s1" \
  --set plans.agent.version="v1.28.5+k3s1"
```

### Air-gapped Environment

```bash
helm install system-upgrade dawidmalina/system-upgrade \
  --create-namespace \
  --namespace system-upgrade \
  --set controller.image.registry="harbor.example.com" \
  --set kubectl.image.registry="harbor.example.com" \
  --set plans.system.upgrade.image="harbor.example.com/rancher/k3s-upgrade" \
  --set plans.agent.upgrade.image="harbor.example.com/rancher/k3s-upgrade"
```

### Disable Agent Plan (Control-plane only)

```bash
helm install system-upgrade dawidmalina/system-upgrade \
  --create-namespace \
  --namespace system-upgrade \
  --set plans.agent.enabled=false
```

### Custom Resource Limits

```bash
helm install system-upgrade dawidmalina/system-upgrade \
  --create-namespace \
  --namespace system-upgrade \
  --set controller.resources.limits.memory="256Mi" \
  --set controller.resources.requests.memory="256Mi"
```

## Monitoring

### Check Controller Status

```bash
kubectl -n system-upgrade get deployments
kubectl -n system-upgrade get pods
```

### Monitor Upgrade Progress

```bash
# Check plans
kubectl -n system-upgrade get plans

# Check upgrade jobs
kubectl -n system-upgrade get jobs

# View controller logs
kubectl -n system-upgrade logs -l app.kubernetes.io/component=controller

# View upgrade job logs
kubectl -n system-upgrade logs -l upgrade.cattle.io/plan
```

## Troubleshooting

### Common Issues

1. **Controller not starting**: Check RBAC permissions and image availability
2. **Plans not executing**: Verify node selectors and tolerations
3. **Upgrade jobs failing**: Check job logs and node resources

### Debug Commands

```bash
# Describe plan status
kubectl -n system-upgrade describe plan system-upgrade-system
kubectl -n system-upgrade describe plan system-upgrade-agent

# Check events
kubectl -n system-upgrade get events --sort-by=.metadata.creationTimestamp

# View detailed job logs
kubectl -n system-upgrade logs job/<job-name>
```

## Security Considerations

- The controller runs with minimal privileges using a dedicated service account
- Upgrade jobs run as privileged containers (required for system upgrades)
- Security contexts enforce non-root execution where possible
- Network policies should allow controller to communicate with the Kubernetes API

## Contributing

Please read the contributing guidelines and submit issues or pull requests to the [helm-charts repository](https://github.com/dawidmalina/helm-charts).

## License

This chart is licensed under the Apache License 2.0.

## References

- [System Upgrade Controller](https://github.com/rancher/system-upgrade-controller)
- [K3s Documentation](https://docs.k3s.io/)
- [RKE2 Documentation](https://docs.rke2.io/)