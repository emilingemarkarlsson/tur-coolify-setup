#!/usr/bin/env bash
# Schemalagd påminnelse till Telegram om att posta ny artikel.
# Cron (t.ex. mån 09:00): 0 9 * * 1 /usr/local/bin/telegram-seo-reminder.sh

set -euo pipefail

TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:--1003767033253}"  # logs-kanalen

if [[ -z "$TOKEN" ]]; then
  for f in /etc/litellm-daily-spend-urls "${HOME:-}/.litellm-daily-spend-urls"; do
    if [[ -f "$f" ]]; then
      set -a; source "$f" 2>/dev/null || true; set +a; break
    fi
  done
  TOKEN="${TELEGRAM_BOT_TOKEN:-}"
fi

if [[ -z "$TOKEN" ]]; then
  echo "TELEGRAM_BOT_TOKEN not set." >&2; exit 1
fi

python3 - "$TOKEN" "$CHAT_ID" << 'PYEOF'
import json, sys, urllib.request
token, chat_id = sys.argv[1], sys.argv[2]
text = (
    "📝 <b>Påminnelse – ny artikel</b>\n\n"
    "Idag är en bra dag att posta en ny artikel för att nå SEO-mål.\n\n"
    "Kör en NHL-dataartikel:\n"
    "<code>NHL-DATA-AUTO: thehockeybrain</code>\n"
    "<code>NHL-DATA-AUTO: thehockeyanalytics</code>"
)
payload = json.dumps({"chat_id": chat_id, "text": text, "parse_mode": "HTML"}).encode()
req = urllib.request.Request(
    f"https://api.telegram.org/bot{token}/sendMessage",
    data=payload, headers={"Content-Type": "application/json"})
urllib.request.urlopen(req, timeout=10)
print("Reminder sent.")
PYEOF
