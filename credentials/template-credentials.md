# Credential Setup Guide

This document explains how to create each credential in n8n. All values should be stored as environment variables in `.env` — never hard-coded.

---

## 1. Meta / Facebook Graph API

### Required for: Meta Enquiry Agent, Content Publisher, Ads Optimizer

#### a) Meta App Setup
1. Go to https://developers.facebook.com/apps
2. Create a new app (type: **Business**)
3. In the app dashboard, add the following products:
   - **Messenger** — for Messenger webhook
   - **Instagram Basic Display** — for Instagram publishing
   - **Marketing API** — for ads management
   - **Pages API** — for page posting

#### b) Page Access Token
1. In your app, go to **Messenger → Settings**
2. Under "Access Tokens", generate a **Page Access Token**
3. Copy this into `.env` as `META_PAGE_ACCESS_TOKEN`

#### c) System User Token (for Ads API)
1. Go to https://business.facebook.com/settings/system-users
2. Create a system user with **Ads Management** permissions
3. Generate a system user token
4. Copy into `.env` as `META_SYSTEM_USER_TOKEN`

#### d) Ad Account ID
- Found at https://business.facebook.com/adsmanager — the account ID (format: `act_123456789`)
- Copy into `.env` as `META_AD_ACCOUNT_ID`

#### e) Webhook Setup for Messenger
1. In your Meta app, go to **Messenger → Settings → Webhooks**
2. Click **Setup Webhooks**
3. Callback URL: `https://YOUR_N8N_DOMAIN/webhook/meta-messenger-webhook-YOUR_CLIENT_ID`
4. Verify token: set `META_WEBHOOK_VERIFY_TOKEN` in `.env` (defaults to `n8n-meta-verify`)
5. Subscribe to the **messages** and **messaging_postbacks** fields

#### f) Environment Variables
```bash
META_APP_ID=123456789
META_APP_SECRET=abc123def456
META_PAGE_ACCESS_TOKEN=EAAxxxxx...
META_AD_ACCOUNT_ID=act_123456789
META_SYSTEM_USER_TOKEN=EAAyyyyy...
META_WEBHOOK_VERIFY_TOKEN=n8n-meta-verify
```

---

## 2. Squarespace API

### Required for: Squarespace SEO Agent

1. Go to https://account.squarespace.com/api-keys
2. Click **Create Key**
3. Give the key a descriptive name (e.g., "n8n SEO Agent")
4. The key is only shown once — copy it immediately
5. Copy into `.env` as `SQUARESPACE_API_KEY`

To find your site ID:
```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  https://api.squarespace.com/1.0/sites
```
Copy the `id` field into `.env` as `SQUARESPACE_SITE_ID`.

```bash
SQUARESPACE_API_KEY=your-squarespace-api-key
SQUARESPACE_SITE_ID=your-site-id
```

---

## 3. LLM Providers

The LLM Router can use any combination of these. At minimum, configure **one**.

### a) Ollama (Local — free)

1. Install Ollama: `brew install ollama` (macOS) or Docker
2. Pull a model: `ollama pull llama3.2`
3. Start the server: `ollama serve`
4. Base URL from n8n Docker: `http://host.docker.internal:11434`

```bash
OLLAMA_BASE_URL=http://host.docker.internal:11434
```

### b) SiliconFlow (OpenAI-compatible — cheap)

1. Go to https://siliconflow.cn
2. Register and create an API key
3. The API is OpenAI-compatible at `https://api.siliconflow.cn/v1`
4. Recommended models: `Qwen/Qwen2.5-7B-Instruct` (cheap/quick), `deepseek-ai/DeepSeek-V3` (capable)

```bash
SILICONFLOW_API_KEY=sk-your-siliconflow-key
SILICONFLOW_BASE_URL=https://api.siliconflow.cn/v1
```

### c) Anthropic Claude (complex reasoning)

1. Go to https://console.anthropic.com
2. Create an API key
3. The LLM Router calls Anthropic as `httpRequest` using the HTTP API — you need to map auth in the workflow or use a custom header

**In the LLM Router workflow**, the "Claude (Complex)" node uses HTTP. Update the URL and auth to match Anthropic's API:
- URL: `https://api.anthropic.com/v1/messages`
- Header: `x-api-key: YOUR_KEY`
- Header: `anthropic-version: 2023-06-01`

```bash
ANTHROPIC_API_KEY=sk-ant-your-anthropic-key
```

### d) Grok / xAI (fallback)

1. Go to https://x.ai/api
2. Generate an API key
3. OpenAI-compatible at `https://api.x.ai/v1`

```bash
GROK_API_KEY=xai-your-grok-key
GROK_BASE_URL=https://api.x.ai/v1
```

### e) OpenAI

```bash
OPENAI_API_KEY=sk-your-openai-key
```

---

## 4. Google Sheets (Execution Logging)

1. Go to https://console.cloud.google.com
2. Create a project or select existing
3. Enable **Google Sheets API**
4. Go to **IAM & Admin → Service Accounts**
5. Create a service account with **Editor** role
6. Generate a JSON key and download
7. Extract `client_email` and `private_key` from the JSON

```bash
GOOGLE_SHEETS_CLIENT_EMAIL=your-service-account@project.iam.gserviceaccount.com
GOOGLE_SHEETS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_KEY\n-----END PRIVATE KEY-----\n"
```

8. Create a Google Sheet and share it with the service account email (Editor access)
9. Copy the Google Sheet ID from the URL: `https://docs.google.com/spreadsheets/d/SPREADSHEET_ID/edit`
10. Set up the sheet with column headers matching:
   - `timestamp, client_id, workflow, action, content, llm_provider, tokens_used, cost_estimate, status`

```bash
LOG_SPREADSHEET_ID=your-google-sheet-id
LOG_SHEET_NAME=ExecutionLog
```

---

## 5. Creating Credentials in n8n UI

After starting n8n, for each credential type:

1. Go to **Settings → Credentials** (or click the credential name in any node)
2. Click **Add Credential**
3. Choose the credential type and fill in the values from your `.env` file

Alternatively, use n8n expressions `{{ $env.VARIABLE }}` in credential fields to pull from environment.

### Credential Types Needed

| n8n Credential Type | Environment Variables |
|---|---|
| **HTTP Header Auth** (for SiliconFlow, Grok, OpenAI) | `SILICONFLOW_API_KEY`, `GROK_API_KEY`, `OPENAI_API_KEY` |
| **HTTP Query Auth** (for Meta Graph API) | `META_PAGE_ACCESS_TOKEN`, `META_SYSTEM_USER_TOKEN` |
| **Google Sheets OAuth2 API** or **Service Account** | `GOOGLE_SHEETS_CLIENT_EMAIL`, `GOOGLE_SHEETS_PRIVATE_KEY` |

---

## 6. Security Reminder

- **Never commit `.env` to git** — it's in `.gitignore`
- Rotate API keys every 90 days
- Use least-privilege scopes: Meta tokens should only have access to the needed pages/ad accounts
- Store backup copies of API keys in a password manager
- The `N8N_ENCRYPTION_KEY` is critical — if lost, all n8n credentials are unrecoverable. Store it securely.
