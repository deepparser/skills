# IAM Policy Templates for S3 + EKS Pod Identity

## Trust Policy (Required)

Every IAM role used with EKS Pod Identity needs this trust policy. Replace `ACCOUNT_ID` and `CLUSTER_NAME`.

```json
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
          "aws:SourceAccount": "ACCOUNT_ID"
        },
        "ArnEquals": {
          "aws:SourceArn": "arn:aws:eks:REGION:ACCOUNT_ID:cluster/CLUSTER_NAME"
        }
      }
    }
  ]
}
```

## S3 Access Policies

### Full Read-Write Access (Single Bucket)

For services that upload and download files.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3BucketAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::BUCKET_NAME",
        "arn:aws:s3:::BUCKET_NAME/*"
      ]
    }
  ]
}
```

### Read-Only Access

For services that only read from S3.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3ReadOnly",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::BUCKET_NAME",
        "arn:aws:s3:::BUCKET_NAME/*"
      ]
    }
  ]
}
```

### Prefix-Scoped Access

Restrict access to a specific key prefix (e.g., `uploads/` or `tenant-123/`).

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3PrefixListBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::BUCKET_NAME",
      "Condition": {
        "StringLike": {
          "s3:prefix": "PREFIX/*"
        }
      }
    },
    {
      "Sid": "S3PrefixObjectAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::BUCKET_NAME/PREFIX/*"
    }
  ]
}
```

### Multipart Upload Access

For large file uploads (e.g., model artifacts, backups).

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3MultipartUpload",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:ListMultipartUploadParts",
        "s3:AbortMultipartUpload",
        "s3:ListBucketMultipartUploads"
      ],
      "Resource": [
        "arn:aws:s3:::BUCKET_NAME",
        "arn:aws:s3:::BUCKET_NAME/*"
      ]
    }
  ]
}
```

### Multiple Buckets

When a single service needs access to multiple buckets.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3MultiBucketAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::BUCKET_ONE",
        "arn:aws:s3:::BUCKET_ONE/*",
        "arn:aws:s3:::BUCKET_TWO",
        "arn:aws:s3:::BUCKET_TWO/*"
      ]
    }
  ]
}
```

## KMS Encryption Policy (Optional)

If the bucket uses a custom KMS key for SSE-KMS encryption, the role also needs KMS permissions.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3WithKMS",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::BUCKET_NAME",
        "arn:aws:s3:::BUCKET_NAME/*"
      ]
    },
    {
      "Sid": "KMSAccess",
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "arn:aws:kms:REGION:ACCOUNT_ID:key/KEY_ID"
    }
  ]
}
```
