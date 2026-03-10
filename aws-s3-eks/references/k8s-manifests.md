# Kubernetes Manifests for S3 + EKS Pod Identity

## ServiceAccount

The ServiceAccount is the K8s resource that gets linked to the IAM role via Pod Identity Association.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-api
  namespace: my-app
  labels:
    app.kubernetes.io/name: my-app
    app.kubernetes.io/component: api
```

No annotations needed — Pod Identity does not use annotations (unlike IRSA).

## Deployment Patch for S3 Environment Variables

Add S3 configuration to your Deployment:

```yaml
# Patch: my-app-api Deployment
spec:
  template:
    spec:
      serviceAccountName: my-app-api  # Must match pod identity association
      containers:
        - name: api
          env:
            - name: S3_BUCKET
              valueFrom:
                configMapKeyRef:
                  name: my-app-config
                  key: S3_BUCKET
            - name: S3_REGION
              valueFrom:
                configMapKeyRef:
                  name: my-app-config
                  key: S3_REGION
            # No access key / secret key — Pod Identity injects credentials automatically
```

## ConfigMap for S3 Settings

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-app-s3-config
  namespace: my-app
data:
  S3_BUCKET: "my-app-uploads"
  S3_REGION: "us-east-1"
  # S3_PUBLIC_URL only needed if you serve files via CloudFront or custom domain
  # S3_PUBLIC_URL: "https://files.example.com"
```

## Full Deployment Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-api
  namespace: my-app
  labels:
    app.kubernetes.io/name: my-app
    app.kubernetes.io/component: api
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: my-app
      app.kubernetes.io/component: api
  template:
    metadata:
      labels:
        app.kubernetes.io/name: my-app
        app.kubernetes.io/component: api
    spec:
      serviceAccountName: my-app-api
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
        - name: api
          image: my-app-api:latest
          ports:
            - name: http
              containerPort: 8080
          envFrom:
            - configMapRef:
                name: my-app-config
            - configMapRef:
                name: my-app-s3-config
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
      volumes:
        - name: tmp
          emptyDir: {}
```

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
      name: my-app-api
    patch: |
      - op: add
        path: /spec/template/spec/containers/0/envFrom/-
        value:
          configMapKeyRef:
            name: my-app-s3-config
configMapGenerator:
  - name: my-app-s3-config
    literals:
      - S3_BUCKET=my-app-uploads
      - S3_REGION=us-east-1
```

## Verification Commands

```bash
# Check ServiceAccount exists
kubectl get sa my-app-api -n my-app

# Verify Pod Identity Agent DaemonSet is running
kubectl get ds -n kube-system | grep pod-identity

# Check pod has the injected env vars
kubectl exec -it deploy/my-app-api -n my-app -- env | grep AWS_CONTAINER

# Test S3 access from within the pod
kubectl exec -it deploy/my-app-api -n my-app -- \
  python3 -c "import boto3; s3=boto3.client('s3'); print(s3.list_buckets()['Buckets'])"
```
