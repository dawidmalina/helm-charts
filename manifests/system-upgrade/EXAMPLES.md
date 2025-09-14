# OS Upgrade Plan - Usage Examples

This file contains practical examples for using the OS upgrade plan in various scenarios.

## Quick Start

### 1. Deploy the Plan

```bash
# Apply the OS upgrade plan
kubectl apply -f manifests/system-upgrade/os-upgrade-plan.yaml

# Verify deployment
kubectl get plans -n system-upgrade
kubectl get configmaps -n system-upgrade os-upgrade-scripts
```

### 2. Test on a Single Node

```bash
# Choose a test node (preferably a worker node)
export TEST_NODE="worker-1"

# Enable OS upgrades on the test node
kubectl label node $TEST_NODE upgrade.cattle.io/os-upgrade-enabled=true

# Monitor the upgrade process
kubectl get jobs -n system-upgrade -w
kubectl logs -n system-upgrade -l upgrade.cattle.io/plan=os-upgrade-plan -f

# Check upgrade status
kubectl get node $TEST_NODE -o yaml | grep -A5 -B5 upgrade.cattle.io
```

### 3. Production Rolling Upgrade

```bash
# Enable upgrades on all worker nodes (safe with concurrency: 1)
kubectl label nodes -l '!node-role.kubernetes.io/control-plane' upgrade.cattle.io/os-upgrade-enabled=true

# Monitor progress across all nodes
watch "kubectl get nodes -o custom-columns='NAME:.metadata.name,STATUS:.status.conditions[?(@.type==\"Ready\")].status,UPGRADE-ENABLED:.metadata.labels.upgrade\.cattle\.io/os-upgrade-enabled,IN-PROGRESS:.metadata.labels.upgrade\.cattle\.io/os-upgrade-in-progress,COMPLETED:.metadata.annotations.upgrade\.cattle\.io/os-upgrade-completed'"

# View upgrade logs
kubectl logs -n system-upgrade -l upgrade.cattle.io/plan=os-upgrade-plan --tail=100
```

## Advanced Scenarios

### Maintenance Window Automation

```bash
#!/bin/bash
# maintenance-upgrade.sh - Automated maintenance window upgrade script

set -e

echo "Starting maintenance window OS upgrades..."

# Get list of worker nodes
WORKER_NODES=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}')

for node in $WORKER_NODES; do
    echo "Processing node: $node"
    
    # Enable upgrade for this node
    kubectl label node $node upgrade.cattle.io/os-upgrade-enabled=true
    
    # Wait for upgrade to start
    echo "Waiting for upgrade to start on $node..."
    timeout 300 bash -c "
        while ! kubectl get node $node -o yaml | grep -q 'upgrade.cattle.io/os-upgrade-in-progress'; do
            sleep 10
        done
    "
    
    # Wait for upgrade to complete
    echo "Waiting for upgrade to complete on $node..."
    timeout 1800 bash -c "
        while kubectl get node $node -o yaml | grep -q 'upgrade.cattle.io/os-upgrade-in-progress'; do
            sleep 30
        done
    "
    
    # Check if upgrade was successful
    if kubectl get node $node -o yaml | grep -q 'upgrade.cattle.io/os-upgrade-completed'; then
        echo "✓ Node $node upgraded successfully"
        
        # Check if reboot is required
        if kubectl get node $node -o yaml | grep -q 'upgrade.cattle.io/reboot-required'; then
            echo "⚠ Node $node requires reboot - waiting for it to come back online..."
            
            # Wait for node to become ready again after reboot
            kubectl wait --for=condition=Ready node $node --timeout=600s
            echo "✓ Node $node is ready after reboot"
        fi
    else
        echo "✗ Node $node upgrade failed"
        kubectl get node $node -o yaml | grep upgrade.cattle.io
        exit 1
    fi
    
    echo "---"
done

echo "All worker nodes upgraded successfully!"
```

### Control Plane Upgrade (Advanced)

