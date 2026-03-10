#!/usr/bin/env bash
# create-node-group.sh — Add a managed node group to an existing EKS cluster.
#
# Usage:
#   ./create-node-group.sh --cluster NAME --name GROUP [options]
#
# Options:
#   --cluster CLUSTER       EKS cluster name (required)
#   --name GROUP            Node group name (required)
#   --region REGION         AWS region (default: from cluster)
#   --type TYPE(S)          EC2 instance type(s), comma-separated (default: m6i.xlarge)
#   --nodes N               Desired node count (default: 2)
#   --nodes-min N           Minimum nodes (default: 1)
#   --nodes-max N           Maximum nodes (default: 6)
#   --volume-size GB        EBS volume in GB (default: 80)
#   --spot                  Use Spot instances
#   --taint TAINT           Taint in key=value:effect format, repeatable
#   --label KEY=VALUE       Label, repeatable
#   --ami-family FAMILY     AmazonLinux2023 or Bottlerocket (default: AmazonLinux2023)
#   --ssh-key KEY           EC2 key pair for SSH
#   --gpu                   Shortcut: g5.xlarge + GPU taint + nvidia label
#   --dry-run               Print commands without executing
#   -h, --help              Show this help
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────
CLUSTER=""
GROUP_NAME=""
REGION=""
INSTANCE_TYPES="m6i.xlarge"
NODES=2
NODES_MIN=1
NODES_MAX=6
VOLUME_SIZE=80
SPOT="false"
TAINTS=()
LABELS=()
AMI_FAMILY="AmazonLinux2023"
SSH_KEY=""
GPU="false"
DRY_RUN="false"

# ── Parse args ────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster)      CLUSTER="$2"; shift 2 ;;
    --name)         GROUP_NAME="$2"; shift 2 ;;
    --region)       REGION="$2"; shift 2 ;;
    --type)         INSTANCE_TYPES="$2"; shift 2 ;;
    --nodes)        NODES="$2"; shift 2 ;;
    --nodes-min)    NODES_MIN="$2"; shift 2 ;;
    --nodes-max)    NODES_MAX="$2"; shift 2 ;;
    --volume-size)  VOLUME_SIZE="$2"; shift 2 ;;
    --spot)         SPOT="true"; shift ;;
    --taint)        TAINTS+=("$2"); shift 2 ;;
    --label)        LABELS+=("$2"); shift 2 ;;
    --ami-family)   AMI_FAMILY="$2"; shift 2 ;;
    --ssh-key)      SSH_KEY="$2"; shift 2 ;;
    --gpu)          GPU="true"; shift ;;
    --dry-run)      DRY_RUN="true"; shift ;;
    -h|--help)
      sed -n '2,/^set /{ /^#/s/^# \?//p }' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$CLUSTER" ]]    && { echo "Error: --cluster is required" >&2; exit 1; }
[[ -z "$GROUP_NAME" ]] && { echo "Error: --name is required" >&2; exit 1; }

# Auto-detect region from cluster if not specified
if [[ -z "$REGION" ]]; then
  REGION=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.arn' --output text | cut -d: -f4)
  echo "  Auto-detected region: $REGION"
fi

# GPU shortcut
if [[ "$GPU" == "true" ]]; then
  INSTANCE_TYPES="g5.xlarge"
  TAINTS+=("nvidia.com/gpu=true:NoSchedule")
  LABELS+=("workload-type=gpu" "nvidia.com/gpu.present=true")
  AMI_FAMILY="AmazonLinux2023"
fi

run() {
  echo "+ $*"
  if [[ "$DRY_RUN" == "false" ]]; then
    "$@"
  fi
}

