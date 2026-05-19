#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# update-workflows.sh
# Import n8n workflow JSONs into a running n8n instance.
#
# Requirements: curl, jq
#   brew install jq   (macOS)
#   apt install jq    (Ubuntu)
#
# Usage:
#   ./update-workflows.sh
#   ./update-workflows.sh --host n8n.example.com --user admin --pass secret
#   ./update-workflows.sh --source .env              (read vars from .env)
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOWS_DIR="$SCRIPT_DIR/workflows"

# ─── Config (can be overridden via args or .env) ────────────
N8N_HOST="${N8N_HOST:-localhost}"
N8N_PORT="${N8N_PORT:-5678}"
N8N_PROTOCOL="${N8N_PROTOCOL:-http}"
N8N_USER="${N8N_BASIC_AUTH_USER:-admin}"
N8N_PASS="${N8N_BASIC_AUTH_PASSWORD:-changeme}"

# ─── Parse args ────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)    N8N_HOST="$2";    shift 2 ;;
    --port)    N8N_PORT="$2";    shift 2 ;;
    --user)    N8N_USER="$2";    shift 2 ;;
    --pass)    N8N_PASS="$2";    shift 2 ;;
    --source)  source "$2";      shift 2 ;;  # read vars from a file
    --help|-h)
      echo "Usage: $0 [options]"
      echo ""
      echo "  --host HOST      n8n host (default: localhost)"
      echo "  --port PORT      n8n port (default: 5678)"
      echo "  --user USER      basic auth user (default: admin)"
      echo "  --pass PASS      basic auth password"
      echo "  --source FILE    read config from file (e.g., .env)"
      echo ""
      echo "Examples:"
      echo "  $0 --source .env"
      echo "  $0 --host n8n.example.com --user admin --pass secret"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

BASE_URL="${N8N_PROTOCOL}://${N8N_HOST}:${N8N_PORT}"
AUTH_HEADER="-u ${N8N_USER}:${N8N_PASS}"

# ─── Helpers ────────────────────────────────────────────────
log()  { echo "[$(date '+%H:%M:%S')] $*"; }
err()  { echo "[$(date '+%H:%M:%S')] ERROR: $*" >&2; }

check_n8n() {
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" ${AUTH_HEADER:-} "$BASE_URL/healthz" 2>/dev/null || echo "000")
  if [[ "$http_code" != "200" ]]; then
    err "n8n is not reachable at $BASE_URL (HTTP $http_code)"
    err "Make sure: docker compose up -d && sleep 10"
    err "Or specify host: $0 --host your-domain.com --user admin --pass secret"
    exit 1
  fi
  log "n8n reachable at $BASE_URL (HTTP $http_code)"
}