```bash
#!/bin/bash
# control-plane-upgrade.sh - Upgrade control plane nodes one by one

set -e

# WARNING: This should only be done in maintenance windows with proper backups
echo "WARNING: Upgrading control plane nodes. Ensure you have:"
echo "1. Recent etcd backup"
echo "2. VM snapshots"
echo "3. Maintenance window scheduled"
echo "4. Tested in non-production environment"
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# Get control plane nodes
CONTROL_NODES=$(kubectl get nodes -l 'node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}')

for node in $CONTROL_NODES; do
    echo "Upgrading control plane node: $node"
    
    # Enable upgrade
    kubectl label node $node upgrade.cattle.io/os-upgrade-enabled=true
    
    # Monitor upgrade
    echo "Monitoring upgrade progress..."
    timeout 2400 bash -c "
        while ! kubectl get node $node -o yaml | grep -q 'upgrade.cattle.io/os-upgrade-completed'; do
            if kubectl get node $node -o yaml | grep -q 'upgrade.cattle.io/os-upgrade-failed'; then
                echo 'Upgrade failed!'
                exit 1
            fi
            sleep 30
        done
    "
    
    # Verify cluster health after each control plane node
    echo "Verifying cluster health..."
    kubectl get nodes
    kubectl get pods -n kube-system
    
    # Wait a bit before proceeding to next node
    sleep 60
done

echo "All control plane nodes upgraded successfully!"
```

### Emergency Procedures

#### Stop All Upgrades

```bash
#!/bin/bash
# emergency-stop.sh - Stop all ongoing upgrades immediately

echo "Emergency stop: Disabling all OS upgrades..."

# Remove labels from all nodes
kubectl label nodes upgrade.cattle.io/os-upgrade-enabled- --all

# Delete any running upgrade jobs
kubectl delete jobs -n system-upgrade -l upgrade.cattle.io/plan=os-upgrade-plan

# Remove in-progress labels
kubectl label nodes upgrade.cattle.io/os-upgrade-in-progress- --all

echo "All upgrades stopped."
```

#### Manual Recovery

```bash
#!/bin/bash
# manual-recovery.sh - Recover from failed upgrade

NODE_NAME="$1"
if [ -z "$NODE_NAME" ]; then
    echo "Usage: $0 <node-name>"
    exit 1
fi

echo "Recovering node: $NODE_NAME"

# Remove all upgrade labels and annotations
kubectl label node $NODE_NAME upgrade.cattle.io/os-upgrade-enabled- || true
kubectl label node $NODE_NAME upgrade.cattle.io/os-upgrade-in-progress- || true
kubectl annotate node $NODE_NAME upgrade.cattle.io/os-upgrade-failed- || true

# Mark as recovered
kubectl annotate node $NODE_NAME upgrade.cattle.io/manual-recovery="$(date -Iseconds)"

echo "Node $NODE_NAME marked as recovered. Manual intervention may be required on the node itself."
```

## Monitoring Examples

### Prometheus Alerts

```yaml
# prometheus-alerts.yaml
groups:
- name: os-upgrades
  rules:
  - alert: OSUpgradeStuck
    expr: increase(kube_job_status_failed{job_name=~".*os-upgrade-plan.*"}[1h]) > 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "OS upgrade job failed"
      description: "OS upgrade job {{ $labels.job_name }} has failed"

  - alert: OSUpgradeTakingTooLong
    expr: time() - kube_job_status_start_time{job_name=~".*os-upgrade-plan.*"} > 3600
    for: 0m
    labels:
      severity: warning
    annotations:
      summary: "OS upgrade taking too long"
      description: "OS upgrade job {{ $labels.job_name }} has been running for over 1 hour"
```

### Log Aggregation

```yaml
# fluentd-config.yaml - Example Fluentd configuration for upgrade logs
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-os-upgrade-config
data:
  fluent.conf: |
    <source>
      @type tail
      path /var/log/system-upgrade/upgrade.log
      pos_file /var/log/fluentd-os-upgrade.log.pos
      tag os.upgrade
      format json
      time_key timestamp
      time_format %Y-%m-%d %H:%M:%S
    </source>
    
    <filter os.upgrade>
      @type record_transformer
      <record>
        cluster_name "#{ENV['CLUSTER_NAME']}"
        node_name "#{ENV['NODE_NAME']}"
      </record>
    </filter>
    
    <match os.upgrade>
      @type elasticsearch
      host elasticsearch.logging.svc.cluster.local
      port 9200
      index_name os-upgrades
      type_name _doc
    </match>
```

