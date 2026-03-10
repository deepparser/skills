#!/usr/bin/env bash
# create-s3-bucket.sh — Create an S3 bucket with encryption, versioning,
# and optionally set up EKS Pod Identity for a Kubernetes service.
#
# Usage:
#   ./create-s3-bucket.sh --bucket NAME --region REGION [options]
#
# Options:
#   --bucket NAME           S3 bucket name (required)
#   --region REGION         AWS region (required)
#   --cluster CLUSTER       EKS cluster name (triggers full pod identity setup)
#   --namespace NS          K8s namespace (default: default)
#   --service-account SA    K8s ServiceAccount name (default: default)
#   --role-name ROLE        Custom IAM role name
#   --versioning            Enable versioning (default: true)
#   --no-versioning         Disable versioning
#   --lifecycle-days N      Add lifecycle expiration rule
#   --public-read           Apply public-read bucket policy
#   --cors-origins ORIGINS  Comma-separated CORS origins
#   --bucket-only           Only create bucket, skip IAM/pod identity
#   --dry-run               Print commands without executing
#   -h, --help              Show this help
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────
BUCKET=""
REGION=""
CLUSTER=""
NAMESPACE="default"
SERVICE_ACCOUNT="default"
ROLE_NAME=""
VERSIONING="true"
LIFECYCLE_DAYS=""
PUBLIC_READ="false"
CORS_ORIGINS=""
BUCKET_ONLY="false"
DRY_RUN="false"

# ── Parse args ────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bucket)         BUCKET="$2"; shift 2 ;;
    --region)         REGION="$2"; shift 2 ;;
    --cluster)        CLUSTER="$2"; shift 2 ;;
    --namespace)      NAMESPACE="$2"; shift 2 ;;
    --service-account) SERVICE_ACCOUNT="$2"; shift 2 ;;
    --role-name)      ROLE_NAME="$2"; shift 2 ;;
    --versioning)     VERSIONING="true"; shift ;;
    --no-versioning)  VERSIONING="false"; shift ;;
    --lifecycle-days) LIFECYCLE_DAYS="$2"; shift 2 ;;
    --public-read)    PUBLIC_READ="true"; shift ;;
    --cors-origins)   CORS_ORIGINS="$2"; shift 2 ;;
    --bucket-only)    BUCKET_ONLY="true"; shift ;;
    --dry-run)        DRY_RUN="true"; shift ;;
    -h|--help)
      sed -n '2,/^set /{ /^#/s/^# \?//p }' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$BUCKET" ]] && { echo "Error: --bucket is required" >&2; exit 1; }
[[ -z "$REGION" ]] && { echo "Error: --region is required" >&2; exit 1; }

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

run() {
  echo "+ $*"
  if [[ "$DRY_RUN" == "false" ]]; then
    "$@"
  fi
}

echo "═══════════════════════════════════════════════════════════"
echo "  S3 Bucket Setup"
echo "  Bucket:  $BUCKET"
echo "  Region:  $REGION"
echo "  Account: $ACCOUNT_ID"
echo "═══════════════════════════════════════════════════════════"

# ── 1. Create bucket ─────────────────────────────────────────────────────
echo ""
echo "▸ Creating S3 bucket..."
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "  Bucket '$BUCKET' already exists — skipping creation."
else
  if [[ "$REGION" == "us-east-1" ]]; then
    run aws s3api create-bucket \
      --bucket "$BUCKET" \
      --region "$REGION"
  else
    run aws s3api create-bucket \
      --bucket "$BUCKET" \
      --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION"
  fi
  echo "  ✓ Bucket created."
fi

# ── 2. Enable encryption (SSE-S3) ────────────────────────────────────────
echo ""
echo "▸ Enabling default encryption (AES-256)..."
run aws s3api put-bucket-encryption \
  --bucket "$BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'
echo "  ✓ Encryption enabled."

# ── 3. Block public access (default — unless --public-read) ──────────────
if [[ "$PUBLIC_READ" == "false" ]]; then
  echo ""
  echo "▸ Blocking all public access..."
  run aws s3api put-public-access-block \
    --bucket "$BUCKET" \
    --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  echo "  ✓ Public access blocked."
