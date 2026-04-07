# Skills

A collection of Claude Code, Codex, Antigravity, OpenClaw, IronClaw, Nanobot skills.

## Available Skills

### Cloud & Infrastructure

| Skill | Description |
| --- | --- |
| [eks-cluster](eks-cluster/) | Create and manage Amazon EKS clusters, managed node groups, and EC2 instances — includes VPC networking, addons (CoreDNS, kube-proxy, VPC CNI, EBS CSI, Pod Identity Agent), autoscaling, and troubleshooting |
| [aws-s3-eks](aws-s3-eks/) | Create S3 buckets with encryption/versioning and configure EKS Pod Identity so pods access S3 without static credentials — includes IAM policies, K8s manifests, and S3 OpenAPI spec |
| [azure-bot](azure-bot/) | Create and manage Azure Bot resources — covers identity creation, bot registration, channel configuration (Teams, Slack, Telegram, Direct Line), and deployment to Azure App Service |

### APIs & Integrations

| Skill | Description |
| --- | --- |
| [oas-api-spec-generator](oas-api-spec-generator/) | Generate OpenAPI 3.2.0 specifications for third-party APIs (OpenAI, Anthropic, Google, Microsoft, Stripe, GitHub, Slack, AWS, and more) |
| [exa.ai-websearch-api](exa.ai-websearch-api/) | Real-time web search and content retrieval using the Exa API — optimized for balanced relevance and speed with full-text extraction for RAG and code assistance |

### Brand Design Systems (58 skills)

Apply brand-accurate design systems (colors, typography, components, layout, shadows) when building UI. Each skill includes light and dark theme HTML previews.

| Skill | Brand |
| --- | --- |
| [design-airbnb](design-airbnb/) | Airbnb |
| [design-airtable](design-airtable/) | Airtable |
| [design-apple](design-apple/) | Apple |
| [design-bmw](design-bmw/) | BMW |
| [design-cal](design-cal/) | Cal.com |
| [design-claude](design-claude/) | Claude (Anthropic) |
| [design-clay](design-clay/) | Clay |
| [design-clickhouse](design-clickhouse/) | ClickHouse |
| [design-cohere](design-cohere/) | Cohere |
| [design-coinbase](design-coinbase/) | Coinbase |
| [design-composio](design-composio/) | Composio |
| [design-cursor](design-cursor/) | Cursor |
| [design-elevenlabs](design-elevenlabs/) | ElevenLabs |
| [design-expo](design-expo/) | Expo |
| [design-ferrari](design-ferrari/) | Ferrari |
| [design-figma](design-figma/) | Figma |
| [design-framer](design-framer/) | Framer |
| [design-hashicorp](design-hashicorp/) | HashiCorp |
| [design-ibm](design-ibm/) | IBM |
| [design-intercom](design-intercom/) | Intercom |
| [design-kraken](design-kraken/) | Kraken |
| [design-lamborghini](design-lamborghini/) | Lamborghini |
| [design-linear.app](design-linear.app/) | Linear |
| [design-lovable](design-lovable/) | Lovable |
| [design-minimax](design-minimax/) | MiniMax |
| [design-mintlify](design-mintlify/) | Mintlify |
| [design-miro](design-miro/) | Miro |
| [design-mistral.ai](design-mistral.ai/) | Mistral AI |
| [design-mongodb](design-mongodb/) | MongoDB |
| [design-notion](design-notion/) | Notion |
| [design-nvidia](design-nvidia/) | NVIDIA |
| [design-ollama](design-ollama/) | Ollama |
| [design-opencode.ai](design-opencode.ai/) | OpenCode |
| [design-pinterest](design-pinterest/) | Pinterest |
| [design-posthog](design-posthog/) | PostHog |
| [design-raycast](design-raycast/) | Raycast |
| [design-renault](design-renault/) | Renault |
| [design-replicate](design-replicate/) | Replicate |
| [design-resend](design-resend/) | Resend |
| [design-revolut](design-revolut/) | Revolut |
| [design-runwayml](design-runwayml/) | Runway |
| [design-sanity](design-sanity/) | Sanity |
| [design-sentry](design-sentry/) | Sentry |
| [design-spacex](design-spacex/) | SpaceX |
| [design-spotify](design-spotify/) | Spotify |
| [design-stripe](design-stripe/) | Stripe |
| [design-supabase](design-supabase/) | Supabase |
| [design-superhuman](design-superhuman/) | Superhuman |
| [design-tesla](design-tesla/) | Tesla |
| [design-together.ai](design-together.ai/) | Together AI |
| [design-uber](design-uber/) | Uber |
| [design-vercel](design-vercel/) | Vercel |
| [design-voltagent](design-voltagent/) | VoltAgent |
| [design-warp](design-warp/) | Warp |
| [design-webflow](design-webflow/) | Webflow |
| [design-wise](design-wise/) | Wise |
| [design-x.ai](design-x.ai/) | xAI |
| [design-zapier](design-zapier/) | Zapier |

## Installation

Install a skill using the `skills` CLI:

```bash
# Cloud & Infrastructure
npx skills add deepparser/skills --skill eks-cluster
npx skills add deepparser/skills --skill aws-s3-eks
npx skills add deepparser/skills --skill azure-bot

# APIs & Integrations
npx skills add deepparser/skills --skill oas-api-spec-generator
npx skills add deepparser/skills --skill exa.ai-websearch-api

# Brand Design Systems (examples)
npx skills add deepparser/skills --skill design-stripe
npx skills add deepparser/skills --skill design-vercel
npx skills add deepparser/skills --skill design-supabase
npx skills add deepparser/skills --skill design-claude
# ... and 54 more — see the full list above
```

## Acknowledgements

The brand design system skills are based on [VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md) — a curated collection of brand design system markdown files for AI-assisted UI development.

## License

[MIT](LICENSE)
