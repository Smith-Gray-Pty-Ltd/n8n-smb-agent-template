# n8n SMB Agent Template

Production-ready, multi-client n8n deployment for AI-driven Meta (Facebook/Instagram), Squarespace SEO, and multi-LLM routing. Deploy locally with OrbStack in under 10 minutes, or to Hostinger VPS in under 30.

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
│(Local/   Flow   API    (xAI)           │
│ Cloud)                                 │
└─────────────────────────────────────────┘
```

## Recommended Hosting

| Environment | Tool | Best For |
|---|---|---|
| **Local Dev (macOS)** | [OrbStack](https://orbstack.dev) | Fast, lightweight Docker — 200-400MB less RAM than Docker Desktop |
| **Production VPS** | [Hostinger VPS](https://hostinger.com/vps) | Affordable KVM VPS with excellent AU/SG/US data centers |
| **Alternative VPS** | Any Ubuntu 22.04+ VPS | Hetzner, DigitalOcean, Linode, Vultr — all work fine |

---

## Quick Start: Local Development (OrbStack)

### Prerequisites

- [OrbStack](https://orbstack.dev) installed (`brew install orbstack`)
- Git
- (Optional) [Ollama](https://ollama.com) for local LLM inference

### 1. Clone & Configure

```bash
git clone git@github.com:Smith-Gray-Pty-Ltd/n8n-smb-agent-template.git client-name
cd client-name
cp .env.example .env
```

Edit `.env` and set at minimum:
- `N8N_ENCRYPTION_KEY` — generate with `openssl rand -hex 16`
- `N8N_HOST=localhost` (local dev)
- `N8N_PROTOCOL=http` (local dev)
- At least one LLM provider (see below)

### 2. Start OrbStack (if not running)

```bash
open -a OrbStack
# or
orb start
```

### 3. Deploy

```bash
docker compose up -d
```

Wait for services to be healthy (30-60 seconds):

```bash
docker compose ps
```

n8n is now at **http://localhost:5678**.

### 4. Import Workflows

```bash
chmod +x update-workflows.sh
./update-workflows.sh
```

### 5. Set Up Credentials & Activate

Follow `credentials/template-credentials.md`. Then activate workflows in the n8n UI.

---

## Quick Start: Deploy to Hostinger VPS

See **[HOSTINGER-DEPLOY.md](HOSTINGER-DEPLOY.md)** for the full step-by-step guide.

Quick summary:

```bash
# On your VPS:
git clone https://github.com/Smith-Gray-Pty-Ltd/n8n-smb-agent-template.git /opt/n8n-smb
cd /opt/n8n-smb
cp .env.example .env
# Edit .env with your domain and credentials
./deploy-hostinger.sh
```

---

## OrbStack-Specific Tips

### Accessing Host from Containers

OrbStack automatically configures `host.docker.internal` to resolve to your Mac. This lets n8n containers reach services running on macOS — like Ollama:

```bash
# .env
OLLAMA_BASE_URL=http://host.docker.internal:11434
```

The `extra_hosts` entry `host.docker.internal:host-gateway` in `docker-compose.yml` handles this for both OrbStack and Docker Desktop.

### Performance

OrbStack uses native macOS virtualization — filesystem I/O is up to 20x faster than Docker Desktop. This matters for n8n execution logs and Postgres.

### Running Ollama on Mac

```bash
# Install and start Ollama
brew install ollama
ollama serve

# Pull a model
ollama pull llama3.2