echo "═══════════════════════════════════════════════════════════"
echo "  Add Node Group"
echo "  Cluster:    $CLUSTER"
echo "  Group:      $GROUP_NAME"
echo "  Types:      $INSTANCE_TYPES"
echo "  Nodes:      ${NODES} (${NODES_MIN}-${NODES_MAX})"
echo "  Spot:       $SPOT"
echo "  AMI Family: $AMI_FAMILY"
[[ ${#TAINTS[@]} -gt 0 ]] && echo "  Taints:     ${TAINTS[*]}"
[[ ${#LABELS[@]} -gt 0 ]] && echo "  Labels:     ${LABELS[*]}"
echo "═══════════════════════════════════════════════════════════"

# ── Generate eksctl nodegroup config ──────────────────────────────────────
CONFIG_FILE="nodegroup-${CLUSTER}-${GROUP_NAME}.yaml"

# Build instance types YAML
IFS=',' read -ra TYPES <<< "$INSTANCE_TYPES"
if [[ ${#TYPES[@]} -gt 1 || "$SPOT" == "true" ]]; then
  INSTANCE_YAML="    instanceTypes:"
  for t in "${TYPES[@]}"; do
    INSTANCE_YAML+=$'\n'"      - ${t}"
  done
else
  INSTANCE_YAML="    instanceType: ${TYPES[0]}"
fi

# Build labels YAML
LABELS_YAML="    labels:"$'\n'"      role: ${GROUP_NAME}"
for l in "${LABELS[@]}"; do
  KEY="${l%%=*}"
  VAL="${l#*=}"
  LABELS_YAML+=$'\n'"      ${KEY}: \"${VAL}\""
done

# Build taints YAML
TAINTS_YAML=""
if [[ ${#TAINTS[@]} -gt 0 ]]; then
  TAINTS_YAML="    taints:"
  for t in "${TAINTS[@]}"; do
    # Parse key=value:effect
    KEY="${t%%=*}"
    REST="${t#*=}"
    VALUE="${REST%%:*}"
    EFFECT="${REST#*:}"
    TAINTS_YAML+=$'\n'"      - key: ${KEY}"
    TAINTS_YAML+=$'\n'"        value: \"${VALUE}\""
    TAINTS_YAML+=$'\n'"        effect: ${EFFECT}"
  done
fi

# Build SSH YAML
SSH_YAML=""
if [[ -n "$SSH_KEY" ]]; then
  SSH_YAML=$(cat <<EOFSSH
    ssh:
      allow: true
      publicKeyName: "${SSH_KEY}"
EOFSSH
  )
fi

# Build spot YAML
SPOT_YAML=""
if [[ "$SPOT" == "true" ]]; then
  SPOT_YAML="    spot: true"
fi

cat > "$CONFIG_FILE" <<EOFNG
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER}
  region: ${REGION}

managedNodeGroups:
  - name: ${CLUSTER}-${GROUP_NAME}
${INSTANCE_YAML}
    desiredCapacity: ${NODES}
    minSize: ${NODES_MIN}
    maxSize: ${NODES_MAX}
    volumeSize: ${VOLUME_SIZE}
    volumeType: gp3
    amiFamily: ${AMI_FAMILY}
    privateNetworking: true
${LABELS_YAML}
${TAINTS_YAML}
${SPOT_YAML}
    iam:
      withAddonPolicies:
        autoScaler: true
        ebs: true
        cloudWatch: true
    tags:
      node-group: ${GROUP_NAME}
${SSH_YAML}
EOFNG

echo ""
echo "▸ Config written to $CONFIG_FILE"

# ── Create the node group ────────────────────────────────────────────────
echo ""
echo "▸ Creating node group (this takes 5-10 minutes)..."
run eksctl create nodegroup -f "$CONFIG_FILE"

echo ""
echo "▸ Waiting for nodes to be Ready..."
TIMEOUT=300
ELAPSED=0
while true; do
  READY=$(kubectl get nodes -l "eks.amazonaws.com/nodegroup=${CLUSTER}-${GROUP_NAME}" \
    --no-headers 2>/dev/null | grep -c " Ready" || true)
  if [[ "$READY" -ge "$NODES_MIN" ]]; then
    break
  fi
  if [[ "$ELAPSED" -ge "$TIMEOUT" ]]; then
    echo "  ⚠ Timeout waiting for nodes — check AWS Console"
    break
  fi
  sleep 10
  ELAPSED=$((ELAPSED + 10))
  echo "  Waiting... (${READY} ready, ${ELAPSED}s elapsed)"
done

# ── GPU: Install NVIDIA device plugin if needed ──────────────────────────
if [[ "$GPU" == "true" ]]; then
  echo ""
  echo "▸ Installing NVIDIA device plugin for GPU nodes..."
  run kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.16.2/deployments/static/nvidia-device-plugin.yml
  echo "  ✓ NVIDIA device plugin installed."
fi

# ── Done ─────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✓ Node group '${GROUP_NAME}' added to cluster '${CLUSTER}'!"
echo ""
READY_COUNT=$(kubectl get nodes -l "eks.amazonaws.com/nodegroup=${CLUSTER}-${GROUP_NAME}" \
  --no-headers 2>/dev/null | grep -c " Ready" || echo "?")
echo "  Nodes ready: ${READY_COUNT}"
echo "  Config:      $CONFIG_FILE"
echo ""
if [[ ${#TAINTS[@]} -gt 0 ]]; then
  echo "  Taints applied — pods need matching tolerations."
fi
if [[ ${#LABELS[@]} -gt 0 ]]; then
  echo "  Labels applied — use nodeSelector or affinity to target."
fi
echo "═══════════════════════════════════════════════════════════"
