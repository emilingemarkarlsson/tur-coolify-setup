#!/usr/bin/env bash
# Schemalagd påminnelse till Telegram om att posta ny artikel.
# Cron (t.ex. mån 09:00): 0 9 * * 1 /data/.openclaw/scripts/telegram-seo-reminder.sh

set -euo pipefail

CONFIG="/data/.openclaw/telegram-config.json"
TOKEN=$(python3 -c "import json; d=json.load(open('${CONFIG}')); print(d['bot_token'])")
CHAT_ID=$(python3 -c "import json; d=json.load(open('${CONFIG}')); print(d['channels']['logs'])")

TEXT="📝 <b>Påminnelse – ny artikel</b>

Idag är en bra dag att posta en ny artikel för att nå SEO-mål.

Kör en NHL-dataartikel:
<code>NHL-DATA-AUTO: thehockeybrain</code>
<code>NHL-DATA-AUTO: thehockeyanalytics</code>"

python3 - "$TOKEN" "$CHAT_ID" "$TEXT" << 'PYEOF'
import json, sys, urllib.request
token, chat_id, text = sys.argv[1], sys.argv[2], sys.argv[3]
payload = json.dumps({"chat_id": chat_id, "text": text, "parse_mode": "HTML"}).encode()
req = urllib.request.Request(
    f"https://api.telegram.org/bot{token}/sendMessage",
    data=payload, headers={"Content-Type": "application/json"})
urllib.request.urlopen(req, timeout=10)
print("Reminder sent.")
PYEOF
