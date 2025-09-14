# OS Upgrade Plan for K3s Clusters

This directory contains a production-ready Kubernetes Plan for performing OS upgrades on K3s nodes using the chroot approach with system-upgrade-controller.

## Overview

The OS upgrade plan provides automated, safe operating system updates for Ubuntu/Debian-based K3s cluster nodes with the following features:

- **Security-first approach**: Defaults to security-only updates using unattended-upgrades
- **Safe rolling updates**: Upgrades one node at a time (concurrency: 1)
- **Chroot isolation**: Uses chroot to safely upgrade the host OS from within containers
- **Pre-upgrade validation**: Comprehensive system health checks before upgrading
- **Post-upgrade verification**: Validates system state after upgrades
- **Reboot coordination**: Handles kernel updates requiring system reboots
- **Comprehensive logging**: Detailed logs and status reporting
- **Rollback capability**: Error handling with automatic rollback on failures
- **Disabled by default**: Requires explicit node labeling for safety

## Prerequisites

1. **K3s cluster** with system-upgrade-controller deployed
2. **Ubuntu/Debian** based nodes (amd64 architecture only)
3. **Cluster admin permissions** to create Plans and label nodes
4. **unattended-upgrades package** installed on all nodes
5. **Sufficient disk space** (minimum 2GB free on root filesystem)

## Installation

### Step 1: Deploy the OS Upgrade Plan

```bash
# Apply the OS upgrade plan and scripts
kubectl apply -f manifests/system-upgrade/os-upgrade-plan.yaml

# Verify the plan is created (but disabled)
kubectl get plans -n system-upgrade
```

### Step 2: Enable OS Upgrades on Specific Nodes

The plan is **disabled by default** for safety. To enable OS upgrades on specific nodes:

```bash
# Enable OS upgrades on a specific node
kubectl label node <node-name> upgrade.cattle.io/os-upgrade-enabled=true

# Enable on all worker nodes (example)
kubectl label nodes -l '!node-role.kubernetes.io/control-plane' upgrade.cattle.io/os-upgrade-enabled=true

# Enable on control-plane nodes (be careful!)
kubectl label nodes -l 'node-role.kubernetes.io/control-plane' upgrade.cattle.io/os-upgrade-enabled=true
```

### Step 3: Monitor Upgrade Progress

```bash
# Check plan status
kubectl describe plan os-upgrade-plan -n system-upgrade

# Monitor upgrade jobs
kubectl get jobs -n system-upgrade -l upgrade.cattle.io/plan=os-upgrade-plan

# View upgrade logs
kubectl logs -n system-upgrade -l upgrade.cattle.io/plan=os-upgrade-plan -f

# Check node annotations for upgrade status
kubectl get nodes -o yaml | grep -A5 -B5 upgrade.cattle.io
```

## Configuration

### Environment Variables

The upgrade plan can be customized using the following environment variables in the Plan spec:

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_SECURITY_UPDATES_ONLY` | `true` | Only install security updates |
| `MAX_UPGRADE_TIME` | `1800` | Maximum upgrade time in seconds |
| `UPGRADE_LOG_LEVEL` | `info` | Log level (debug, info, warn, error) |
| `REBOOT_REQUIRED_FILE` | `/host/var/run/reboot-required` | File indicating reboot needed |

### Customizing Security Updates

To enable full system updates instead of security-only:

```bash
# Edit the plan to change ENABLE_SECURITY_UPDATES_ONLY to false
kubectl patch plan os-upgrade-plan -n system-upgrade --type='merge' -p='{"spec":{"upgrade":{"env":[{"name":"ENABLE_SECURITY_UPDATES_ONLY","value":"false"}]}}}'
```

### Adjusting Upgrade Timeout

For slower systems, increase the upgrade timeout:

```bash
kubectl patch plan os-upgrade-plan -n system-upgrade --type='merge' -p='{"spec":{"upgrade":{"env":[{"name":"MAX_UPGRADE_TIME","value":"3600"}]}}}'
```

## Usage Examples

### Example 1: Upgrade a Single Test Node

```bash
# Label a test node for upgrade
kubectl label node worker-1 upgrade.cattle.io/os-upgrade-enabled=true

# Monitor the upgrade
kubectl logs -n system-upgrade -l upgrade.cattle.io/plan=os-upgrade-plan -f

