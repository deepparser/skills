---
name: azure-bot
description: "Create and manage Azure Bot resources using the Azure CLI. Covers the full lifecycle: identity creation, bot registration, channel configuration (Teams, Slack, Telegram, Direct Line, and more), and deployment to Azure App Service. ESPECIALLY for OpenClaw agents."
---

# Azure Bot Registration & Deployment

Create and manage Azure Bot resources using the Azure CLI (`az bot`). This skill covers the full lifecycle: identity creation, bot registration, channel configuration, and deployment.

## Prerequisites

Before running any commands, verify the user has:

```bash
# Check Azure CLI is installed and logged in
az account show --query "{subscription:name, tenantId:tenantId}" -o table
```

If not logged in, run `az login` first.

Required tools:
- Azure CLI 2.39.0+ (`az --version`)
- An active Azure subscription

## When to Use This Skill

Use when the user asks to:
- Create an Azure Bot resource
- Register a bot with Azure AI Bot Service
- Connect a bot to channels (Teams, Slack, Telegram, Direct Line, etc.)
- Deploy a bot to Azure App Service
- Manage bot identity (single-tenant, user-assigned managed identity)
- Set up a messaging endpoint for an existing bot

## Important Notes

- **Multi-tenant bot creation is deprecated after July 31, 2025.** Always default to **SingleTenant** or **UserAssignedMSI**.
- Bot names must be 4-42 characters, alphanumeric + hyphens + underscores only.
- The free tier (F0) is suitable for development; use S1 for production.

## Step-by-Step: Create an Azure Bot

### Step 1: Gather Required Information

Ask the user for these values (provide sensible defaults):

