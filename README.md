# n8n SMB Agent Template

[![n8n Version](https://img.shields.io/badge/n8n-latest-blue?logo=n8n)](https://hub.docker.com/r/n8nio/n8n)
[![Docker](https://img.shields.io/badge/docker-compose-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![License](https://img.shields.io/badge/license-MIT-green)](./LICENSE)
[![CI](https://img.shields.io/badge/CI-validate.yml-passing-brightgreen)](.github/workflows/validate.yml)

Production-ready, multi-client n8n deployment for AI-driven Meta (Facebook/Instagram), Squarespace SEO, and multi-LLM routing. Deploy locally with OrbStack in under 10 minutes, or to Hostinger VPS in under 30.

---

## Changelog

| Date | Version | Changes |
|---|---|---|
| 2026-05-19 | 2.1.0 | Resource limits, Caddy example alongside Traefik, auto-patch LLM Router placeholder, GitHub badges |
| 2026-05-19 | 2.0.0 | LLM Router v2 (Anthropic endpoint fix, fallback cascade); OrbStack + Hostinger guides; `deploy-hostinger.sh` |
| 2026-05-19 | 1.0.0 | Initial release — 5 workflows, multi-LLM router, queue-mode docker compose |

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
| **Local Dev (macOS)** | [OrbStack](https://orbstack.dev) | Lightweight Docker — 2-4x less RAM than Docker Desktop |
| **Production VPS** | [Hostinger VPS](https://hostinger.com/vps) | Affordable KVM VPS, AU/SG/US data centers |
| **Alternative VPS** | Ubuntu 22.04+ | Hetzner, DigitalOcean, Linode, Vultr |

---

## One-Command Deploy (Hostinger VPS)

```bash
curl -fsSL https://get.docker.com | sh && \
git clone https://github.com/Smith-Gray-Pty-Ltd/n8n-smb-agent-template.git /opt/n8n-smb && \
cd /opt/n8n-smb && cp .env.example .env && \
echo "EDIT .env NOW: nano .env" && ./deploy-hostinger.sh
```

Edit `.env` with your domain/credentials, then `./deploy-hostinger.sh` again. Full guide: **[HOSTINGER-DEPLOY.md](HOSTINGER-DEPLOY.md)**.

---

## Quick Start: Local Development (OrbStack)

### Prerequisites

- [OrbStack](https://orbstack.dev) installed (`brew install orbstack`)
- Git
- (Optional) [Ollama](https://ollama.com) for local LLM

### 1. Clone & Configure

```bash
git clone git@github.com:Smith-Gray-Pty-Ltd/n8n-smb-agent-template.git client-name
cd client-name
cp .env.example .env
```

Set in `.env`:
- `N8N_ENCRYPTION_KEY` — `openssl rand -hex 16`
- `N8N_HOST=localhost`, `N8N_PROTOCOL=http`
- At least one LLM provider

### 2. Start & Deploy

```bash
open -a OrbStack          # or: orb start
docker compose up -d      # wait ~60s for services to be healthy
docker compose ps         # verify all 4 services are "healthy"
```

n8n is now at **http://localhost:5678**.

### 3. Import Workflows

```bash
./update-workflows.sh
```

This imports all 5 workflows and **auto-patches** the LLM Router dependency in parent workflows.

### 4. Set Up Credentials & Activate

Follow `credentials/template-credentials.md`.

---

## OrbStack-Specific Tips

See the full **[OrbStack Troubleshooting](#orbstack-troubleshooting)** section below.

| Tip | Command |
|---|---|
| Verify Ollama from container | `docker compose exec n8n wget -qO- http://host.docker.internal:11434/api/tags` |
| Check what's on port 5678 | `lsof -i :5678` |
| Full health check | `orbctl doctor` |
| Restart after macOS sleep | `orb restart && docker compose down && docker compose up -d` |

---

## Workflow Descriptions

| Workflow | Trigger | Purpose |
|---|---|---|
| **LLM Router** | Sub-workflow call | Multi-provider routing with automatic fallback cascade |
| **Meta Enquiry Agent** | Messenger Webhook | Triage → AI reply → human approval → send |
| **Content Publisher** | Schedule / Manual | Analyze past posts → generate content → publish FB + IG |
| **Ads Optimizer** | Schedule (daily) | Fetch ad insights → AI optimization → human approval |
| **Squarespace SEO Agent** | Schedule (weekly) | Page audit → AI SEO recommendations → approval → apply |

> **LLM Router dependency**: The 4 agent workflows use `Execute Workflow` to call the LLM Router sub-workflow. `update-workflows.sh` auto-sets this dependency.

---

## LLM Router Routing Table

| Task Type | Primary Provider | Fallback | Cost/1K tokens | Ideal For |
|---|---|---|---|---|
| `routine` | Ollama (local) | SiliconFlow Qwen | $0 | Simple replies, chat |
| `quick` | SiliconFlow Qwen 7B | Grok | ~$0.0007 | Fast, cheap responses |
| `analysis` | SiliconFlow DeepSeek-V3 | Anthropic Claude | ~$0.0014 | SEO, ads analysis |
| `complex` | Anthropic Claude 3.5 | Grok | ~$0.015 | Strategy, nuanced writing |
| `general` | Grok (xAI) | — | ~$0.003 | Always-available fallback |

Failed providers trigger automatic fallback. All nodes use `continueOnFail: true` with 3 retries.

---

## Environment Variables

Key variables from `.env`:

| Variable | Required | Description |
|---|---|---|
| `CLIENT_ID` | Yes | Unique client identifier |
| `BRAND_VOICE` | Yes | AI tone/style prefix |
| `N8N_ENCRYPTION_KEY` | Yes | Credential encryption key |
| `N8N_HOST` | Yes | Domain for webhooks |
| `N8N_VERSION` | Prod | Pin version (e.g., `1.91.0`) |
| `COMPOSE_PROJECT_NAME` | Prod | Multi-client stack isolation |
| `META_PAGE_ACCESS_TOKEN` | Meta | Facebook Page token |
| `META_AD_ACCOUNT_ID` | Ads | Meta Ad Account ID |
| `SQUARESPACE_API_KEY` | SEO | Squarespace API key |
| `OLLAMA_BASE_URL` | LLM | Ollama endpoint |
| `SILICONFLOW_API_KEY` | LLM | SiliconFlow key |
| `ANTHROPIC_API_KEY` | LLM | Claude key |
| `GROK_API_KEY` | LLM | xAI Grok key |
| `SERVER_IP` | VPS | Server IP |
| `DOMAIN` | VPS | Domain name |

Full list: `.env.example`.

---

## Multi-Client Deployment

```bash
git clone git@github.com:Smith-Gray-Pty-Ltd/n8n-smb-agent-template.git client-acme
cd client-acme
cp .env.example .env
# Edit .env with acme values
docker compose -p acme up -d
```

Each client gets isolated volumes, network, and containers via `COMPOSE_PROJECT_NAME`.

---

## Webhooks

### Meta Messenger
`https://YOUR_DOMAIN/webhook/meta-messenger-webhook-YOUR_CLIENT_ID`

### Human Approval (per workflow)
| Workflow | Webhook Path |
|---|---|
| Meta Enquiry | `/webhook-wait/human-approval-{SENDER_ID}` |
| Content Publisher | `/webhook-wait/content-approval-{DATE}` |
| Ads Optimizer | `/webhook-wait/ads-approval-{DATE}` |
| SEO Agent | `/webhook-wait/seo-approval-{WEEK}` |

> Workflows **must be activated** before webhooks receive requests.

---

## Security

- **Basic Auth** enabled — change default credentials immediately
- **Credentials encrypted** with `N8N_ENCRYPTION_KEY`
- **No hard-coded secrets** — everything via environment variables
- **Human-in-the-loop** on ads, publishing, and SEO workflows
- **Queue mode** isolates executions via Redis
- **HTTPS** via Caddy/nginx/Traefik in production
- **UFW firewall** — allow only 22/80/443

---

## Upgrading

```bash
docker compose pull
docker compose up -d
```

**Always back up first:**
```bash
docker compose exec postgres pg_dump -U n8n n8n > backup-$(date +%Y%m%d).sql
```

n8n auto-migrates the database — no manual steps.

---

## Observability

- **Google Sheets**: All workflows log to `LOG_SPREADSHEET_ID`
- **n8n UI**: Built-in execution history
- **Healthchecks**: `docker compose ps` — all 4 services report "healthy"
- **Retries**: 3 attempts on all HTTP calls, automatic fallback cascade
- **Hostinger**: Monitor via hPanel or `hapi vps vm metrics`

---

## CI/CD

GitHub Actions (`.github/workflows/validate.yml`) runs on every push:
- Validates all workflow JSONs
- Checks `.env.example` required keys
- Lints `docker-compose.yml` structure and restart policies

---

## OrbStack Troubleshooting

**n8n can't reach Ollama**
```bash
curl http://localhost:11434/api/tags        # Is Ollama running?
ollama serve                                  # Start it
docker compose exec n8n wget -qO- http://host.docker.internal:11434/api/tags
```

**Port 5678 already in use**
```bash
lsof -i :5678
orb restart
```

**Containers stuck starting after macOS sleep**
```bash
orb restart
docker compose down && docker compose up -d
```

**Slow disk I/O**
```bash
orbctl doctor
# Close Docker Desktop, Parallels, or other hypervisors
```

---

## Template Updates

To pull the latest template improvements into an existing client deployment:

```bash
cd client-name
git fetch origin main
git diff main origin/main      # review changes
git merge origin/main          # apply updates
docker compose pull && docker compose up -d
```

Your `.env`, `n8n_data`, and `postgres_data` volumes are unaffected by git merges.

---

## Contributing

1. Fork the repo
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Make changes; ensure `workflows/*.json` files remain valid JSON
4. Run `docker compose up -d` locally to verify
5. Open a PR against `main`

CI will validate JSONs, `.env.example`, and `docker-compose.yml` automatically.

---

## Files

```
├── .github/workflows/validate.yml       # CI checks
├── docker-compose.yml                   # 4-service stack
├── .env.example                         # All config vars
├── .gitignore
├── LICENSE                              # MIT
├── README.md
├── HOSTINGER-DEPLOY.md                  # Hostinger VPS step-by-step
├── deploy-hostinger.sh                  # Auto-deploy script
├── update-workflows.sh                  # Import + auto-patch script
├── credentials/
│   └── template-credentials.md          # API key setup guide
└── workflows/
    ├── llm-router-subworkflow.json      # v2: 5-provider fallback router
    ├── master-meta-enquiry-agent.json   # Messenger webhook agent
    ├── content-publisher-agent.json     # FB + IG publishing agent
    ├── ads-optimizer-agent.json         # Meta Ads optimization agent
    └── squarespace-seo-agent.json       # Squarespace SEO agent
```