# Verify from within n8n container
docker compose exec n8n wget -qO- http://host.docker.internal:11434/api/tags
```

### OrbStack vs Docker Desktop

| Feature | OrbStack | Docker Desktop |
|---|---|---|
| RAM usage (idle) | ~200 MB | ~600-800 MB |
| File I/O speed | Native | osxfs (slower) |
| Rosetta x86 emulation | Built-in | Requires config |
| Linux machines | `orb` / `orbctl` | No |
| Price | Free for personal | Free / $9+ |

---

## Workflow Descriptions

| Workflow | Trigger | Purpose |
|---|---|---|
| **LLM Router** | Sub-workflow call | Routes tasks to optimal LLM with fallback cascade |
| **Master Meta Enquiry Agent** | Messenger Webhook | Triages messages, generates AI replies, queues for human approval |
| **Content Publisher Agent** | Schedule / Manual | Optimizes and publishes content to Facebook & Instagram |
| **Ads Optimizer Agent** | Schedule (daily) | Pulls ad insights, suggests optimizations with human approval |
| **Squarespace SEO Agent** | Schedule (weekly) | Audits Squarespace pages for SEO, geo/local improvements |

## LLM Router: How It Routes

The LLM Router sub-workflow selects the best provider based on `task_type`:

| Task Type | Primary Provider | Why |
|---|---|---|
| `routine` | Ollama (local) or SiliconFlow | Cheap, fast — ideal for simple replies |
| `quick` | SiliconFlow (Qwen) | 7B model, sub-second responses |
| `analysis` | Anthropic Claude | Complex reasoning for SEO, ads, strategy |
| `complex` | SiliconFlow (DeepSeek-V3) | Strong reasoning at 1/10th Claude's cost |
| `fallback` (default) | Grok (xAI) | Reliable OpenAI-compatible as last resort |

If the primary provider fails, the router falls back to the next available provider automatically.

---

## Environment Variables

All customization is via environment variables in `.env`. Key variables:

| Variable | Required | Description |
|---|---|---|
| `CLIENT_ID` | Yes | Unique client identifier for multi-tenant logging |
| `BRAND_VOICE` | Yes | AI prompt prefix for consistent brand tone |
| `N8N_ENCRYPTION_KEY` | Yes | Encryption key (generate via `openssl rand -hex 16`) |
| `N8N_VERSION` | Prod | Pin n8n version for stability (e.g., `1.91.0`) |
| `META_PAGE_ACCESS_TOKEN` | For Meta | Facebook page access token |
| `META_AD_ACCOUNT_ID` | For ads | Meta ad account ID |
| `SQUARESPACE_API_KEY` | For SEO | Squarespace API key |
| `OLLAMA_BASE_URL` | For LLM | Ollama server URL (local or cloud) |
| `ANTHROPIC_API_KEY` | For Claude | Anthropic API key |
| `SILICONFLOW_API_KEY` | For LLM | SiliconFlow API key |
| `GROK_API_KEY` | For LLM | xAI Grok API key |
| `SERVER_IP` | For VPS | Server IP for firewall/health checks |
| `DOMAIN` | For VPS | Domain name for webhooks/URLs |

See `.env.example` for the full list.

---

## Observability

- **Execution Logs**: All workflows log to Google Sheets
- **n8n GUI**: Built-in execution history at `/executions`
- **Docker Healthchecks**: All services have health checks — check with `docker compose ps`
- **Error Handling**: HTTP calls include retry logic (3 attempts) and fallback cascade
- **Hostinger VPS**: Monitor CPU/RAM via hPanel or `hapi vps vm metrics`

---

## Multi-Client Deployment

Clone once per client with isolated `.env` and project name:

```bash
git clone git@github.com:Smith-Gray-Pty-Ltd/n8n-smb-agent-template.git client-acme
cd client-acme
cp .env.example .env
# Edit .env with acme-specific values
docker compose -p acme up -d
```

Each instance is fully isolated with:
- Separate Postgres database (via `COMPOSE_PROJECT_NAME`)
- Separate Redis instance
- Client-tagged execution logs
- Independent `BRAND_VOICE`

---

## Webhook Configuration

### Meta Messenger Webhook

Webhook URL: `https://YOUR_DOMAIN/webhook/meta-messenger-webhook-YOUR_CLIENT_ID`

Where `YOUR_CLIENT_ID` matches the `CLIENT_ID` in `.env`.

### Human Approval Webhooks

Approval webhooks are at:
- `https://YOUR_DOMAIN/webhook-wait/human-approval-SENDER_ID` (Meta Enquiry)
- `https://YOUR_DOMAIN/webhook-wait/content-approval-DATE` (Content Publisher)
- `https://YOUR_DOMAIN/webhook-wait/ads-approval-DATE` (Ads Optimizer)
- `https://YOUR_DOMAIN/webhook-wait/seo-approval-WEEK` (SEO Agent)

> **Important**: n8n Webhook nodes **must be activated** before they can receive requests. Always activate a workflow before testing its webhooks.

---

## Security

- **Basic Auth**: Enabled by default — change username and password immediately
- **Encryption**: All credentials encrypted with `N8N_ENCRYPTION_KEY`
- **No hard-coded secrets**: Every credential sourced from environment variables
- **Human-in-the-loop**: Ads, publishing, and SEO workflows require manual approval
- **Queue mode**: Executions isolated with Redis-backed queue
- **HTTPS**: Use Caddy or nginx reverse proxy in production
- **Firewall**: UFW configured to allow only 22/80/443

---

## Upgrading

```bash
# Local dev
docker compose pull
docker compose up -d

# Hostinger VPS
cd /opt/n8n-smb
git pull origin main
docker compose pull
docker compose up -d
```

**Backup before upgrading:**

```bash
docker compose exec postgres pg_dump -U n8n n8n > backup-$(date +%Y%m%d).sql
```

n8n auto-migrates the database on startup — no manual migration needed.

---

## Files

```
├── docker-compose.yml          # docker compose config
├── .env.example                # template env vars
├── .gitignore
├── LICENSE                     # MIT
├── README.md                   # this file
├── HOSTINGER-DEPLOY.md         # full Hostinger VPS guide
├── deploy-hostinger.sh         # automated deploy script
├── update-workflows.sh         # workflow import script
├── credentials/
│   └── template-credentials.md
└── workflows/
    ├── llm-router-subworkflow.json
    ├── master-meta-enquiry-agent.json
    ├── content-publisher-agent.json
    ├── ads-optimizer-agent.json
    └── squarespace-seo-agent.json
```
