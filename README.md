# Skills

A collection of Claude Code, Codex, Antigravity, OpenClaw, IronClaw, Nanobot skills.

## Available Skills

| Skill | Description |
|---|---|
| [aws-s3-eks](aws-s3-eks/) | Create S3 buckets and configure EKS Pod Identity so pods access S3 without static credentials |
| [azure-bot](azure-bot/) | Create and manage Azure Bot resources using the Azure CLI — covers identity creation, bot registration, channel configuration, and deployment |
| [eks-cluster](eks-cluster/) | Provision EKS clusters with managed node groups, autoscaling, and essential addons |
| [exa.ai-websearch-api](exa.ai-websearch-api/) | Real-time web search and content retrieval using the Exa API |
| [oas-api-spec-generator](oas-api-spec-generator/) | Generate OpenAPI 3.2.0 specifications for third-party APIs |

## Installation

Install a skill using the `skills` CLI:

```bash
npx skills add deepparser/skills --skill aws-s3-eks
npx skills add deepparser/skills --skill azure-bot
npx skills add deepparser/skills --skill eks-cluster
npx skills add deepparser/skills --skill exa.ai-websearch-api
npx skills add deepparser/skills --skill oas-api-spec-generator
```

## License

[MIT](LICENSE)
