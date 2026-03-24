#!/usr/bin/env bash
# Daglig påminnelse till Telegram med länk till LiteLLM Usage-sidan.
#
# Kräver: TELEGRAM_BOT_TOKEN och TELEGRAM_CHAT_ID (logs-kanalen)
# Cron (t.ex. 08:00): 0 8 * * * /usr/local/bin/telegram-daily-spend.sh

set -euo pipefail

TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:--1003767033253}"  # logs-kanalen

if [[ -z "$TOKEN" ]]; then
  for f in "${HOME:-}/.litellm-daily-spend-urls" /etc/litellm-daily-spend-urls; do
    if [[ -f "$f" ]]; then
      set -a; source "$f" 2>/dev/null || true; set +a; break
    fi
  done
  TOKEN="${TELEGRAM_BOT_TOKEN:-}"
fi

if [[ -z "$TOKEN" ]]; then
  echo "TELEGRAM_BOT_TOKEN not set." >&2; exit 1
fi

BASE="${LITELLM_BASE_URL:-http://litellm-kkswc8gokk84c0o8oo84w44w.46.62.206.47.sslip.io}"
USAGE_LINK="${LITELLM_UI_URL:-${BASE%/}/ui}"

python3 - "$TOKEN" "$CHAT_ID" "$USAGE_LINK" << 'PYEOF'
import json, sys, urllib.request
token, chat_id, link = sys.argv[1], sys.argv[2], sys.argv[3]
text = f"💰 <b>LiteLLM – kolla kostnadsläget</b>\n\nSe spend, requests och daily chart:\n{link}"
payload = json.dumps({"chat_id": chat_id, "text": text, "parse_mode": "HTML"}).encode()
req = urllib.request.Request(
    f"https://api.telegram.org/bot{token}/sendMessage",
    data=payload, headers={"Content-Type": "application/json"})
urllib.request.urlopen(req, timeout=10)
print("Telegram notification sent.")
PYEOF
