# Deploy to Hostinger VPS

Step-by-step guide to deploy the n8n SMB Agent Template on a Hostinger VPS.

---

## Prerequisites

- A Hostinger VPS (VPS KVM 2 or higher — see specs below)
- A domain pointed to your VPS IP (via Hostinger DNS or any registrar)
- SSH access to the VPS
- GitHub access to clone this repo

---

## Recommended VPS Specs

| Tier | vCPU | RAM | Suitable For |
|---|---|---|---|
| **VPS KVM 2** (minimum) | 2 | 8 GB | 1-2 clients, basic workflows |
| **VPS KVM 4** (recommended) | 4 | 16 GB | 3-5 clients, AI agents, multiple LLM providers |
| **VPS KVM 8** (growth) | 8 | 32 GB | 5+ clients, local Ollama, heavy AI workloads |

Running an LLM locally on the VPS (Ollama) requires significant RAM. If using cloud LLMs (SiliconFlow, Claude, Grok), the minimum VPS is sufficient.

---

## Step 1: Provision Your VPS

1. Log in to [hPanel](https://hpanel.hostinger.com)
2. Go to **VPS → Manage**
3. Choose an OS template: **Ubuntu 24.04 LTS**
4. If you haven't already, add your SSH key under **VPS → SSH Keys**
5. Note your VPS IP address

---

## Step 2: Initial Server Setup

SSH into your VPS:

```bash
ssh root@YOUR_VPS_IP
```

### Update & Install Docker

```bash
apt update && apt upgrade -y
apt install -y curl wget git ufw

# Install Docker
curl -fsSL https://get.docker.com | sh

# Start Docker & enable on boot
systemctl enable docker
systemctl start docker

# Add your user to docker group (optional — use a non-root user for security)
# useradd -m -s /bin/bash deploy
# usermod -aG docker deploy
```

---

## Step 3: Firewall Configuration

```bash
# Allow SSH, HTTP, HTTPS
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp

# Allow n8n port only if NOT using a reverse proxy
# ufw allow 5678/tcp

ufw enable
ufw status verbose
```

---

## Step 4: Point Your Domain

1. Go to your DNS provider (Hostinger DNS or Cloudflare etc.)
2. Create an **A record**:
   - Name: `n8n` (or your preferred subdomain)
   - Value: `YOUR_VPS_IP`
   - TTL: 3600
3. Wait for DNS propagation (usually < 5 minutes, up to 24 hours)

Verify:

```bash
dig n8n.yourdomain.com +short
```

---

## Step 5: Clone & Configure

```bash
git clone https://github.com/Smith-Gray-Pty-Ltd/n8n-smb-agent-template.git /opt/n8n-smb
cd /opt/n8n-smb
cp .env.example .env
```

Edit `.env`:

```bash
nano .env
```

**Critical values to set:**

```bash
N8N_HOST=n8n.yourdomain.com
N8N_PROTOCOL=https
N8N_ENCRYPTION_KEY=$(openssl rand -hex 16)
N8N_BASIC_AUTH_PASSWORD=your-strong-password
CLIENT_ID=your-client-id
CLIENT_NAME="Your Client Name"
DB_PASSWORD=$(openssl rand -hex 16)
REDIS_PASSWORD=$(openssl rand -hex 8)
```

For production, also pin the n8n version:

```bash
N8N_VERSION=1.91.0  # Check https://hub.docker.com/r/n8nio/n8n/tags for latest
```

---

## Step 6: Deploy with Docker Compose

```bash
docker compose up -d
```

Check all services are healthy:

```bash
docker compose ps
docker compose logs n8n | tail -20
```

You should see `n8n` running and the health check passing.

---

## Step 7: Set Up HTTPS (Reverse Proxy)

### Option A: Caddy (Simplest)

```bash
apt install -y caddy

# Create a simple Caddyfile
cat > /etc/caddy/Caddyfile << 'CADDYEOF'
n8n.yourdomain.com {
    reverse_proxy localhost:5678
}
CADDYEOF

systemctl restart caddy
```

Caddy auto-obtains and renews Let's Encrypt certificates.

### Option B: nginx + Certbot

```bash
apt install -y nginx certbot python3-certbot-nginx

# Create nginx config
cat > /etc/nginx/sites-available/n8n << 'NGXEOF'
server {
    listen 80;
    server_name n8n.yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
        proxy_read_timeout 86400s;
    }
}
NGXEOF

ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
certbot --nginx -d n8n.yourdomain.com
```

---

## Step 8: Import Workflows

```bash
chmod +x update-workflows.sh
./update-workflows.sh --host n8n.yourdomain.com
```

Or import manually via n8n UI at `https://n8n.yourdomain.com`.

**After import**, update the `PLACEHOLDER_LLM_ROUTER_WORKFLOW_ID` in each parent workflow to point to the actual LLM Router sub-workflow ID.

---

## Step 9: Set Up Meta Webhooks

In your Meta app (https://developers.facebook.com):
1. Go to **Messenger → Settings → Webhooks**
2. Callback URL: `https://n8n.yourdomain.com/webhook/meta-messenger-webhook-YOUR_CLIENT_ID`
3. Verify token: same as `META_WEBHOOK_VERIFY_TOKEN` in your `.env`
4. Subscribe to `messages` and `messaging_postbacks`

---

## Step 10: Configure Backups

### Database Backups

Add a cron job to back up Postgres daily:

```bash
crontab -e
```

Add:

```
0 3 * * * docker exec n8n-smb-postgres-1 pg_dump -U n8n n8n > /opt/backups/n8n-$(date +\%Y\%m\%d).sql
0 4 * * * find /opt/backups -name "n8n-*.sql" -mtime +7 -delete
```

Create the backup directory:

```bash
mkdir -p /opt/backups
```

### Volume Backups

```bash
# Backup all Docker volumes
docker run --rm \
  -v n8n-smb_postgres_data:/data \
  -v /opt/backups:/backup \
  alpine tar czf /backup/postgres-volume-$(date +%Y%m%d).tar.gz -C /data .

docker run --rm \
  -v n8n-smb_n8n_data:/data \
  -v /opt/backups:/backup \
  alpine tar czf /backup/n8n-volume-$(date +%Y%m%d).tar.gz -C /data .
```

---

## Step 11: Monitoring

### Check Container Health

```bash
docker compose ps
docker stats --no-stream
```

### View Logs

```bash
docker compose logs -f --tail=100 n8n
```

### VM Metrics via Hostinger

```bash
# Using the hapi CLI (if installed)
hapi vps vm metrics --virtual-machine-id YOUR_VM_ID --format json
```

Or check in hPanel under **VPS → Overview** for CPU, RAM, disk graphs.

---

## Upgrading n8n on Hostinger

```bash
cd /opt/n8n-smb

# Pull latest code
git pull origin main

# Backup database
docker compose exec postgres pg_dump -U n8n n8n > /opt/backups/pre-upgrade-$(date +%Y%m%d%H%M).sql

# Pull new images and restart
docker compose pull
docker compose up -d

# Watch logs during startup
docker compose logs -f n8n
```

n8n auto-migrates the database on startup. If something goes wrong, restore from backup.

---

## Troubleshooting

### n8n won't start
```bash
docker compose logs n8n
```
Common issues: wrong `N8N_ENCRYPTION_KEY`, Postgres not ready, port conflicts.

### Webhooks not receiving
Check: reverse proxy forwarding, firewall allowing 443, Meta webhook configured correctly, `WEBHOOK_URL` matching your domain.

### Workers not picking up jobs
```bash
docker compose logs n8n-worker
```
Ensure Redis is healthy and `REDIS_PASSWORD` matches.

### Out of memory
Reduce worker count or scale up VPS. Cloud LLMs use less RAM than local Ollama.
