#!/usr/bin/env bash
# create-eks-cluster.sh — Create an EKS cluster with VPC, managed node group, and addons.
#
# Usage:
#   ./create-eks-cluster.sh --name NAME --region REGION [options]
#
# Options:
#   --name NAME             Cluster name (required)
#   --region REGION         AWS region (required)
#   --version VER           Kubernetes version (default: 1.31)
#   --vpc-cidr CIDR         VPC CIDR block (default: 10.0.0.0/16)
#   --node-type TYPE        EC2 instance type (default: m6i.xlarge)
#   --nodes N               Desired node count (default: 3)
#   --nodes-min N           Minimum autoscaling nodes (default: 2)
#   --nodes-max N           Maximum autoscaling nodes (default: 8)
#   --node-volume-size GB   EBS volume size (default: 80)
#   --ssh-key KEY           EC2 key pair for SSH access
#   --existing-vpc VPC_ID   Use existing VPC
#   --private-subnets IDS   Comma-separated private subnet IDs
#   --public-subnets IDS    Comma-separated public subnet IDs
#   --spot                  Use Spot instances for node group
#   --config-only           Generate eksctl config file only (do not create)
#   --dry-run               Print commands without executing
#   -h, --help              Show this help
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────
CLUSTER_NAME=""
REGION=""
K8S_VERSION="1.31"
VPC_CIDR="10.0.0.0/16"
NODE_TYPE="m6i.xlarge"
NODES=3
NODES_MIN=2
NODES_MAX=8
NODE_VOLUME_SIZE=80
SSH_KEY=""
EXISTING_VPC=""
PRIVATE_SUBNETS=""
PUBLIC_SUBNETS=""
SPOT="false"
CONFIG_ONLY="false"
DRY_RUN="false"

# ── Parse args ────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)             CLUSTER_NAME="$2"; shift 2 ;;
    --region)           REGION="$2"; shift 2 ;;
    --version)          K8S_VERSION="$2"; shift 2 ;;
    --vpc-cidr)         VPC_CIDR="$2"; shift 2 ;;
    --node-type)        NODE_TYPE="$2"; shift 2 ;;
    --nodes)            NODES="$2"; shift 2 ;;
    --nodes-min)        NODES_MIN="$2"; shift 2 ;;
    --nodes-max)        NODES_MAX="$2"; shift 2 ;;
    --node-volume-size) NODE_VOLUME_SIZE="$2"; shift 2 ;;
    --ssh-key)          SSH_KEY="$2"; shift 2 ;;
    --existing-vpc)     EXISTING_VPC="$2"; shift 2 ;;
    --private-subnets)  PRIVATE_SUBNETS="$2"; shift 2 ;;
    --public-subnets)   PUBLIC_SUBNETS="$2"; shift 2 ;;
    --spot)             SPOT="true"; shift ;;
    --config-only)      CONFIG_ONLY="true"; shift ;;
    --dry-run)          DRY_RUN="true"; shift ;;
    -h|--help)
      sed -n '2,/^set /{ /^#/s/^# \?//p }' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$CLUSTER_NAME" ]] && { echo "Error: --name is required" >&2; exit 1; }
[[ -z "$REGION" ]]       && { echo "Error: --region is required" >&2; exit 1; }

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CONFIG_FILE="eksctl-${CLUSTER_NAME}.yaml"

run() {
  echo "+ $*"
  if [[ "$DRY_RUN" == "false" ]]; then
    "$@"
  fi
}

echo "═══════════════════════════════════════════════════════════"
echo "  EKS Cluster Setup"
echo "  Cluster:  $CLUSTER_NAME"
echo "  Region:   $REGION"
echo "  Version:  $K8S_VERSION"
echo "  Account:  $ACCOUNT_ID"
echo "  Nodes:    ${NODES} (${NODES_MIN}-${NODES_MAX}) × ${NODE_TYPE}"
echo "═══════════════════════════════════════════════════════════"

# ── 1. Generate eksctl config ─────────────────────────────────────────────
echo ""
echo "▸ Generating eksctl ClusterConfig → $CONFIG_FILE"

# Build VPC section
if [[ -n "$EXISTING_VPC" ]]; then
  VPC_BLOCK=$(cat <<EOFVPC
vpc:
  id: "${EXISTING_VPC}"
  subnets:
    private:
$(echo "$PRIVATE_SUBNETS" | tr ',' '\n' | awk '{print "      sub-" NR ":\n        id: " $1}')
    public:
$(echo "$PUBLIC_SUBNETS" | tr ',' '\n' | awk '{print "      sub-" NR ":\n        id: " $1}')
EOFVPC
  )
