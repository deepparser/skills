# EC2 Instance Types for EKS

## Quick Reference by Workload

| Workload | Recommended | vCPU | Memory | Est. Monthly |
| --- | --- | --- | --- | --- |
| Low traffic services | t3.medium | 2 | 4 GiB | ~$30 |
| Auth / proxy (production) | m6i.large | 2 | 8 GiB | ~$70 |
| API services (agents, workers) | m6i.xlarge | 4 | 16 GiB | ~$140 |
| High-CPU routing / proxy | c6i.xlarge | 4 | 8 GiB | ~$125 |
| Shared infra (DB, cache) | r6i.xlarge | 4 | 32 GiB | ~$200 |
| GPU inference | g5.xlarge | 4 | 16 GiB + GPU | ~$750 |
| Batch / non-critical workers | Spot m6i.xlarge | 4 | 16 GiB | ~$50-80 |

*Prices are approximate on-demand us-east-1 rates.*

## Instance Families

### General Purpose (M-series) — Recommended Default

Balanced compute, memory, and networking. Best for most general workloads.

| Instance | vCPU | Memory | Network | Use Case |
|----------|------|--------|---------|----------|
| m6i.large | 2 | 8 GiB | Up to 12.5 Gbps | Small services, auth, proxies |
| m6i.xlarge | 4 | 16 GiB | Up to 12.5 Gbps | Standard APIs, agents |
| m6i.2xlarge | 8 | 32 GiB | Up to 12.5 Gbps | Heavy: multi-service per node |
| m7i.xlarge | 4 | 16 GiB | Up to 12.5 Gbps | Latest gen, ~5% faster |
| m6a.xlarge | 4 | 16 GiB | Up to 12.5 Gbps | AMD, ~10% cheaper than m6i |

### Compute Optimized (C-series)

High CPU-to-memory ratio. Good for request routing, serialization, and compute-heavy services.

| Instance | vCPU | Memory | Network | Use Case |
|----------|------|--------|---------|----------|
| c6i.xlarge | 4 | 8 GiB | Up to 12.5 Gbps | LLM proxy routing |
| c6i.2xlarge | 8 | 16 GiB | Up to 12.5 Gbps | High-throughput proxy |
| c7i.xlarge | 4 | 8 GiB | Up to 12.5 Gbps | Latest gen |

### Memory Optimized (R-series)

For in-memory databases and caches. Use for self-hosted PostgreSQL/Redis.

| Instance | vCPU | Memory | Network | Use Case |
|----------|------|--------|---------|----------|
| r6i.large | 2 | 16 GiB | Up to 12.5 Gbps | Small DB workload |
| r6i.xlarge | 4 | 32 GiB | Up to 12.5 Gbps | PostgreSQL + Redis |
| r6i.2xlarge | 8 | 64 GiB | Up to 12.5 Gbps | Large datasets |

### Burstable (T-series)

For low-traffic or dev/staging environments. Baseline CPU with burst capability.

| Instance | vCPU | Memory | Baseline CPU | Use Case |
|----------|------|--------|-------------|----------|
| t3.medium | 2 | 4 GiB | 20% | Dev: single service |
| t3.large | 2 | 8 GiB | 30% | Dev: multiple services |
| t3.xlarge | 4 | 16 GiB | 40% | Staging |

**Warning:** T-series instances throttle after CPU credits are exhausted. Not recommended for production workloads with sustained CPU usage.

### GPU (G-series)

For model inference or embedding generation.

| Instance | vCPU | Memory | GPU | GPU Memory | Use Case |
|----------|------|--------|-----|-----------|----------|
| g5.xlarge | 4 | 16 GiB | 1× A10G | 24 GiB | Small model inference |
| g5.2xlarge | 8 | 32 GiB | 1× A10G | 24 GiB | Medium inference |
| g5.4xlarge | 16 | 64 GiB | 1× A10G | 24 GiB | Large model + preprocessing |
| g5.12xlarge | 48 | 192 GiB | 4× A10G | 96 GiB | Multi-model serving |

## Sizing Strategy

### Development (1-2 nodes)

```
1× t3.xlarge — runs all services on a single node
Total: ~$120/month
```

### Staging (2-3 nodes)

```
2× m6i.large — general services
1× t3.large — shared infra (PG, Redis)
Total: ~$230/month
```

### Production (6-10 nodes)

```
3× m6i.xlarge  — general services
2× c6i.xlarge  — compute-intensive services
2× r6i.xlarge  — data (PostgreSQL, Redis)
2× m6i.xlarge  — spot (batch workers)
Total: ~$1,400/month (on-demand) or ~$1,000/month (with spot)
```

### Production with GPU

```
Above production + 1× g5.xlarge (on-demand or spot)
Total: ~$2,150/month (on-demand)
```

## Spot Instance Tips

- Use multiple instance types for better availability: `m6i.xlarge,m5.xlarge,m5a.xlarge,m6a.xlarge`
- Apply taints so critical workloads don't land on spot: `spot=true:PreferNoSchedule`
- Use for: Temporal workers, batch processing, development
- Avoid for: databases, stateful services, user-facing APIs
- Savings: typically 60-70% vs on-demand

## Right-Sizing Checklist

1. Start with the K8s resource requests from your deployments (e.g. 250m CPU / 256Mi per pod)
2. Account for DaemonSet overhead (~300Mi per node for kube-proxy, VPC CNI, Pod Identity Agent)
3. Leave 15-20% headroom for burst and system pods
4. Use HPA metrics to determine if CPU or memory is the bottleneck
5. Review CloudWatch Container Insights after 1 week of production traffic