import_workflow() {
  local name="$1"
  local file="$2"

  log "Importing: $name ..."

  local response
  response=$(curl -s -X POST ${AUTH_HEADER:-} \
    -H "Content-Type: application/json" \
    -d "@$file" \
    "$BASE_URL/rest/workflows" 2>&1)

  local wf_id
  wf_id=$(echo "$response" | jq -r '.id // empty' 2>/dev/null)

  if [[ -n "$wf_id" && "$wf_id" != "null" ]]; then
    log "  Created: $name (ID: $wf_id)"

    # Activate
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

# ─── Replace placeholder in workflow ────────────────────────
replace_placeholder() {
  local wf_id="$1"
  local llm_router_id="$2"
  local wf_name="$3"

  log "  Patching $wf_name: replacing LLM Router placeholder with $llm_router_id ..."

  # Fetch current workflow
  local wf_json
  wf_json=$(curl -s ${AUTH_HEADER:-} "$BASE_URL/rest/workflows/$wf_id")

  if [[ -z "$wf_json" || "$wf_json" == "null" ]]; then
    err "  Could not fetch workflow $wf_id for patching"
    return 1
  fi

  # Replace the placeholder string in the JSON
  local patched_json
  patched_json=$(echo "$wf_json" | sed "s/PLACEHOLDER_LLM_ROUTER_WORKFLOW_ID/$llm_router_id/g")

  # Update the workflow
  local update_response
  update_response=$(curl -s -X PUT ${AUTH_HEADER:-} \
    -H "Content-Type: application/json" \
    -d "$patched_json" \
    "$BASE_URL/rest/workflows/$wf_id" 2>&1)

  local updated_id
  updated_id=$(echo "$update_response" | jq -r '.id // empty' 2>/dev/null)

  if [[ -n "$updated_id" && "$updated_id" != "null" ]]; then
    log "  Patched: $wf_name (LLM Router ID set to $llm_router_id)"

    # Re-activate after update
    curl -s -X POST ${AUTH_HEADER:-} \
      -H "Content-Type: application/json" \
      "$BASE_URL/rest/workflows/$wf_id/activate" > /dev/null 2>&1
    log "  Re-activated: $wf_name"
  else
    err "  Failed to patch $wf_name — you can update the ID manually in n8n UI"
    return 1
  fi
}

# ─── Main ──────────────────────────────────────────────────
main() {
  echo ""
  log "============================================"
  log "  n8n Workflow Import Tool"
  log "  Target: $BASE_URL"
  log "============================================"
  echo ""

  check_n8n

  if [[ ! -d "$WORKFLOWS_DIR" ]]; then
    err "Workflows directory not found: $WORKFLOWS_DIR"
    exit 1
  fi

  # Step 1 — Import LLM Router
  log "Step 1/2: Import LLM Router (sub-workflow dependency)"
  log "──────────────────────────────────────────────"
  local llm_id
  llm_id=$(import_workflow "LLM Router" "$WORKFLOWS_DIR/llm-router-subworkflow.json")

  if [[ -z "$llm_id" ]]; then
    err "LLM Router import failed. Cannot continue."
    err "You can import it manually via n8n UI → Import from File."
    exit 1
  fi
  log "  LLM Router ID: $llm_id"
  echo ""

  # Step 2 — Import remaining + auto-patch placeholder
  log "Step 2/2: Import other workflows & patch LLM Router dependency"
  log "──────────────────────────────────────────────"

  local PARENT_WORKFLOWS=(
    "Meta Enquiry:master-meta-enquiry-agent.json"
    "Content Publisher:content-publisher-agent.json"
    "Ads Optimizer:ads-optimizer-agent.json"
    "Squarespace SEO:squarespace-seo-agent.json"
  )

  local imported=0
  local patched=0

  for entry in "${PARENT_WORKFLOWS[@]}"; do
    local label="${entry%%:*}"
    local fname="${entry##*:}"

    local parent_id
    parent_id=$(import_workflow "$label" "$WORKFLOWS_DIR/$fname" || echo "")

    if [[ -n "$parent_id" ]]; then
      ((imported++))

      # Auto-patch the PLACEHOLDER_LLM_ROUTER_WORKFLOW_ID
      if replace_placeholder "$parent_id" "$llm_id" "$label"; then
        ((patched++))
      fi
    fi
  done

  # Summary
  echo ""
  log "============================================"
  log "  Import Summary"
  log "============================================"
  log "  Workflows imported:  $((imported + 1))  (1 router + $imported parent)"
  log "  Auto-patched:        $patched / $imported parent workflows"
  log "  LLM Router ID:       $llm_id"
  echo ""
  log "Next Steps:"
  log "  1. Open $BASE_URL and log in"
  log "  2. Verify all workflows appear under Workflows"
  log "  3. Open each parent workflow and confirm Call LLM Router uses ID: $llm_id"
  log "  4. Set up credentials in Settings → Credentials"
  log "  5. Configure Meta webhooks at https://developers.facebook.com"
  echo ""
  log "Done!"
  echo ""
}

main
