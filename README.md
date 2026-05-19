# n8n SMB Agent Template

Production-ready, multi-client n8n deployment for AI-driven Meta (Facebook/Instagram), Squarespace SEO, and multi-LLM routing. Deploy locally with OrbStack in under 10 minutes, or to Hostinger VPS in under 30.

---

## Changelog

| Date | Version | Changes |
|---|---|---|
| 2026-05-19 | 2.0.0 | LLM Router v2 with Anthropic endpoint fix + fallback cascade; OrbStack guide; Hostinger VPS deploy guide; Traefik labels; `deploy-hostinger.sh` |
| 2026-05-19 | 1.0.0 | Initial release — 5 workflows, multi-LLM router, docker compose with queue mode |

---

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

---

## Recommended Hosting

| Environment | Tool | Best For |
|---|---|---|
| **Local Dev (macOS)** | [OrbStack](https://orbstack.dev) | Fast, lightweight — 200-400MB less RAM than Docker Desktop |
| **Production VPS** | [Hostinger VPS](https://hostinger.com/vps) | Affordable KVM VPS with AU/SG/US data centers |
| **Alternative VPS** | Any Ubuntu 22.04+ VPS | Hetzner, DigitalOcean, Linode, Vultr — all work fine |

---

## One-Command Deploy (Hostinger VPS)

From a fresh Ubuntu 24.04 VPS, copy and paste:

```bash
curl -fsSL https://get.docker.com | sh && \
git clone https://github.com/Smith-Gray-Pty-Ltd/n8n-smb-agent-template.git /opt/n8n-smb && \
cd /opt/n8n-smb && \
cp .env.example .env && \
echo "EDIT .env NOW: nano .env" && \
./deploy-hostinger.sh
```

Then edit `.env`, run `./deploy-hostinger.sh` again, and n8n is live.

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
- At least one LLM provider

### 2. Start OrbStack

```bash
open -a OrbStack   # or: orb start
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
./update-workflows.sh
```

### 5. Set Up Credentials & Activate

Follow `credentials/template-credentials.md`. Then activate workflows in the n8n UI.

---

## OrbStack-Specific Tips

### Networking: host.docker.internal

OrbStack auto-resolves `host.docker.internal` to your Mac. The `docker-compose.yml` includes:

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

This works identically in OrbStack and Docker Desktop.

### Running Ollama Locally

```bash
brew install ollama
ollama serve               # Start in a separate terminal
ollama pull llama3.2       # Pull your model

# Verify from inside n8n:
docker compose exec n8n wget -qO- http://host.docker.internal:11434/api/tags
```

### OrbStack Troubleshooting

**Problem: n8n can't reach Ollama on Mac**
```bash
# Check Ollama is running
curl http://localhost:11434/api/tags

# If not, start it
ollama serve

# Verify container networking
docker compose exec n8n wget -qO- http://host.docker.internal:11434/api/tags
```

**Problem: Port already in use**
```bash
# Check what's on port 5678
lsof -i :5678

# If OrbStack's internal proxy conflicts, restart OrbStack
orb restart
```

**Problem: Containers stuck "starting"**
```bash
# OrbStack sometimes needs a reset after macOS sleep
orb restart
docker compose down && docker compose up -d
```

**Problem: Slow disk I/O**
OrbStack uses native macOS virt — should be fast. If slow, check:
```bash
orbctl doctor               # OrbStack health check
```
Make sure no other virtualization (Docker Desktop, Parallels) is running.

### OrbStack vs Docker Desktop

| Feature | OrbStack | Docker Desktop |
|---|---|---|
| RAM usage (idle) | ~200 MB | ~600-800 MB |
| File I/O | Native macOS virt | osxfs (slower) |
| Rosetta x86 emulation | Built-in | Optional |
| Linux machines | `orb` / `orbctl` | None |
| Price | Free for personal | Free / $9+/mo |

---

## Workflow Descriptions

| Workflow | Trigger | Purpose |
|---|---|---|
| **LLM Router** | Sub-workflow call | Routes tasks to optimal LLM with fallback cascade |
| **Master Meta Enquiry Agent** | Messenger Webhook | Triages messages, generates AI replies, queues for human approval |
| **Content Publisher Agent** | Schedule / Manual | Optimizes and publishes content to Facebook & Instagram |
| **Ads Optimizer Agent** | Schedule (daily) | Pulls ad insights, suggests optimizations with human approval |
| **Squarespace SEO Agent** | Schedule (weekly) | Audits Squarespace pages for SEO, geo/local improvements |

---

## LLM Router: How It Routes

The LLM Router sub-workflow selects the best provider by `task_type`:

| Task Type | Primary Provider | Fallback | Why |
|---|---|---|---|
| `routine` | Ollama (local) | SiliconFlow Qwen | Free and fast for simple replies |
| `quick` | SiliconFlow Qwen (7B) | Grok (xAI) | Sub-second, $0.0007/1K tokens |
| `analysis` | SiliconFlow DeepSeek-V3 | Anthropic Claude | Strong reasoning at 1/10th cost |
| `complex` | Anthropic Claude 3.5 | Grok (xAI) | Best reasoning quality |
| `general` (default) | Grok (xAI) | — | Always available, OpenAI-compatible |

> **Fallback cascade**: If primary fails (timeout, auth error, rate limit), the router automatically tries the fallback provider. All nodes use `continueOnFail: true` and 3 retries.

---

## Environment Variables

Key variables from `.env`:

| Variable | Required | Description |
|---|---|---|
| `CLIENT_ID` | Yes | Client identifier for logging isolation |
| `BRAND_VOICE` | Yes | AI prompt prefix for tone consistency |
| `N8N_ENCRYPTION_KEY` | Yes | Credential encryption (generate with `openssl rand -hex 16`) |
| `N8N_VERSION` | Prod | Pin version (e.g., `1.91.0`) for stability |
| `N8N_HOST` | Yes | Domain for webhooks/URLs |
| `COMPOSE_PROJECT_NAME` | Prod | Isolate stacks per client |
| `META_PAGE_ACCESS_TOKEN` | Meta | Facebook Page token |
| `META_AD_ACCOUNT_ID` | Ads | Meta Ad Account ID |
| `SQUARESPACE_API_KEY` | SEO | Squarespace API key |
| `OLLAMA_BASE_URL` | LLM | Local or cloud Ollama endpoint |
| `SILICONFLOW_API_KEY` | LLM | SiliconFlow API key |
| `ANTHROPIC_API_KEY` | LLM | Anthropic Claude API key |
| `GROK_API_KEY` | LLM | xAI Grok API key |
| `SERVER_IP` | VPS | Server IP for logging |
| `DOMAIN` | VPS | Domain name |

See `.env.example` for the full list.

---

## Observability

- **Execution Logs**: All workflows log to Google Sheets (`LOG_SPREADSHEET_ID` / `LOG_SHEET_NAME`)
- **n8n GUI**: Built-in execution history at `https://YOUR_DOMAIN/executions`
- **Docker Healthchecks**: All 4 services have health checks — `docker compose ps`
- **Error Handling**: HTTP calls include 3 retries + fallback cascade
- **Hostinger VPS**: Monitor CPU/RAM via hPanel or `hapi vps vm metrics`

---

## Multi-Client Deployment

```bash
git clone git@github.com:Smith-Gray-Pty-Ltd/n8n-smb-agent-template.git client-acme
cd client-acme
cp .env.example .env
# Edit .env with acme-specific values
docker compose -p acme up -d
```

Each instance is fully isolated by `COMPOSE_PROJECT_NAME`:
- Separate named volumes (`acme_postgres_data`, `acme_redis_data`, `acme_n8n_data`)
- Separate network (`acme_net`)
- Client-tagged execution logs
- Independent `BRAND_VOICE`

---

## Webhook Configuration

### Meta Messenger Webhook

Webhook URL: `https://YOUR_DOMAIN/webhook/meta-messenger-webhook-YOUR_CLIENT_ID`

Where `YOUR_CLIENT_ID` matches `CLIENT_ID` in `.env`.

### Human Approval Webhooks

| Workflow | Webhook URL Pattern |
|---|---|
| Meta Enquiry | `/webhook-wait/human-approval-{SENDER_ID}` |
| Content Publisher | `/webhook-wait/content-approval-{DATE}` |
| Ads Optimizer | `/webhook-wait/ads-approval-{DATE}` |
| SEO Agent | `/webhook-wait/seo-approval-{WEEK}` |

> **Important**: Webhook workflows **must be activated** before they can receive requests.

---

## Security

- **Basic Auth**: Enabled by default — change credentials immediately
- **Encryption**: All credentials encrypted with `N8N_ENCRYPTION_KEY`
- **No hard-coded secrets**: Everything is an environment variable
- **Human-in-the-loop**: Ads, publishing, and SEO require manual approval
- **Queue mode**: Executions isolated with Redis-backed queue
- **HTTPS**: Caddy or nginx reverse proxy in production
- **Firewall**: UFW allows only 22/80/443
- **Container names**: Predictable `container_name` for easier monitoring/logging

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

**Always back up before upgrading:**

```bash
docker compose exec postgres pg_dump -U n8n n8n > backup-$(date +%Y%m%d).sql
```

n8n auto-migrates the database on startup — no manual migration needed.

---

## CI/CD

A GitHub Actions workflow (`.github/workflows/validate.yml`) runs on every push/PR:
- Validates all workflow JSONs are parseable
- Checks `.env.example` has required keys
- Lints `docker-compose.yml` structure and restart policies

---

## Files

```
├── .github/
│   └── workflows/
│       └── validate.yml                # CI: JSON validation + env check
├── docker-compose.yml                  # 4-service stack (n8n, worker, Postgres, Redis)
├── .env.example                        # All configurable environment variables
├── .gitignore
├── LICENSE                             # MIT
├── README.md                           # This file
├── HOSTINGER-DEPLOY.md                 # Full Hostinger VPS step-by-step
├── deploy-hostinger.sh                 # One-command deploy script
├── update-workflows.sh                 # Workflow import CLI tool
├── credentials/
│   └── template-credentials.md         # Meta, Squarespace, LLM, Sheets setup
└── workflows/
    ├── llm-router-subworkflow.json     # v2: 5-provider router with fallback cascade
    ├── master-meta-enquiry-agent.json  # Messenger webhook → triage → AI → approval
    ├── content-publisher-agent.json    # Schedule → analyze → publish FB + IG
    ├── ads-optimizer-agent.json        # Daily insights → AI recs → human approval
    └── squarespace-seo-agent.json      # Weekly audit → AI SEO → approval → apply
```
