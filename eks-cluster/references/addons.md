# EKS Addons Reference

## Essential Addons

These are installed automatically by `create-eks-cluster.sh`.

### VPC CNI (amazon-vpc-cni-k8s)

Assigns VPC IP addresses directly to pods. Required for all EKS clusters.

```bash
eksctl create addon --cluster CLUSTER --name vpc-cni --version latest
```

Enable Network Policy support:

```bash
eksctl create addon --cluster CLUSTER --name vpc-cni \
  --configuration-values '{"enableNetworkPolicy": "true"}'
```

### CoreDNS

Cluster DNS for service discovery. Required.

```bash
eksctl create addon --cluster CLUSTER --name coredns --version latest
```

### kube-proxy

Network rules for service routing. Required.

```bash
eksctl create addon --cluster CLUSTER --name kube-proxy --version latest
```

### EKS Pod Identity Agent

Injects temporary AWS credentials into pods. Required for the aws-s3-eks skill and any AWS service access without static credentials.

```bash
eksctl create addon --cluster CLUSTER --name eks-pod-identity-agent --version latest
```

No IAM role needed — the agent itself runs with node-level permissions.

### EBS CSI Driver

Required for PersistentVolumeClaims backed by EBS (gp3, io2, etc.).

```bash
# Create IAM role for EBS CSI
eksctl create iamserviceaccount \
  --cluster CLUSTER \
  --namespace kube-system \
  --name ebs-csi-controller-sa \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --role-name ${CLUSTER}-ebs-csi-role \
  --approve

# Install addon
eksctl create addon --cluster CLUSTER --name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::ACCOUNT:role/${CLUSTER}-ebs-csi-role
```

Or in eksctl config:

```yaml
addons:
  - name: aws-ebs-csi-driver
    version: latest
    wellKnownPolicies:
      ebsCSIController: true
```

## Optional Addons

### EFS CSI Driver

For ReadWriteMany PVCs (shared across pods/nodes). Useful for the dp-agents uploads volume.

```bash
# Create IAM role
eksctl create iamserviceaccount \
  --cluster CLUSTER \
  --namespace kube-system \
  --name efs-csi-controller-sa \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy \
  --role-name ${CLUSTER}-efs-csi-role \
  --approve

# Install addon
eksctl create addon --cluster CLUSTER --name aws-efs-csi-driver \
  --service-account-role-arn arn:aws:iam::ACCOUNT:role/${CLUSTER}-efs-csi-role
```

Create an EFS filesystem:

```bash
# Get VPC and subnets
VPC_ID=$(aws eks describe-cluster --name CLUSTER --query 'cluster.resourcesVpcConfig.vpcId' --output text)
SUBNET_IDS=$(aws eks describe-cluster --name CLUSTER --query 'cluster.resourcesVpcConfig.subnetIds' --output text)

# Create EFS
EFS_ID=$(aws efs create-file-system --performance-mode generalPurpose --throughput-mode elastic --encrypted --query 'FileSystemId' --output text)

# Create mount targets in each subnet
for SUBNET in $SUBNET_IDS; do
  aws efs create-mount-target --file-system-id $EFS_ID --subnet-id $SUBNET --security-groups SG_ID
done
```

StorageClass for EFS:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-0abc123
  directoryPerms: "700"
```

### AWS Load Balancer Controller

Alternative to NGINX Ingress. Creates AWS ALB/NLB for Ingress/Service resources.

```bash
# Install via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=CLUSTER \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

Requires IAM policy: [AWSLoadBalancerControllerIAMPolicy](https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json)

### CloudWatch Observability

Container Insights for monitoring and log collection.

```bash
eksctl create addon --cluster CLUSTER --name amazon-cloudwatch-observability --version latest
```

### Metrics Server

Required for HorizontalPodAutoscaler.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### NGINX Ingress Controller

Installed by `create-eks-cluster.sh`. Manual install:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0/deploy/static/provider/aws/deploy.yaml
```

This creates a Network Load Balancer (NLB) in AWS. To use an Application Load Balancer instead, use the AWS Load Balancer Controller.

### cert-manager

For automatic TLS certificate management (Let's Encrypt).

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.3/cert-manager.yaml
```

Create a ClusterIssuer for Let's Encrypt:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
```

## Addon Version Management

List installed addons:

```bash
eksctl get addons --cluster CLUSTER
```

Update an addon:

```bash
eksctl update addon --cluster CLUSTER --name vpc-cni --version latest
```

List available addon versions:

```bash
aws eks describe-addon-versions --addon-name vpc-cni --kubernetes-version 1.31 \
  --query 'addons[0].addonVersions[*].addonVersion' --output table
```

## Addon Compatibility Matrix

| Addon | Min K8s | IAM Role Needed | Notes |
|-------|---------|-----------------|-------|
| vpc-cni | 1.24 | No (uses node role) | Core networking |
| coredns | 1.24 | No | DNS resolution |
| kube-proxy | 1.24 | No | Service networking |
| eks-pod-identity-agent | 1.24 | No | Credential injection |
| aws-ebs-csi-driver | 1.24 | Yes | PVC storage |
| aws-efs-csi-driver | 1.24 | Yes | Shared storage |
| amazon-cloudwatch-observability | 1.24 | Yes | Monitoring |
| aws-load-balancer-controller | 1.24 | Yes | ALB/NLB |
