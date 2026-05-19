#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# update-workflows.sh
# Helps import workflow JSONs into a running n8n instance.
# Requires: curl, jq (brew install jq)
#
# Usage:
#   ./update-workflows.sh
#   ./update-workflows.sh --host https://n8n.example.com --user admin --pass secret
#   ./update-workflows.sh --import-all
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOWS_DIR="$SCRIPT_DIR/workflows"

# ─── Config ─────────────────────────────────────────────────
N8N_HOST="${N8N_HOST:-localhost}"
N8N_PORT="${N8N_PORT:-5678}"
N8N_PROTOCOL="${N8N_PROTOCOL:-http}"
N8N_USER="${N8N_BASIC_AUTH_USER:-admin}"
N8N_PASS="${N8N_BASIC_AUTH_PASSWORD:-changeme}"
IMPORT_ALL=false

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) N8N_HOST="$2"; shift 2 ;;
    --port) N8N_PORT="$2"; shift 2 ;;
    --user) N8N_USER="$2"; shift 2 ;;
    --pass) N8N_PASS="$2"; shift 2 ;;
    --import-all) IMPORT_ALL=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

BASE_URL="${N8N_PROTOCOL}://${N8N_HOST}:${N8N_PORT}"
AUTH_HEADER="-u ${N8N_USER}:${N8N_PASS}"

# ─── Helpers ────────────────────────────────────────────────

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
err()  { echo "[$(date '+%H:%M:%S')] ERROR: $*" >&2; }
json_escape() {
  # Escape file content for JSON embedding
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' < "$1"
}

check_n8n() {
  if ! curl -s -o /dev/null -w "%{http_code}" ${AUTH_HEADER:-} "$BASE_URL/healthz" | grep -q "200"; then
    err "n8n is not reachable at $BASE_URL"
    err "Make sure n8n is running: docker compose up -d"
    err "Or specify host: $0 --host your-domain.com --user admin --pass secret"
    exit 1
  fi
  log "n8n is reachable at $BASE_URL"
}

# ─── Import workflow ────────────────────────────────────────

import_workflow() {
  local name="$1"
  local file="$2"

  log "Importing: $name ..."

  # Create the workflow via POST
  local response
  response=$(curl -s -X POST ${AUTH_HEADER:-} \
    -H "Content-Type: application/json" \
    -d "@$file" \
    "$BASE_URL/rest/workflows" 2>&1)

  local wf_id
  wf_id=$(echo "$response" | jq -r '.id // empty' 2>/dev/null)

  if [[ -n "$wf_id" && "$wf_id" != "null" ]]; then
    log "  Created: $name (ID: $wf_id)"

    # Activate it
    curl -s -X POST ${AUTH_HEADER:-} \
      -H "Content-Type: application/json" \
      "$BASE_URL/rest/workflows/$wf_id/activate" > /dev/null 2>&1
    log "  Activated: $name"

    echo "$wf_id"
  else
    local err_msg
    err_msg=$(echo "$response" | jq -r '.message // "Unknown error"' 2>/dev/null)
    err "  Failed to import $name: $err_msg"
    return 1
  fi
}

# ─── Main ──────────────────────────────────────────────────

main() {
  log "============================================"
  log "n8n Workflow Import Tool"
  log "Target: $BASE_URL"
  log "============================================"

  check_n8n

  if [[ ! -d "$WORKFLOWS_DIR" ]]; then
    err "Workflows directory not found: $WORKFLOWS_DIR"
    exit 1
  fi

  # Step 1: Import LLM Router first (other workflows depend on it)
  log ""
  log "Step 1: Import LLM Router (sub-workflow dependency)"
  log "----------------------------------------"
  local llm_id
  llm_id=$(import_workflow "LLM Router" "$WORKFLOWS_DIR/llm-router-subworkflow.json")

  if [[ -z "$llm_id" ]]; then
    err "LLM Router import failed. Fix the issue before proceeding."
    err "You can import it manually via n8n UI."
    exit 1
  fi

  log "  LLM Router ID: $llm_id"
  log "  Update PLACEHOLDER_LLM_ROUTER_WORKFLOW_ID in other workflows to: $llm_id"

  # Step 2: Import remaining workflows
  log ""
  log "Step 2: Import remaining workflows"
  log "----------------------------------------"
  local files=(
    "meta-enquiry:master-meta-enquiry-agent.json"
    "content-publisher:content-publisher-agent.json"
    "ads-optimizer:ads-optimizer-agent.json"
    "squarespace-seo:squarespace-seo-agent.json"
  )

  for entry in "${files[@]}"; do
    local label="${entry%%:*}"
    local fname="${entry##*:}"
    import_workflow "$label" "$WORKFLOWS_DIR/$fname" || true
  done

  # Step 3: Summary
  log ""
  log "============================================"
  log "Import Complete"
  log "============================================"
  log ""
  log "Next Steps:"
  log "  1. Open $BASE_URL in your browser"
  log "  2. Go to Workflows and verify all 5 workflows are active"
  log "  3. Update the LLM Router Workflow ID in each parent workflow:"
  log "     - Open each parent workflow"
  log "     - Find the 'Call LLM Router' / 'Execute Workflow' node"
  log "     - Set it to the LLM Router sub-workflow (ID: $llm_id)"
  log "  4. Set up credentials (Settings → Credentials)"
  log "  5. Go to https://developers.facebook.com to set up Meta webhooks"
  log ""
  log "Done!"
}

main