else
  VPC_BLOCK=$(cat <<EOFVPC
vpc:
  cidr: "${VPC_CIDR}"
  nat:
    gateway: HighlyAvailable
  clusterEndpoints:
    publicAccess: true
    privateAccess: true
EOFVPC
  )
fi

# Build SSH section
SSH_BLOCK=""
if [[ -n "$SSH_KEY" ]]; then
  SSH_BLOCK=$(cat <<EOFSSH
    ssh:
      allow: true
      publicKeyName: "${SSH_KEY}"
EOFSSH
  )
fi

# Build spot config
INSTANCE_BLOCK=""
if [[ "$SPOT" == "true" ]]; then
  INSTANCE_BLOCK=$(cat <<EOFSPOT
    instanceTypes: ["${NODE_TYPE}"]
    spot: true
EOFSPOT
  )
else
  INSTANCE_BLOCK=$(cat <<EOFONDEMAND
    instanceType: ${NODE_TYPE}
EOFONDEMAND
  )
fi

cat > "$CONFIG_FILE" <<EOFCONFIG
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER_NAME}
  region: ${REGION}
  version: "${K8S_VERSION}"
  tags:
    managed-by: eksctl
    project: my-project

${VPC_BLOCK}

iam:
  withOIDC: false  # Using Pod Identity instead of IRSA

addons:
  - name: vpc-cni
    version: latest
    configurationValues: '{"enableNetworkPolicy": "true"}'
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest
  - name: eks-pod-identity-agent
    version: latest
  - name: aws-ebs-csi-driver
    version: latest
    wellKnownPolicies:
      ebsCSIController: true

managedNodeGroups:
  - name: ${CLUSTER_NAME}-general
    labels:
      role: general
      workload-type: general
${INSTANCE_BLOCK}
    desiredCapacity: ${NODES}
    minSize: ${NODES_MIN}
    maxSize: ${NODES_MAX}
    volumeSize: ${NODE_VOLUME_SIZE}
    volumeType: gp3
    amiFamily: AmazonLinux2023
    privateNetworking: true
    iam:
      withAddonPolicies:
        autoScaler: true
        ebs: true
        cloudWatch: true
    tags:
      node-group: general
${SSH_BLOCK}

cloudWatch:
  clusterLogging:
    enableTypes:
      - api
      - audit
      - authenticator
      - controllerManager
      - scheduler
    logRetentionInDays: 30
EOFCONFIG

echo "  ✓ Config written to $CONFIG_FILE"

if [[ "$CONFIG_ONLY" == "true" ]]; then
  echo ""
  echo "  Config-only mode — edit $CONFIG_FILE then run:"
  echo "    eksctl create cluster -f $CONFIG_FILE"
  exit 0
fi

# ── 2. Create cluster ────────────────────────────────────────────────────
echo ""
echo "▸ Creating EKS cluster (this takes 15-25 minutes)..."
run eksctl create cluster -f "$CONFIG_FILE"
echo "  ✓ Cluster created."

# ── 3. Update kubeconfig ─────────────────────────────────────────────────
echo ""
echo "▸ Updating kubeconfig..."
run aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
echo "  ✓ kubeconfig updated."

# ── 4. Create gp3 StorageClass as default ─────────────────────────────────
echo ""
echo "▸ Creating gp3 StorageClass..."
kubectl apply -f - <<EOFSC
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOFSC
# Remove default annotation from gp2 if it exists
kubectl annotate storageclass gp2 storageclass.kubernetes.io/is-default-class- 2>/dev/null || true
echo "  ✓ gp3 StorageClass set as default."

# ── 5. Install NGINX Ingress Controller ──────────────────────────────────
echo ""
echo "▸ Installing NGINX Ingress Controller..."
run kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0/deploy/static/provider/aws/deploy.yaml
echo "  Waiting for Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s 2>/dev/null || echo "  (timeout — check manually)"
echo "  ✓ NGINX Ingress Controller installed."

# ── 6. Create default namespace ───────────────────────────────────────────
echo ""
echo "▸ Creating default app namespace..."
kubectl create namespace apps --dry-run=client -o yaml | kubectl apply -f -
echo "  ✓ Namespace created."

# ── Done ─────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✓ EKS cluster '$CLUSTER_NAME' is ready!"
echo ""
echo "  Nodes:       $(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
echo "  K8s version: $K8S_VERSION"
echo "  Region:      $REGION"
echo ""
echo "  Next steps:"
echo "    1. Deploy services:  kubectl apply -f k8s/"
echo "    2. Set up S3 access: aws-s3-eks skill"
echo "    3. Add node groups:  scripts/create-node-group.sh"
echo ""
echo "  Config saved: $CONFIG_FILE"
echo "═══════════════════════════════════════════════════════════"
