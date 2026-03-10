#!/usr/bin/env bash
# Skickar en SEO-draft till n8n "Store SEO draft" webhook så att den hamnar i Google Sheet.
# Då kan användaren klicka "Approve" i Slack och n8n Eik SEO Publisher publicerar från Sheet.
#
# Användning: store-seo-draft.sh <slug> "<keyword>" <path-to-draft.md>
# Kräver: curl. Webhook-URL: N8N_STORE_DRAFT_WEBHOOK_URL eller /data/.openclaw/n8n-store-draft-url

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <slug> \"<keyword>\" <path-to-draft.md>" >&2
  exit 1
fi

SLUG="$1"
KEYWORD="$2"
DRAFT_FILE="$3"

if [[ ! -f "$DRAFT_FILE" ]]; then
  echo "Draft file not found: $DRAFT_FILE" >&2
  exit 1
fi

# Webhook URL: env or file in container
if [[ -n "${N8N_STORE_DRAFT_WEBHOOK_URL:-}" ]]; then
  URL="$N8N_STORE_DRAFT_WEBHOOK_URL"
elif [[ -f /data/.openclaw/n8n-store-draft-url ]]; then
  URL=$(cat /data/.openclaw/n8n-store-draft-url | tr -d '\n')
else
  echo "N8N_STORE_DRAFT_WEBHOOK_URL not set and /data/.openclaw/n8n-store-draft-url not found." >&2
  exit 1
fi

CONTENT=$(cat "$DRAFT_FILE")

# Build JSON body safely (jq required for content with quotes/newlines)
if ! command -v jq &>/dev/null; then
  echo "jq is required to escape draft content. Install jq in the container or use N8N webhook from outside." >&2
  exit 1
fi
BODY=$(jq -n --arg slug "$SLUG" --arg keyword "$KEYWORD" --arg content "$CONTENT" '{ slug: $slug, keyword: $keyword, content: $content }')

HTTP_CODE=$(curl -s -o /tmp/store-draft-response.txt -w "%{http_code}" -X POST "$URL" \
  -H "Content-Type: application/json" \
  -d "$BODY")

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
  echo "Draft stored for slug=$SLUG (HTTP $HTTP_CODE)"
else
  echo "Store draft failed: HTTP $HTTP_CODE" >&2
  cat /tmp/store-draft-response.txt >&2
  exit 1
fi