else
  echo ""
  echo "▸ Allowing public read access..."
  run aws s3api put-public-access-block \
    --bucket "$BUCKET" \
    --public-access-block-configuration \
      BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false

  POLICY=$(cat <<EOFPOLICY
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "PublicReadGetObject",
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::${BUCKET}/*"
  }]
}
EOFPOLICY
  )
  run aws s3api put-bucket-policy --bucket "$BUCKET" --policy "$POLICY"
  echo "  ✓ Public read policy applied."
fi

# ── 4. Versioning ────────────────────────────────────────────────────────
if [[ "$VERSIONING" == "true" ]]; then
  echo ""
  echo "▸ Enabling versioning..."
  run aws s3api put-bucket-versioning \
    --bucket "$BUCKET" \
    --versioning-configuration Status=Enabled
  echo "  ✓ Versioning enabled."
fi

# ── 5. Lifecycle rule ────────────────────────────────────────────────────
if [[ -n "$LIFECYCLE_DAYS" ]]; then
  echo ""
  echo "▸ Adding lifecycle rule (expire after ${LIFECYCLE_DAYS} days)..."
  LIFECYCLE=$(cat <<EOFLC
{
  "Rules": [{
    "ID": "auto-expire-${LIFECYCLE_DAYS}d",
    "Status": "Enabled",
    "Filter": {},
    "Expiration": { "Days": ${LIFECYCLE_DAYS} }
  }]
}
EOFLC
  )
  run aws s3api put-bucket-lifecycle-configuration \
    --bucket "$BUCKET" \
    --lifecycle-configuration "$LIFECYCLE"
  echo "  ✓ Lifecycle rule added."
fi

# ── 6. CORS ──────────────────────────────────────────────────────────────
if [[ -n "$CORS_ORIGINS" ]]; then
  echo ""
  echo "▸ Configuring CORS..."
  # Build JSON array from comma-separated origins
  ORIGINS_JSON=$(echo "$CORS_ORIGINS" | tr ',' '\n' | sed 's/^/"/;s/$/"/' | paste -sd, -)
  CORS=$(cat <<EOFCORS
{
  "CORSRules": [{
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
    "AllowedOrigins": [${ORIGINS_JSON}],
    "ExposeHeaders": ["ETag", "x-amz-request-id"],
    "MaxAgeSeconds": 3600
  }]
}
EOFCORS
  )
  run aws s3api put-bucket-cors --bucket "$BUCKET" --cors-configuration "$CORS"
  echo "  ✓ CORS configured."
fi

# ── 7. Pod Identity (if --cluster provided and not --bucket-only) ────────
if [[ -n "$CLUSTER" && "$BUCKET_ONLY" == "false" ]]; then
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "  Setting up EKS Pod Identity"
  echo "  Cluster:         $CLUSTER"
  echo "  Namespace:       $NAMESPACE"
  echo "  ServiceAccount:  $SERVICE_ACCOUNT"
  echo "═══════════════════════════════════════════════════════════"

  # Delegate to the pod identity script
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  exec "$SCRIPT_DIR/setup-pod-identity.sh" \
    --cluster "$CLUSTER" \
    --namespace "$NAMESPACE" \
    --service-account "$SERVICE_ACCOUNT" \
    --bucket "$BUCKET" \
    --region "$REGION" \
    ${ROLE_NAME:+--role-name "$ROLE_NAME"} \
    $([[ "$DRY_RUN" == "true" ]] && echo --dry-run || true)
else
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "  Done! Bucket '$BUCKET' is ready."
  echo ""
  echo "  To set up EKS Pod Identity later, run:"
  echo "    scripts/setup-pod-identity.sh \\"
  echo "      --cluster <CLUSTER> --namespace $NAMESPACE \\"
  echo "      --service-account $SERVICE_ACCOUNT \\"
  echo "      --bucket $BUCKET --region $REGION"
  echo "═══════════════════════════════════════════════════════════"
fi
