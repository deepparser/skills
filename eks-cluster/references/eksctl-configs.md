# eksctl ClusterConfig Templates

## Development / Single-Node

Minimal cluster for development and testing. Single node, small instances.

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: my-cluster-dev
  region: us-east-1
  version: "1.31"
  tags:
    environment: dev
    project: my-project

vpc:
  cidr: 10.0.0.0/16
  nat:
    gateway: Single  # Save cost — single NAT gateway
  clusterEndpoints:
    publicAccess: true
    privateAccess: true

iam:
  withOIDC: false

addons:
  - name: vpc-cni
    version: latest
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
  - name: my-cluster-dev-general
    instanceType: t3.xlarge
    desiredCapacity: 1
    minSize: 1
    maxSize: 3
    volumeSize: 50
    volumeType: gp3
    amiFamily: AmazonLinux2023
    privateNetworking: true
    labels:
      role: general
      environment: dev
    iam:
      withAddonPolicies:
        autoScaler: true
        ebs: true
```

## Staging

Multi-node cluster mirroring production topology but with smaller instances.

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: my-cluster-staging
  region: us-east-1
  version: "1.31"
  tags:
    environment: staging
    project: my-project

vpc:
  cidr: 10.1.0.0/16
  nat:
    gateway: HighlyAvailable
  clusterEndpoints:
    publicAccess: true
    privateAccess: true

iam:
  withOIDC: false

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
  - name: my-cluster-staging-general
    instanceType: m6i.large
    desiredCapacity: 2
    minSize: 2
    maxSize: 4
    volumeSize: 80
    volumeType: gp3
    amiFamily: AmazonLinux2023
    privateNetworking: true
    labels:
      role: general
    iam:
      withAddonPolicies:
        autoScaler: true
        ebs: true
        cloudWatch: true

cloudWatch:
  clusterLogging:
    enableTypes:
      - api
      - audit
      - authenticator
    logRetentionInDays: 7
```

## Production

Full production setup with multiple node groups, HA networking, logging.

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: my-cluster-production
  region: us-east-1
  version: "1.31"
  tags:
    environment: production
    project: my-project
    managed-by: eksctl

vpc:
  cidr: 10.10.0.0/16
  nat:
    gateway: HighlyAvailable  # NAT gateway in each AZ
  clusterEndpoints:
    publicAccess: true
    privateAccess: true

iam:
  withOIDC: false  # Using Pod Identity

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
  # General-purpose workloads
  - name: my-cluster-production-general
    instanceType: m6i.xlarge
    desiredCapacity: 3
    minSize: 2
    maxSize: 8
    volumeSize: 80
    volumeType: gp3
    amiFamily: AmazonLinux2023
    privateNetworking: true
    labels:
      role: general
      workload-type: general
    iam:
      withAddonPolicies:
        autoScaler: true
        ebs: true
        cloudWatch: true
    tags:
      node-group: general

  # Compute-optimized: high-CPU workloads (routing, serialization)
  - name: my-cluster-production-compute
    instanceType: c6i.xlarge
    desiredCapacity: 2
    minSize: 2
    maxSize: 6
    volumeSize: 80
    volumeType: gp3
    amiFamily: AmazonLinux2023
    privateNetworking: true
    labels:
      role: compute
      workload-type: compute
    taints:
      - key: workload-type
        value: "compute"
        effect: PreferNoSchedule
    iam:
      withAddonPolicies:
        autoScaler: true
        ebs: true
        cloudWatch: true
    tags:
      node-group: compute

  # Spot instances: batch jobs, non-critical workloads
  - name: my-cluster-production-spot
    instanceTypes:
      - m6i.xlarge
      - m5.xlarge
      - m5a.xlarge
      - m6a.xlarge
    spot: true
    desiredCapacity: 2
    minSize: 0
    maxSize: 10
    volumeSize: 80
    volumeType: gp3
    amiFamily: AmazonLinux2023
    privateNetworking: true
    labels:
      role: spot
      workload-type: spot
    taints:
      - key: spot
        value: "true"
        effect: PreferNoSchedule
    iam:
      withAddonPolicies:
        autoScaler: true
        ebs: true
    tags:
      node-group: spot

cloudWatch:
  clusterLogging:
    enableTypes:
      - api
      - audit
      - authenticator
      - controllerManager
      - scheduler
    logRetentionInDays: 30
```

## Production with GPU Nodes

Extends production config with a GPU node group for model inference.

```yaml
# Add to the production config's managedNodeGroups:
  - name: my-cluster-production-gpu
    instanceTypes:
      - g5.xlarge
      - g5.2xlarge
    desiredCapacity: 1
    minSize: 0
    maxSize: 4
    volumeSize: 100
    volumeType: gp3
    amiFamily: AmazonLinux2023
    privateNetworking: true
    labels:
      role: gpu
      workload-type: gpu
      nvidia.com/gpu.present: "true"
    taints:
      - key: nvidia.com/gpu
        value: "true"
        effect: NoSchedule
    iam:
      withAddonPolicies:
        autoScaler: true
        ebs: true
    tags:
      node-group: gpu
```

After creating GPU nodes, install the NVIDIA device plugin:

```bash
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.16.2/deployments/static/nvidia-device-plugin.yml
```

## Existing VPC

When you have a pre-existing VPC (e.g., shared with other teams):

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: my-cluster-production
  region: us-east-1
  version: "1.31"

vpc:
  id: vpc-0abc123def456789
  subnets:
    private:
      us-east-1a:
        id: subnet-0aaa111
      us-east-1b:
        id: subnet-0bbb222
      us-east-1c:
        id: subnet-0ccc333
    public:
      us-east-1a:
        id: subnet-0ddd444
      us-east-1b:
        id: subnet-0eee555
      us-east-1c:
        id: subnet-0fff666
  clusterEndpoints:
    publicAccess: true
    privateAccess: true

# ... rest of config same as above
```