# Check if reboot is required
kubectl get node worker-1 -o yaml | grep upgrade.cattle.io/reboot-required
```

### Example 2: Rolling Upgrade of All Worker Nodes

```bash
# Enable upgrades on all worker nodes
kubectl label nodes -l '!node-role.kubernetes.io/control-plane' upgrade.cattle.io/os-upgrade-enabled=true

# The system-upgrade-controller will automatically upgrade nodes one by one
# Monitor progress
watch kubectl get nodes -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[?(@.type=='Ready')].status,UPGRADE-STATUS:.metadata.labels.upgrade\.cattle\.io/os-upgrade-enabled,LAST-UPGRADE:.metadata.annotations.upgrade\.cattle\.io/os-upgrade-completed"
```

### Example 3: Emergency Disable

```bash
# Disable upgrades on all nodes immediately
kubectl label nodes upgrade.cattle.io/os-upgrade-enabled-

# Or disable the entire plan
kubectl patch plan os-upgrade-plan -n system-upgrade --type='merge' -p='{"spec":{"nodeSelector":{"matchExpressions":[{"key":"upgrade.cattle.io/disabled","operator":"Exists"}]}}}'
```

## Monitoring and Logging

### Log Files

Upgrade logs are stored on each node at:
- `/var/log/system-upgrade/upgrade.log` - Main upgrade log
- `/var/log/system-upgrade/upgrade-report-<node>-<timestamp>.json` - Structured upgrade report

### Kubernetes Events

Monitor cluster events for upgrade progress:

```bash
kubectl get events -n system-upgrade --sort-by=.metadata.creationTimestamp
```

### Node Annotations

The plan adds several annotations to track upgrade status:

- `upgrade.cattle.io/os-upgrade-completed` - Timestamp of successful upgrade
- `upgrade.cattle.io/os-upgrade-failed` - Timestamp of failed upgrade
- `upgrade.cattle.io/reboot-required` - Timestamp when reboot was scheduled

### Prometheus Metrics (if available)

The system-upgrade-controller exposes metrics that can be monitored:

```bash
# Example Prometheus queries
system_upgrade_plan_status{plan="os-upgrade-plan"}
system_upgrade_job_duration_seconds{plan="os-upgrade-plan"}
```

## Troubleshooting

### Common Issues

#### 1. Plan Not Starting Jobs

**Symptoms**: No upgrade jobs are created despite labeled nodes.

**Diagnosis**:
```bash
kubectl describe plan os-upgrade-plan -n system-upgrade
kubectl get nodes -l upgrade.cattle.io/os-upgrade-enabled=true
```

**Solutions**:
- Verify system-upgrade-controller is running
- Check node selector matches labeled nodes
- Ensure RBAC permissions are correct

#### 2. Upgrade Jobs Failing

**Symptoms**: Jobs fail during execution.

**Diagnosis**:
```bash
kubectl logs -n system-upgrade job/<job-name>
kubectl describe job <job-name> -n system-upgrade
```

**Common Causes & Solutions**:
- **Insufficient disk space**: Free up space or increase disk size
- **Network connectivity**: Check DNS resolution and package repository access
- **Package conflicts**: Manually resolve package issues on the node
- **Permission issues**: Verify privileged containers are allowed

#### 3. Node Stuck in Upgrade

**Symptoms**: Node shows upgrade in progress but job completed.

**Diagnosis**:
```bash
kubectl get node <node-name> -o yaml | grep upgrade.cattle.io
```

**Solutions**:
```bash
# Remove stuck labels manually
kubectl label node <node-name> upgrade.cattle.io/os-upgrade-in-progress-
kubectl annotate node <node-name> upgrade.cattle.io/os-upgrade-failed="$(date -Iseconds)"
```

#### 4. Reboot Not Happening

**Symptoms**: Node marked for reboot but system doesn't restart.

**Diagnosis**:
```bash
# Check if reboot is actually required
kubectl exec -it <pod-on-node> -- ls -la /var/run/reboot-required
```

**Solutions**:
- Manually reboot the node: `sudo systemctl reboot`
- Check systemd status: `systemctl status`

### Debug Commands

```bash
# Enable debug logging
kubectl patch plan os-upgrade-plan -n system-upgrade --type='merge' -p='{"spec":{"prepare":{"env":[{"name":"UPGRADE_LOG_LEVEL","value":"debug"}]},"upgrade":{"env":[{"name":"UPGRADE_LOG_LEVEL","value":"debug"}]}}}'

