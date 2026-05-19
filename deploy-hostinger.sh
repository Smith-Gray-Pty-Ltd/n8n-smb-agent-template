#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# deploy-hostinger.sh
# Deploy n8n SMB Agent Template to a Hostinger VPS.
#
# Usage (run from repo root on your VPS):
#   chmod +x deploy-hostinger.sh
#   ./deploy-hostinger.sh
#
# Or deploy remotely via SSH:
#   ./deploy-hostinger.sh --ssh user@your-vps-ip --path /opt/n8n-smb
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_SSH=""
REMOTE_PATH=""
MODE="local"

# ─── Parse args ────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh) REMOTE_SSH="$2"; shift 2 ;;
    --path) REMOTE_PATH="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: $0 [--ssh user@host] [--path /remote/path]"
      echo ""
      echo "  Local deploy:   ./deploy-hostinger.sh"
      echo "  Remote deploy:  ./deploy-hostinger.sh --ssh root@1.2.3.4 --path /opt/n8n-smb"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -n "$REMOTE_SSH" ]]; then
  MODE="remote"
fi

# ─── Helpers ────────────────────────────────────────────────
log()  { echo "[$(date '+%H:%M:%S')] $*"; }
err()  { echo "[$(date '+%H:%M:%S')] ERROR: $*" >&2; exit 1; }

# ─── Remote Deploy ─────────────────────────────────────────
if [[ "$MODE" == "remote" ]]; then
  log "Deploying to $REMOTE_SSH:$REMOTE_PATH ..."

  # Sync repo to remote
  rsync -avz --exclude '.git' --exclude '.env' --exclude '*.log' \
    --exclude 'n8n_data' --exclude 'postgres_data' --exclude 'redis_data' \
    "$SCRIPT_DIR/" "$REMOTE_SSH:$REMOTE_PATH/"

  # Run remote commands
  ssh "$REMOTE_SSH" << EOSSH
    set -e
    cd "$REMOTE_PATH"

    log() { echo "[\$(date '+%H:%M:%S')] \$*"; }

    # Verify Docker
    if ! command -v docker &>/dev/null; then
      log "Installing Docker..."
      curl -fsSL https://get.docker.com | sh
      systemctl enable docker
      systemctl start docker
    fi

    # Check .env exists
    if [[ ! -f .env ]]; then
      log "WARNING: .env not found. Copy .env.example to .env and edit it."
      cp .env.example .env
      log "Created .env from .env.example — EDIT IT before deploying!"
      exit 1
    fi

    # Generate encryption key if still default
    if grep -q "change-me-to-a-random-32-char" .env; then
      log "Generating N8N_ENCRYPTION_KEY..."
      NEW_KEY=\$(openssl rand -hex 16)
      sed -i "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=\$NEW_KEY/" .env
      log "Encryption key generated: \$NEW_KEY"
    fi

    # Pull fresh images
    log "Pulling Docker images..."
    docker compose pull

    # Start services
    log "Starting services..."
    docker compose up -d

    # Wait for healthy
    log "Waiting for n8n to be ready..."
    for i in \$(seq 1 30); do
      if curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz 2>/dev/null | grep -q 200; then
        log "n8n is healthy!"
        break
      fi
      sleep 2
    done

    docker compose ps
    log "Deploy complete!"
EOSSH

# ─── Local Deploy ──────────────────────────────────────────
else
  log "Deploying locally..."

  if [[ ! -f .env ]]; then
    log "WARNING: .env not found. Copy .env.example to .env and edit it."
    cp .env.example .env
    log "Created .env from .env.example — EDIT IT, then re-run this script."
    exit 1
  fi

  # Generate encryption key if still default
  if grep -q "change-me-to-a-random-32-char" .env; then
    log "Generating N8N_ENCRYPTION_KEY..."
    NEW_KEY=$(openssl rand -hex 16)
    sed -i '' "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=$NEW_KEY/" .env
    log "Encryption key generated: $NEW_KEY"
  fi

  # Pull fresh images
  log "Pulling Docker images..."
  docker compose pull

  # Start services
  log "Starting services..."
  docker compose up -d

  # Wait for healthy
  log "Waiting for services to be healthy..."
  sleep 5
  docker compose ps

  log "n8n available at http://localhost:${N8N_PORT:-5678}"
  log "Deploy complete!"
fi
