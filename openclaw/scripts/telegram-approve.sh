#!/usr/bin/env bash
# Skickar en approval-förfrågan till Telegram Approvals-kanalen med inline-knappar.
# Svaret hanteras av n8n-webhook → docker exec publish-draft.sh / kassera-draft.sh
#
# Användning:
#   telegram-approve.sh <slug> <titel> <sajt> <url>
#
# Exempel:
#   telegram-approve.sh "nhl-best-underlying-fla-2026-03-24" \
#     "Florida Panthers Lead the League in Goal Share" \
#     "thehockeybrain" \
#     "https://thehockeybrain.com/insights/nhl-best-underlying-fla-2026-03-24"

set -euo pipefail

SLUG="${1:-}"
TITLE="${2:-}"
SITE="${3:-}"
URL="${4:-}"

if [[ -z "$SLUG" || -z "$TITLE" || -z "$SITE" ]]; then
  echo "Usage: $0 <slug> <title> <site> [url]" >&2
  exit 1
fi

CONFIG="/data/.openclaw/telegram-config.json"
TOKEN=$(python3 -c "import json; d=json.load(open('${CONFIG}')); print(d['bot_token'])")
CHAT_ID=$(python3 -c "import json; d=json.load(open('${CONFIG}')); print(d['channels']['approvals'])")

MSG="🔔 <b>Ny artikel redo för publicering</b>

📌 <b>${TITLE}</b>
🌐 Sajt: <code>${SITE}</code>
🔗 ${URL:-Ingen URL ännu}
🏷 Slug: <code>${SLUG}</code>"

KEYBOARD=$(python3 -c "
import json
print(json.dumps({
    'inline_keyboard': [[
        {'text': '✅ Publicera', 'callback_data': 'approve:${SLUG}:${SITE}'},
        {'text': '❌ Kassera',   'callback_data': 'reject:${SLUG}:${SITE}'}
    ]]
}))
")

curl -s -o /dev/null -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json, sys
print(json.dumps({
    'chat_id': '${CHAT_ID}',
    'text': sys.argv[1],
    'parse_mode': 'HTML',
    'reply_markup': json.loads(sys.argv[2])
}))
" "$MSG" "$KEYBOARD")"

echo "Approval request sent for: ${SLUG}"
