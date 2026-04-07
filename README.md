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
| [design-airbnb](design-md/airbnb/) | Airbnb |
| [design-airtable](design-md/airtable/) | Airtable |
| [design-apple](design-md/apple/) | Apple |
| [design-bmw](design-md/bmw/) | BMW |
| [design-cal](design-md/cal/) | Cal.com |
| [design-claude](design-md/claude/) | Claude (Anthropic) |
| [design-clay](design-md/clay/) | Clay |
| [design-clickhouse](design-md/clickhouse/) | ClickHouse |
| [design-cohere](design-md/cohere/) | Cohere |
| [design-coinbase](design-md/coinbase/) | Coinbase |
| [design-composio](design-md/composio/) | Composio |
| [design-cursor](design-md/cursor/) | Cursor |
| [design-elevenlabs](design-md/elevenlabs/) | ElevenLabs |
| [design-expo](design-md/expo/) | Expo |
| [design-ferrari](design-md/ferrari/) | Ferrari |
| [design-figma](design-md/figma/) | Figma |
| [design-framer](design-md/framer/) | Framer |
| [design-hashicorp](design-md/hashicorp/) | HashiCorp |
| [design-ibm](design-md/ibm/) | IBM |
| [design-intercom](design-md/intercom/) | Intercom |
| [design-kraken](design-md/kraken/) | Kraken |
| [design-lamborghini](design-md/lamborghini/) | Lamborghini |
| [design-linear.app](design-md/linear.app/) | Linear |
| [design-lovable](design-md/lovable/) | Lovable |
| [design-minimax](design-md/minimax/) | MiniMax |
| [design-mintlify](design-md/mintlify/) | Mintlify |
| [design-miro](design-md/miro/) | Miro |
| [design-mistral.ai](design-md/mistral.ai/) | Mistral AI |
| [design-mongodb](design-md/mongodb/) | MongoDB |
| [design-notion](design-md/notion/) | Notion |
| [design-nvidia](design-md/nvidia/) | NVIDIA |
| [design-ollama](design-md/ollama/) | Ollama |
| [design-opencode.ai](design-md/opencode.ai/) | OpenCode |
| [design-pinterest](design-md/pinterest/) | Pinterest |
| [design-posthog](design-md/posthog/) | PostHog |
| [design-raycast](design-md/raycast/) | Raycast |
| [design-renault](design-md/renault/) | Renault |
| [design-replicate](design-md/replicate/) | Replicate |
| [design-resend](design-md/resend/) | Resend |
| [design-revolut](design-md/revolut/) | Revolut |
| [design-runwayml](design-md/runwayml/) | Runway |
| [design-sanity](design-md/sanity/) | Sanity |
| [design-sentry](design-md/sentry/) | Sentry |
| [design-spacex](design-md/spacex/) | SpaceX |
| [design-spotify](design-md/spotify/) | Spotify |
| [design-stripe](design-md/stripe/) | Stripe |
| [design-supabase](design-md/supabase/) | Supabase |
| [design-superhuman](design-md/superhuman/) | Superhuman |
| [design-tesla](design-md/tesla/) | Tesla |
| [design-together.ai](design-md/together.ai/) | Together AI |
| [design-uber](design-md/uber/) | Uber |
| [design-vercel](design-md/vercel/) | Vercel |
| [design-voltagent](design-md/voltagent/) | VoltAgent |
| [design-warp](design-md/warp/) | Warp |
| [design-webflow](design-md/webflow/) | Webflow |
| [design-wise](design-md/wise/) | Wise |
| [design-x.ai](design-md/x.ai/) | xAI |
| [design-zapier](design-md/zapier/) | Zapier |

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

## License

[MIT](LICENSE)
