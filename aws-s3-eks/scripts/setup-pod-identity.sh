#!/usr/bin/env bash
# setup-pod-identity.sh — Configure EKS Pod Identity for S3 access.
#
# Creates an IAM role with S3 policy, a K8s ServiceAccount,
# and a Pod Identity Association linking them together.
#
# Usage:
#   ./setup-pod-identity.sh \
#     --cluster CLUSTER --namespace NS --service-account SA \
#     --bucket BUCKET --region REGION [options]
#
# Options:
#   --cluster CLUSTER       EKS cluster name (required)
#   --namespace NS          K8s namespace (required)
#   --service-account SA    K8s ServiceAccount name (required)
#   --bucket BUCKET         S3 bucket name (required)
#   --region REGION         AWS region (required)
#   --role-name ROLE        Custom IAM role name
#   --read-only             Grant only read access to S3
#   --prefix PREFIX         Restrict access to a key prefix
#   --dry-run               Print commands without executing
#   -h, --help              Show this help
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────
CLUSTER=""
NAMESPACE=""
SERVICE_ACCOUNT=""
BUCKET=""
REGION=""
ROLE_NAME=""
READ_ONLY="false"
PREFIX=""
DRY_RUN="false"

# ── Parse args ────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster)        CLUSTER="$2"; shift 2 ;;
    --namespace)      NAMESPACE="$2"; shift 2 ;;
    --service-account) SERVICE_ACCOUNT="$2"; shift 2 ;;
    --bucket)         BUCKET="$2"; shift 2 ;;
    --region)         REGION="$2"; shift 2 ;;
    --role-name)      ROLE_NAME="$2"; shift 2 ;;
    --read-only)      READ_ONLY="true"; shift ;;
    --prefix)         PREFIX="$2"; shift 2 ;;
    --dry-run)        DRY_RUN="true"; shift ;;
    -h|--help)
      sed -n '2,/^set /{ /^#/s/^# \?//p }' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$CLUSTER" ]]        && { echo "Error: --cluster is required" >&2; exit 1; }
[[ -z "$NAMESPACE" ]]      && { echo "Error: --namespace is required" >&2; exit 1; }
[[ -z "$SERVICE_ACCOUNT" ]] && { echo "Error: --service-account is required" >&2; exit 1; }
[[ -z "$BUCKET" ]]         && { echo "Error: --bucket is required" >&2; exit 1; }
[[ -z "$REGION" ]]         && { echo "Error: --region is required" >&2; exit 1; }

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
[[ -z "$ROLE_NAME" ]] && ROLE_NAME="${CLUSTER}-${NAMESPACE}-${SERVICE_ACCOUNT}-s3-role"

run() {
  echo "+ $*"
  if [[ "$DRY_RUN" == "false" ]]; then
    "$@"
  fi
}

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  EKS Pod Identity Setup"
echo "  Cluster:        $CLUSTER"
echo "  Namespace:      $NAMESPACE"
echo "  ServiceAccount: $SERVICE_ACCOUNT"
echo "  Bucket:         $BUCKET"
echo "  IAM Role:       $ROLE_NAME"
echo "  Account:        $ACCOUNT_ID"
echo "  Region:         $REGION"
echo "═══════════════════════════════════════════════════════════"

# ── 1. Ensure Pod Identity Agent addon is installed ──────────────────────
echo ""
echo "▸ Checking Pod Identity Agent addon..."
ADDON_STATUS=$(aws eks describe-addon \
  --cluster-name "$CLUSTER" \
  --addon-name eks-pod-identity-agent \
  --query 'addon.status' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [[ "$ADDON_STATUS" == "NOT_FOUND" ]]; then
  echo "  Pod Identity Agent not found — installing..."
  run aws eks create-addon \
    --cluster-name "$CLUSTER" \
    --addon-name eks-pod-identity-agent
  echo "  Waiting for addon to become active..."
  run aws eks wait addon-active \
    --cluster-name "$CLUSTER" \
    --addon-name eks-pod-identity-agent
  echo "  ✓ Pod Identity Agent addon installed."
elif [[ "$ADDON_STATUS" == "ACTIVE" ]]; then
  echo "  ✓ Pod Identity Agent addon is already active."
else
  echo "  ⚠ Pod Identity Agent status: $ADDON_STATUS (may need attention)"
fi

# ── 2. Create IAM trust policy ──────────────────────────────────────────
echo ""
echo "▸ Creating IAM role trust policy..."
TRUST_POLICY=$(cat <<EOFTRUST
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "pods.eks.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ],
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "${ACCOUNT_ID}"
        },
        "ArnEquals": {
          "aws:SourceArn": "arn:aws:eks:${REGION}:${ACCOUNT_ID}:cluster/${CLUSTER}"
        }
      }
    }
  ]
}
EOFTRUST
)

# Check if role exists
if aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
  echo "  IAM role '$ROLE_NAME' already exists — updating trust policy."
  run aws iam update-assume-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-document "$TRUST_POLICY"