| Parameter | Description | Default |
|-----------|-------------|---------|
| `BOT_NAME` | Resource name (4-42 chars, alphanumeric/hyphens/underscores) | — (required) |
| `RESOURCE_GROUP` | Azure resource group | `rg-<BOT_NAME>` |
| `LOCATION` | Azure region | `eastus` |
| `APP_TYPE` | Identity type: `SingleTenant` or `UserAssignedMSI` | `SingleTenant` |
| `DISPLAY_NAME` | Human-readable display name | Same as BOT_NAME |
| `ENDPOINT` | Messaging endpoint URL (https://...) | Can be set later |
| `SKU` | Pricing tier: `F0` (free) or `S1` (standard) | `F0` |

### Step 2: Create Resource Group (if needed)

```bash
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}"
```

### Step 3: Create Identity

**Option A: Single-Tenant App Registration (Recommended)**

```bash
# Create the app registration
az ad app create \
  --display-name "${BOT_NAME}" \
  --sign-in-audience "AzureADMyOrg"

# Note the appId from the output, then generate a password
az ad app credential reset --id "<appId>"
```

Record these values:
- `APP_ID` — the `appId` from `az ad app create` output
- `APP_PASSWORD` — the `password` from `az ad app credential reset` output
- `TENANT_ID` — from `az account show --query tenantId -o tsv`

**Option B: User-Assigned Managed Identity**

```bash
# Create the managed identity
az identity create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}-identity"
```

Record:
- `CLIENT_ID` — the `clientId` from output
- `TENANT_ID` — from `az account show --query tenantId -o tsv`
- `MSI_RESOURCE_ID` — the `id` from output (full ARM resource ID)

### Step 4: Create the Azure Bot Resource

**For Single-Tenant:**

```bash
az bot create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}" \
  --app-type "SingleTenant" \
  --appid "${APP_ID}" \
  --tenant-id "${TENANT_ID}" \
  --display-name "${DISPLAY_NAME}" \
  --endpoint "${ENDPOINT}" \
  --sku "${SKU}"
```

**For User-Assigned Managed Identity:**

```bash
az bot create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}" \
  --app-type "UserAssignedMSI" \
  --appid "${CLIENT_ID}" \
  --tenant-id "${TENANT_ID}" \
  --msi-resource-id "${MSI_RESOURCE_ID}" \
  --display-name "${DISPLAY_NAME}" \
  --endpoint "${ENDPOINT}" \
  --sku "${SKU}"
```

### Step 5: Verify Bot Creation

```bash
az bot show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}" \
  -o table
```

## Channel Configuration

### Microsoft Teams

```bash
az bot msteams create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}"
```

### Slack

```bash
# Requires: Slack App client ID, client secret, verification token, and landing page URL
az bot slack create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}" \
  --client-id "<slack-client-id>" \
  --client-secret "<slack-client-secret>" \
  --verification-token "<slack-verification-token>" \
  --landing-page-url "<landing-page-url>"
```

### Telegram

```bash
# Requires: Telegram bot token from @BotFather
az bot telegram create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}" \
  --access-token "<telegram-bot-token>"
```

### Direct Line (for web/mobile apps)

```bash
az bot directline create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}"
```

Get the Direct Line secret:

```bash
az bot directline show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}" \
  --query "properties.properties.sites[0].key" -o tsv
```

### Facebook Messenger

```bash
az bot facebook create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}" \
  --appid "<facebook-app-id>" \
  --app-secret "<facebook-app-secret>" \
  --page-id "<facebook-page-id>" \
  --access-token "<facebook-page-access-token>"
```

### Email

```bash
az bot email create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}" \
  --email-address "<email@outlook.com>" \
  --password "<email-password>"
```

### Web Chat (enabled by default)

Web Chat is automatically configured. Get the secret:

```bash
az bot webchat show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}" \
  --query "properties.properties.sites[0].key" -o tsv
```

### Show Channel Details

```bash
# Teams
az bot msteams show --resource-group "${RESOURCE_GROUP}" --name "${BOT_NAME}"

# Slack
az bot slack show --resource-group "${RESOURCE_GROUP}" --name "${BOT_NAME}"

# Telegram
az bot telegram show --resource-group "${RESOURCE_GROUP}" --name "${BOT_NAME}"

# Direct Line
az bot directline show --resource-group "${RESOURCE_GROUP}" --name "${BOT_NAME}"
```

## Update Bot Configuration

### Update Messaging Endpoint

```bash
az bot update \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}" \
  --endpoint "https://your-bot.azurewebsites.net/api/messages"
```

### Update Display Name and Description

```bash
az bot update \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}" \
  --display-name "My Bot Display Name" \
  --description "Bot description here"
```

### Upgrade SKU

```bash
az bot update \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}" \
  --sku S1
```

## Deploy Bot Code to App Service

### Step 1: Create App Service Plan + Web App (if hosting on Azure)

```bash
# Create App Service Plan
az appservice plan create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}-plan" \
  --sku B1 \
  --is-linux

# Create Web App (Python example)
az webapp create \
  --resource-group "${RESOURCE_GROUP}" \
  --plan "${BOT_NAME}-plan" \
  --name "${BOT_NAME}-app" \
  --runtime "PYTHON:3.11"

# Or for Node.js
az webapp create \
  --resource-group "${RESOURCE_GROUP}" \
  --plan "${BOT_NAME}-plan" \
  --name "${BOT_NAME}-app" \
  --runtime "NODE:20-lts"
```

### Step 2: Configure App Settings

**For Single-Tenant:**

```bash
az webapp config appsettings set \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}-app" \
  --settings \
    MicrosoftAppType=SingleTenant \
    MicrosoftAppId="${APP_ID}" \
    MicrosoftAppPassword="${APP_PASSWORD}" \
    MicrosoftAppTenantId="${TENANT_ID}"
```

**For User-Assigned Managed Identity:**

```bash
az webapp config appsettings set \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}-app" \
  --settings \
    MicrosoftAppType=UserAssignedMSI \
    MicrosoftAppId="${CLIENT_ID}" \
    MicrosoftAppPassword="" \
    MicrosoftAppTenantId="${TENANT_ID}"
```

### Step 3: Prepare & Deploy Code

```bash
# Prepare deployment files (run from bot project root)
az bot prepare-deploy --lang <Csharp|Javascript|Typescript> --code-dir "."

# Deploy via zip
zip -r bot.zip . -x "*.git*" "node_modules/*" "__pycache__/*" ".env"
az webapp deploy \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}-app" \
  --src-path bot.zip \
  --type zip
```

### Step 4: Update Bot Endpoint

```bash
az bot update \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}" \
  --endpoint "https://${BOT_NAME}-app.azurewebsites.net/api/messages"
```

## OAuth Connection Settings

For bots that need OAuth (e.g., accessing Microsoft Graph):

```bash
# List available OAuth providers
az bot authsetting list-providers \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}"

# Create an OAuth connection
az bot authsetting create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${BOT_NAME}" \
  --setting-name "<connection-name>" \
  --provider-scope-string "<scopes>" \
  --client-id "<oauth-client-id>" \
  --client-secret "<oauth-client-secret>" \
  --service "Aadv2"
```

## Bot Configuration File Templates

### Python (`config.py`)

```python
import os

class DefaultConfig:
    PORT = 3978
    APP_TYPE = os.environ.get("MicrosoftAppType", "SingleTenant")
    APP_ID = os.environ.get("MicrosoftAppId", "")
    APP_PASSWORD = os.environ.get("MicrosoftAppPassword", "")
    APP_TENANTID = os.environ.get("MicrosoftAppTenantId", "")
```

### JavaScript (`.env`)

```
MicrosoftAppType=SingleTenant
MicrosoftAppId=<your-app-id>
MicrosoftAppPassword=<your-app-password>
MicrosoftAppTenantId=<your-tenant-id>
```

### C# (`appsettings.json`)

```json
{
  "MicrosoftAppType": "SingleTenant",
  "MicrosoftAppId": "<your-app-id>",
  "MicrosoftAppPassword": "<your-app-password>",
  "MicrosoftAppTenantId": "<your-tenant-id>"
}
```

## Management Commands

```bash
# List all bots in a resource group
az bot list --resource-group "${RESOURCE_GROUP}" -o table

# Show bot details
az bot show --resource-group "${RESOURCE_GROUP}" --name "${BOT_NAME}"

# Delete a bot
az bot delete --resource-group "${RESOURCE_GROUP}" --name "${BOT_NAME}"

# Delete a channel
az bot msteams delete --resource-group "${RESOURCE_GROUP}" --name "${BOT_NAME}"
az bot slack delete --resource-group "${RESOURCE_GROUP}" --name "${BOT_NAME}"
az bot telegram delete --resource-group "${RESOURCE_GROUP}" --name "${BOT_NAME}"
az bot directline delete --resource-group "${RESOURCE_GROUP}" --name "${BOT_NAME}"

# Generate a new app password
az ad app credential reset --id "${APP_ID}"
```

## Troubleshooting

### Bot not responding
1. Check the messaging endpoint is correct and starts with `https://`
2. Verify App ID and password match between Azure Bot and your app settings
3. Check App Service logs: `az webapp log tail --resource-group "${RESOURCE_GROUP}" --name "${BOT_NAME}-app"`

### Channel-specific issues
- **Teams**: Ensure the bot is also registered in the Teams Developer Portal
- **Slack**: Verify the verification token and OAuth redirect URLs
- **Telegram**: Check the bot token from @BotFather is correct

### Common errors
- `MicrosoftAppId or MicrosoftAppPassword is not correct` — regenerate password with `az ad app credential reset`
- `Endpoint must start with https` — update endpoint: `az bot update --endpoint "https://..."`
- `Bot name already taken` — bot names are globally unique, choose a different name

## Reference Links

- Azure Bot registration: https://learn.microsoft.com/en-us/azure/bot-service/bot-service-quickstart-registration
- Deploy a bot: https://learn.microsoft.com/en-us/azure/bot-service/provision-and-publish-a-bot
- Channel configuration: https://learn.microsoft.com/en-us/azure/bot-service/bot-service-manage-channels
- az bot CLI reference: https://learn.microsoft.com/en-us/cli/azure/bot
- Bot Framework Samples: https://github.com/microsoft/BotBuilder-Samples
