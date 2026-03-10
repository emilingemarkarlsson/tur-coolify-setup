#!/usr/bin/env bash
# Daglig påminnelse till Slack med länk till LiteLLM Usage-sidan – så du kan kolla kostnadsläget.
# Ingen API-anrop; bara ett kort meddelande + länk. Fungerar även när /global/spend/report ger 503.
#
# Miljö eller fil: ~/.litellm-daily-spend-urls eller SLACK_WEBHOOK_URL + LITELLM_UI_URL
#   SLACK_WEBHOOK_URL  – Incoming Webhook för Slack
#   LITELLM_UI_URL     – Länk till LiteLLM Usage (t.ex. https://litellm-xxx.sslip.io/ui/?page=new_usage)
#   Om LITELLM_UI_URL saknas används LITELLM_BASE_URL + /ui/?page=new_usage
#
# Cron (t.ex. 08:00): 0 8 * * * /usr/local/bin/litellm-daily-spend-slack.sh

set -euo pipefail

# Load config from env or file
if [[ -z "${SLACK_WEBHOOK_URL:-}" ]]; then
  for f in "${HOME:-}/.litellm-daily-spend-urls" /etc/litellm-daily-spend-urls; do
    if [[ -f "$f" ]]; then
      set -a
      # shellcheck source=/dev/null
      source "$f" 2>/dev/null || true
      set +a
      break
    fi
  done
fi

if [[ -z "${SLACK_WEBHOOK_URL:-}" ]]; then
  echo "SLACK_WEBHOOK_URL not set. Set env or create ~/.litellm-daily-spend-urls" >&2
  exit 1
fi

# Build Usage link: explicit LITELLM_UI_URL or from LITELLM_BASE_URL
if [[ -n "${LITELLM_UI_URL:-}" ]]; then
  USAGE_LINK="${LITELLM_UI_URL}"
else
  BASE="${LITELLM_BASE_URL:-http://litellm-kkswc8gokk84c0o8oo84w44w.46.62.206.47.sslip.io}"
  BASE="${BASE%/}"
  USAGE_LINK="${BASE}/ui"
fi

export LITELLM_USAGE_LINK="$USAGE_LINK"
PAYLOAD=$(python3 -c '
import json, os
link = os.environ.get("LITELLM_USAGE_LINK", "")
msg = "💰 *LiteLLM – kolla kostnadsläget*\n\nKlicka här för att se spend, requests och daily chart:\n" + link
print(json.dumps({"text": msg}))
' 2>/dev/null) || PAYLOAD=""
if [[ -z "$PAYLOAD" ]]; then
  PAYLOAD="{\"text\": \"💰 *LiteLLM – kolla kostnadsläget*\\n\\n$USAGE_LINK\"}"
fi

curl -sS -X POST -H 'Content-type: application/json' --data "$PAYLOAD" "$SLACK_WEBHOOK_URL" >/dev/null || true