# Check chroot environment
kubectl exec -it <upgrade-job-pod> -n system-upgrade -- chroot /host /bin/bash

# Validate package manager
kubectl exec -it <upgrade-job-pod> -n system-upgrade -- chroot /host apt-get check

# Check available updates
kubectl exec -it <upgrade-job-pod> -n system-upgrade -- chroot /host apt list --upgradable
```

### Recovery Procedures

#### Manual Rollback

If an upgrade causes issues:

1. **Identify the problematic node**:
   ```bash
   kubectl get nodes -o yaml | grep -A10 -B10 upgrade.cattle.io/os-upgrade-failed
   ```

2. **SSH to the node and investigate**:
   ```bash
   ssh user@<node-ip>
   sudo journalctl -u systemd --since "1 hour ago"
   sudo apt-get check
   ```

3. **If necessary, rollback packages**:
   ```bash
   sudo apt-get install --reinstall <package>=<previous-version>
   ```

#### Emergency Stop

To immediately stop all upgrades:

```bash
# Remove labels from all nodes
kubectl label nodes upgrade.cattle.io/os-upgrade-enabled-

# Delete running jobs
kubectl delete jobs -n system-upgrade -l upgrade.cattle.io/plan=os-upgrade-plan
```

## Security Considerations

### Privileged Containers

The upgrade plan requires privileged containers to:
- Mount host filesystems
- Use chroot to access host environment
- Modify system packages
- Trigger system reboots

### Host Access

The plan mounts several host paths:
- `/` - Full host filesystem access (read-write)
- `/proc` - Process information
- `/sys` - System information
- `/var/log/system-upgrade` - Log storage

### Network Security

Ensure nodes can access:
- Package repositories (apt.ubuntu.com, security.ubuntu.com)
- Kubernetes API server
- Container registries for upgrade images

### RBAC Requirements

The plan requires cluster-level permissions to:
- Label and annotate nodes
- Create and manage upgrade jobs
- Access node information

## Best Practices

### 1. Testing Strategy

- **Test in non-production first**: Always test upgrades in development environments
- **Single node testing**: Start with one node to validate the process
- **Gradual rollout**: Label nodes in small batches for controlled upgrades

### 2. Maintenance Windows

- **Schedule during low-traffic periods**: Plan upgrades during maintenance windows
- **Monitor actively**: Watch upgrade progress and system metrics
- **Have rollback plan**: Prepare recovery procedures before starting

### 3. Backup Strategy

- **Snapshot VMs**: Take VM snapshots before major upgrades
- **Backup etcd**: Ensure etcd backups are current for K3s clusters
- **Document current state**: Record current package versions and system state

### 4. Node Preparation

```bash
# Ensure unattended-upgrades is configured
sudo apt-get update && sudo apt-get install -y unattended-upgrades

# Verify disk space
df -h /

# Check for existing upgrade processes
ps aux | grep -E "(apt|dpkg|unattended-upgrade)"
```

## Integration with CI/CD

### GitOps Integration

```yaml
# Example ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: os-upgrades
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/k3s-configs
    targetRevision: HEAD
    path: system-upgrade/
  destination:
    server: https://kubernetes.default.svc
    namespace: system-upgrade
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
```

### Automated Testing

```bash
#!/bin/bash
# Example test script for CI/CD
set -e

# Deploy the plan
kubectl apply -f manifests/system-upgrade/os-upgrade-plan.yaml

# Test on a single node
kubectl label node test-node upgrade.cattle.io/os-upgrade-enabled=true

# Wait for completion
kubectl wait --for=condition=complete job -l upgrade.cattle.io/plan=os-upgrade-plan --timeout=1800s

# Verify node is healthy
kubectl wait --for=condition=ready node test-node --timeout=300s

echo "OS upgrade test completed successfully"
```

## Contributing

To contribute improvements to the OS upgrade plan:

1. Test changes thoroughly in development environments
2. Update documentation for any configuration changes
3. Ensure backward compatibility with existing deployments
4. Add appropriate logging for new features

## License

This OS upgrade plan is part of the system-upgrade Helm chart and follows the same licensing terms.