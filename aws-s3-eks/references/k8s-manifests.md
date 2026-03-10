# Kubernetes Manifests for S3 + EKS Pod Identity

## ServiceAccount

The ServiceAccount is the K8s resource that gets linked to the IAM role via Pod Identity Association.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dp-agents-api
  namespace: dp-agents
  labels:
    app.kubernetes.io/name: dp-agents
    app.kubernetes.io/component: api
```

No annotations needed — Pod Identity does not use annotations (unlike IRSA).

## Deployment Patch for S3 Environment Variables

Add S3 configuration to the existing dp-agents Deployment:

```yaml
# Patch: dp-agents-api Deployment
spec:
  template:
    spec:
      serviceAccountName: dp-agents-api  # Must match pod identity association
      containers:
        - name: api
          env:
            - name: DP_AGENTS_S3_ENABLED
              value: "true"
            - name: DP_AGENTS_S3_BUCKET
              valueFrom:
                configMapKeyRef:
                  name: dp-agents-config
                  key: S3_BUCKET
            - name: DP_AGENTS_S3_REGION
              valueFrom:
                configMapKeyRef:
                  name: dp-agents-config
                  key: S3_REGION
            # No access key / secret key — Pod Identity injects credentials automatically
```

## ConfigMap for S3 Settings

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dp-agents-s3-config
  namespace: dp-agents
data:
  S3_BUCKET: "dp-agents-uploads"
  S3_REGION: "us-east-1"
  S3_ENABLED: "true"
  # S3_PUBLIC_URL only needed if you serve files via CloudFront or custom domain
  # S3_PUBLIC_URL: "https://files.example.com"
```

## Full Deployment Example (dp-agents with S3)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dp-agents-api
  namespace: dp-agents
  labels:
    app.kubernetes.io/name: dp-agents
    app.kubernetes.io/component: api
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: dp-agents
      app.kubernetes.io/component: api
  template:
    metadata:
      labels:
        app.kubernetes.io/name: dp-agents
        app.kubernetes.io/component: api
    spec:
      serviceAccountName: dp-agents-api
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
        - name: api
          image: dp-agents-api:latest
          ports:
            - name: http
              containerPort: 8004
          envFrom:
            - configMapRef:
                name: dp-agents-config
            - configMapRef:
                name: dp-agents-s3-config
            - secretRef:
                name: dp-agents-secrets
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: agents-skills
              mountPath: /app/.agents
      volumes:
        - name: tmp
          emptyDir: {}
        - name: agents-skills
          emptyDir: {}
```

Note: The `uploads` PVC is no longer needed when using S3 — files are stored in the bucket instead.

## Kustomize Overlay (Optional)

If using Kustomize, create an overlay to add S3 config:

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
patches:
  - target:
      kind: Deployment
      name: dp-agents-api
    patch: |
      - op: add
        path: /spec/template/spec/containers/0/envFrom/-
        value:
          configMapKeyRef:
            name: dp-agents-s3-config
configMapGenerator:
  - name: dp-agents-s3-config
    literals:
      - S3_BUCKET=dp-agents-uploads
      - S3_REGION=us-east-1
      - S3_ENABLED=true
```

## Verification Commands

```bash
# Check ServiceAccount exists
kubectl get sa dp-agents-api -n dp-agents

# Verify Pod Identity Agent DaemonSet is running
kubectl get ds -n kube-system | grep pod-identity

# Check pod has the injected env vars
kubectl exec -it deploy/dp-agents-api -n dp-agents -- env | grep AWS_CONTAINER

# Test S3 access from within the pod
kubectl exec -it deploy/dp-agents-api -n dp-agents -- \
  python3 -c "import boto3; s3=boto3.client('s3'); print(s3.list_buckets()['Buckets'])"
```
