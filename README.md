# n8n SMB Agent Template

Production-ready, multi-client n8n deployment for AI-driven Meta (Facebook/Instagram), Squarespace SEO, and multi-LLM routing. Deploy in under 30 minutes.

## Architecture

```
┌─────────────────────────────────────────┐
│              n8n (Queue Mode)            │
│  ┌──────────┐  ┌──────────┐  ┌───────┐ │
│  │ Meta     │  │ Content  │  │ Ads   │ │
│  │ Enquiry  │  │ Publisher│  │Optimi.│ │
│  └────┬─────┘  └────┬─────┘  └───┬───┘ │
│       │             │            │     │
│       └──────┬──────┴────────────┘     │
│              │                         │
│       ┌──────▼──────┐  ┌───────────┐   │
│       │  LLM Router │  │Squarespace│   │
│       │  Sub-wflow  │  │SEO Agent  │   │
│       └──┬──┬──┬──┬─┘  └───────────┘   │
│          │  │  │  │                    │
│   ┌──────┘  │  │  └──────┐             │
│   ▼         ▼  ▼         ▼             │
│ Ollama  Silicon Claude  Grok           │
│         Flow                           │
└─────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Docker & Docker Compose (OrbStack recommended on macOS)
- Git
- A domain pointing to your server (for production webhooks)

### 1. Clone & Configure

```bash
git clone git@github.com:Smith-Gray-Pty-Ltd/n8n-smb-agent-template.git client-name
cd client-name
cp .env.example .env
```

Edit `.env` and fill in at minimum:
- `N8N_ENCRYPTION_KEY` — generate with `openssl rand -hex 16`
- `N8N_HOST` — your domain
- At least one LLM provider (Ollama, SiliconFlow, Anthropic, or Grok)
- Meta credentials if using Meta workflows
- Squarespace credentials if using SEO workflows

### 2. Deploy

```bash
docker compose up -d
```

n8n will be available at `http://localhost:5678` (or your configured domain).

### 3. Import Workflows

```bash
chmod +x update-workflows.sh
./update-workflows.sh
```

Or import manually via **n8n UI → Import from File** for each JSON in `workflows/`.

### 4. Import the LLM Router Sub-Workflow First

1. Go to **Workflows → Import from File**
2. Select `workflows/llm-router-subworkflow.json`
3. **Activate** the workflow
4. Note its **Sub-Workflow ID** (used by other workflows)

### 5. Set Up Credentials

Follow `credentials/template-credentials.md` to create credentials in n8n.

### 6. Activate Workflows

Activate each workflow in order:
1. LLM Router Sub-Workflow (must be active first)
2. Master Meta Enquiry Agent
3. Content Publisher Agent
4. Ads Optimizer Agent
5. Squarespace SEO Agent

## Workflow Descriptions

| Workflow | Trigger | Purpose |
|---|---|---|
| **LLM Router** | Sub-workflow call | Routes tasks to optimal LLM (Ollama for routine, Claude for complex, Grok as fallback) |
| **Master Meta Enquiry Agent** | Messenger Webhook | Triages inbound messages, generates AI replies, queues for human approval |
| **Content Publisher Agent** | Schedule / Manual | Optimizes and publishes content to Facebook & Instagram |
| **Ads Optimizer Agent** | Schedule (daily) | Pulls ad insights, suggests budget/creative optimizations with human approval |
| **Squarespace SEO Agent** | Schedule (weekly) | Analyzes Squarespace pages for SEO, geo/local improvements with human approval |

## Environment Variables

All customization is via environment variables in `.env`. Key variables:

| Variable | Required | Description |
|---|---|---|
| `CLIENT_ID` | Yes | Unique client identifier for multi-tenant logging |
| `BRAND_VOICE` | Yes | AI prompt prefix for consistent brand tone |
| `N8N_ENCRYPTION_KEY` | Yes | Encryption key for credentials (generate via `openssl rand -hex 16`) |
| `META_PAGE_ACCESS_TOKEN` | For Meta | Facebook page access token |
| `META_AD_ACCOUNT_ID` | For ads | Meta ad account ID |
| `SQUARESPACE_API_KEY` | For SEO | Squarespace API key |
| `OLLAMA_BASE_URL` | For LLM | Ollama server URL |
| `ANTHROPIC_API_KEY` | For Claude | Anthropic API key |
| `SILICONFLOW_API_KEY` | For LLM | SiliconFlow API key |
| `GROK_API_KEY` | For LLM | xAI Grok API key |

See `.env.example` for the full list.

## Observability

- **Execution Logs**: All workflows log to Google Sheets (configure `GOOGLE_SHEETS_*` vars)
- **n8n GUI**: Built-in execution history at `/executions`
- **Error Handling**: All HTTP calls include retry logic and fallback paths
- **Monitoring**: `docker compose logs -f n8n` for real-time logs

## Multi-Client Deployment

Clone this repo once per client with separate `.env` files:

```bash
git clone git@github.com:Smith-Gray-Pty-Ltd/n8n-smb-agent-template.git client-acme
cd client-acme
cp .env.example .env
# Edit .env with acme-specific values
docker compose -p acme up -d
```

Each instance is fully isolated with:
- Separate Postgres database
- Separate Redis instance
- Client-tagged execution logs
- Independent branding via `BRAND_VOICE`

## Security

- **Basic Auth**: Enabled by default — change `N8N_BASIC_AUTH_USER` and `N8N_BASIC_AUTH_PASSWORD`
- **Encryption**: All credentials encrypted with `N8N_ENCRYPTION_KEY`
- **No hard-coded secrets**: Every credential is an environment variable
- **Human-in-the-loop**: Ads and publishing workflows require manual approval
- **Queue mode**: Executions isolated with Redis-backed queue
- **Reverse proxy**: Use nginx/traefik/Caddy in front of n8n for HTTPS in production

## Upgrading

```bash
docker compose pull
docker compose up -d
```

n8n auto-migrates the database on startup. Backup Postgres before major version bumps:

```bash
docker compose exec postgres pg_dump -U n8n n8n > backup.sql
```
