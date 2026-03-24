#!/usr/bin/env bash
# Skickar ett meddelande till en Telegram-kanal via TurOpenClawBot.
#
# Användning:
#   telegram-notify.sh <kanal> <meddelande>
#
# Kanaler: thehockeybrain | thehockeyanalytics | logs | approvals
#
# Exempel:
#   telegram-notify.sh thehockeybrain "✅ Artikel publicerad: https://..."
#   telegram-notify.sh logs "❌ Fel i pipeline: ..."

set -euo pipefail

CHANNEL="${1:-}"
MESSAGE="${2:-}"

if [[ -z "$CHANNEL" || -z "$MESSAGE" ]]; then
  echo "Usage: $0 <channel> <message>" >&2
  exit 1
fi

CONFIG="/data/.openclaw/telegram-config.json"
if [[ ! -f "$CONFIG" ]]; then
  echo "Telegram config not found: $CONFIG" >&2
  exit 1
fi

TOKEN=$(python3 -c "import json; d=json.load(open('${CONFIG}')); print(d['bot_token'])")
CHAT_ID=$(python3 -c "import json,sys; d=json.load(open('${CONFIG}')); print(d['channels'].get('${CHANNEL}',''))")

if [[ -z "$CHAT_ID" ]]; then
  echo "Unknown channel: $CHANNEL. Valid: thehockeybrain, thehockeyanalytics, logs, approvals" >&2
  exit 1
fi

curl -s -o /dev/null -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json, sys
print(json.dumps({
    'chat_id': '${CHAT_ID}',
    'text': sys.argv[1],
    'parse_mode': 'HTML',
    'disable_web_page_preview': False
}))
" "$MESSAGE")"