## Testing and Validation

### Pre-deployment Testing

```bash
#!/bin/bash
# test-deployment.sh - Test deployment in development environment

set -e

echo "Testing OS upgrade plan deployment..."

# Deploy to test namespace
kubectl create namespace system-upgrade-test || true
kubectl apply -f manifests/system-upgrade/os-upgrade-plan.yaml -n system-upgrade-test

# Verify resources
kubectl get plans -n system-upgrade-test
kubectl get configmaps -n system-upgrade-test

# Test script syntax
kubectl create job test-scripts -n system-upgrade-test \
  --image=ubuntu:22.04 \
  --restart=Never \
  --command -- /bin/bash -c '
    apt-get update && apt-get install -y python3-yaml
    python3 -c "import yaml; yaml.safe_load_all(open(\"/dev/stdin\"))" < /dev/null
    echo "All tests passed"
  '

kubectl wait --for=condition=complete job/test-scripts -n system-upgrade-test --timeout=300s
kubectl logs job/test-scripts -n system-upgrade-test

# Cleanup
kubectl delete namespace system-upgrade-test

echo "✓ Deployment test completed successfully"
```

### Node Readiness Check

```bash
#!/bin/bash
# check-node-readiness.sh - Verify node is ready for OS upgrades

NODE_NAME="$1"
if [ -z "$NODE_NAME" ]; then
    echo "Usage: $0 <node-name>"
    exit 1
fi

echo "Checking readiness of node: $NODE_NAME"

# Check node status
if ! kubectl get node $NODE_NAME | grep -q "Ready"; then
    echo "✗ Node is not Ready"
    exit 1
fi

# Check disk space
DISK_USAGE=$(kubectl get node $NODE_NAME -o jsonpath='{.status.capacity.ephemeral-storage}')
echo "✓ Disk capacity: $DISK_USAGE"

# Check if any upgrades are already in progress
if kubectl get node $NODE_NAME -o yaml | grep -q 'upgrade.cattle.io/os-upgrade-in-progress'; then
    echo "✗ Node has upgrade in progress"
    exit 1
fi

# Check for existing upgrade labels
if kubectl get node $NODE_NAME -o yaml | grep -q 'upgrade.cattle.io/os-upgrade-enabled.*true'; then
    echo "⚠ Node already labeled for upgrade"
else
    echo "✓ Node not labeled for upgrade"
fi

echo "✓ Node $NODE_NAME is ready for OS upgrades"
```

## Integration Examples

### GitOps with ArgoCD

```yaml
# argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: os-upgrade-plan
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/k3s-infrastructure
    targetRevision: HEAD
    path: system-upgrade/
  destination:
    server: https://kubernetes.default.svc
    namespace: system-upgrade
  syncPolicy:
    automated:
      prune: true
      selfHeal: false
    syncOptions:
    - CreateNamespace=true
    - RespectIgnoreDifferences=true
```

### Terraform Integration

```hcl
# terraform/os-upgrades.tf
resource "kubectl_manifest" "os_upgrade_plan" {
  yaml_body = file("${path.module}/../../manifests/system-upgrade/os-upgrade-plan.yaml")
  
  depends_on = [
    kubectl_manifest.system_upgrade_controller
  ]
}

resource "null_resource" "enable_os_upgrades" {
  count = var.enable_automatic_os_upgrades ? 1 : 0
  
  provisioner "local-exec" {
    command = "kubectl label nodes -l '!node-role.kubernetes.io/control-plane' upgrade.cattle.io/os-upgrade-enabled=true"
  }
  
  depends_on = [
    kubectl_manifest.os_upgrade_plan
  ]
}
```

## Summary

These examples demonstrate:

1. **Basic Usage**: Simple deployment and testing
2. **Production Scenarios**: Safe rolling upgrades with monitoring
3. **Advanced Automation**: Maintenance window scripts
4. **Emergency Procedures**: Recovery and stop mechanisms
5. **Monitoring Integration**: Prometheus alerts and log aggregation
6. **Testing Frameworks**: Validation and readiness checks
7. **GitOps Integration**: ArgoCD and Terraform examples

Always test these procedures in non-production environments first and ensure you have proper backups before running OS upgrades on production systems.