else
  run aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "$TRUST_POLICY" \
    --description "EKS Pod Identity role for ${NAMESPACE}/${SERVICE_ACCOUNT} - S3 access to ${BUCKET}" \
    --tags Key=eks-cluster,Value="$CLUSTER" Key=kubernetes-namespace,Value="$NAMESPACE" Key=kubernetes-service-account,Value="$SERVICE_ACCOUNT"
  echo "  ✓ IAM role created."
fi

# ── 3. Create and attach S3 access policy ────────────────────────────────
echo ""
echo "▸ Creating S3 access policy..."

S3_POLICY_NAME="${ROLE_NAME}-s3-policy"

if [[ "$READ_ONLY" == "true" ]]; then
  S3_ACTIONS='"s3:GetObject", "s3:ListBucket", "s3:GetBucketLocation"'
else
  S3_ACTIONS='"s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketLocation", "s3:ListMultipartUploadParts", "s3:AbortMultipartUpload"'
fi

if [[ -n "$PREFIX" ]]; then
  RESOURCE_ARN="arn:aws:s3:::${BUCKET}/${PREFIX}*"
  S3_POLICY=$(cat <<EOFPOL
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3ListBucketPrefix",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::${BUCKET}",
      "Condition": {
        "StringLike": { "s3:prefix": "${PREFIX}*" }
      }
    },
    {
      "Sid": "S3ObjectAccess",
      "Effect": "Allow",
      "Action": [${S3_ACTIONS}],
      "Resource": "${RESOURCE_ARN}"
    }
  ]
}
EOFPOL
  )
else
  S3_POLICY=$(cat <<EOFPOL
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3BucketAccess",
      "Effect": "Allow",
      "Action": [${S3_ACTIONS}],
      "Resource": [
        "arn:aws:s3:::${BUCKET}",
        "arn:aws:s3:::${BUCKET}/*"
      ]
    }
  ]
}
EOFPOL
  )
fi

# Put inline policy (idempotent — overwrites if exists)
run aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "$S3_POLICY_NAME" \
  --policy-document "$S3_POLICY"
echo "  ✓ S3 policy attached."

# ── 4. Create Kubernetes namespace and ServiceAccount ────────────────────
echo ""
echo "▸ Ensuring K8s namespace and ServiceAccount..."

# Create namespace if it doesn't exist
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  run kubectl create namespace "$NAMESPACE"
  echo "  ✓ Namespace '$NAMESPACE' created."
else
  echo "  Namespace '$NAMESPACE' already exists."
fi

# Create or update ServiceAccount
if ! kubectl get serviceaccount "$SERVICE_ACCOUNT" -n "$NAMESPACE" &>/dev/null; then
  run kubectl create serviceaccount "$SERVICE_ACCOUNT" -n "$NAMESPACE"
  echo "  ✓ ServiceAccount '$SERVICE_ACCOUNT' created."
else
  echo "  ServiceAccount '$SERVICE_ACCOUNT' already exists."
fi

# ── 5. Create Pod Identity Association ───────────────────────────────────
echo ""
echo "▸ Creating Pod Identity Association..."

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# Check if association already exists
EXISTING=$(aws eks list-pod-identity-associations \
  --cluster-name "$CLUSTER" \
  --namespace "$NAMESPACE" \
  --service-account "$SERVICE_ACCOUNT" \
  --query 'associations[0].associationId' \
  --output text 2>/dev/null || echo "None")

if [[ "$EXISTING" != "None" && "$EXISTING" != "" ]]; then
  echo "  Pod Identity Association already exists (ID: $EXISTING)."
  echo "  Updating role ARN..."
  run aws eks update-pod-identity-association \
    --cluster-name "$CLUSTER" \
    --association-id "$EXISTING" \
    --role-arn "$ROLE_ARN"
  echo "  ✓ Association updated."
else
  run aws eks create-pod-identity-association \
    --cluster-name "$CLUSTER" \
    --namespace "$NAMESPACE" \
    --service-account "$SERVICE_ACCOUNT" \
    --role-arn "$ROLE_ARN"
  echo "  ✓ Pod Identity Association created."
fi

# ── Done ─────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✓ EKS Pod Identity setup complete!"
echo ""
echo "  IAM Role:       $ROLE_ARN"
echo "  ServiceAccount: $NAMESPACE/$SERVICE_ACCOUNT"
echo "  S3 Bucket:      $BUCKET"
echo "  Access:         $([ "$READ_ONLY" == "true" ] && echo "Read-only" || echo "Read-write")"
[[ -n "$PREFIX" ]] && echo "  Prefix:         $PREFIX"
echo ""
echo "  Pods using ServiceAccount '$SERVICE_ACCOUNT' in namespace"
echo "  '$NAMESPACE' will automatically receive S3 credentials."
echo ""
echo "  Verify with:"
echo "    kubectl run s3-test --rm -it \\"
echo "      --image=amazon/aws-cli \\"
echo "      --overrides='{\"spec\":{\"serviceAccountName\":\"${SERVICE_ACCOUNT}\"}}' \\"
echo "      -n $NAMESPACE \\"
echo "      -- s3 ls s3://$BUCKET/"
echo "═══════════════════════════════════════════════════════════"
