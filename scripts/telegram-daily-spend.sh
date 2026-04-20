#!/usr/bin/env bash
# Daglig LiteLLM-rapport till Telegram med faktisk spend-data.
#
# Kräver: TELEGRAM_BOT_TOKEN och TELEGRAM_CHAT_ID (logs-kanalen)
# Cron (t.ex. 08:00): 0 8 * * * /usr/local/bin/telegram-daily-spend.sh

set -euo pipefail

TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:--1003767033253}"

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

BASE="${LITELLM_BASE_URL:-https://litellm.theunnamedroads.com}"
MASTER_KEY="${LITELLM_MASTER_KEY:-7cFubmhrruWpKV7tvYqKnp6o4HqrDj7L}"
USAGE_LINK="${LITELLM_UI_URL:-${BASE%/}/ui/?page=new_usage}"

python3 - "$TOKEN" "$CHAT_ID" "$BASE" "$MASTER_KEY" "$USAGE_LINK" << 'PYEOF'
import json, sys, urllib.request
from datetime import date

token, chat_id, base, key, link = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
base = base.rstrip('/')
headers = {'Authorization': 'Bearer ' + key}

def get(path):
    req = urllib.request.Request(base + path, headers=headers)
    return json.loads(urllib.request.urlopen(req, timeout=10).read())

# Fetch data
total = get('/global/spend')
daily = get('/global/spend/logs?limit=30')
models = get('/global/spend/models')

# Total spend
total_spend = total.get('spend', 0)

# Today's spend
today = str(date.today())
today_spend = next((d['spend'] for d in daily if d['date'] == today), 0.0)

# Last 7 days bar chart
bars = [d for d in daily[-7:]]
if bars:
    max_val = max(d['spend'] for d in bars) or 1
    chart_lines = []
    for d in bars:
        pct = d['spend'] / max_val
        filled = round(pct * 8)
        bar = '█' * filled + '░' * (8 - filled)
        day_label = d['date'][5:]  # MM-DD
        chart_lines.append(f"{day_label} {bar} ${d['spend']:.3f}")
    chart = '\n'.join(chart_lines)
else:
    chart = 'Ingen data'

# Top 3 models
top_models = models[:3]
model_lines = '\n'.join(
    f"  {m['model']}: ${m['total_spend']:.4f}"
    for m in top_models
)

text = (
    f"<b>LiteLLM – daglig rapport</b>\n\n"
    f"Totalt: <b>${total_spend:.4f}</b>\n"
    f"Idag:   <b>${today_spend:.4f}</b>\n\n"
    f"<b>Senaste 7 dagarna:</b>\n<code>{chart}</code>\n\n"
    f"<b>Topmodeller (totalt):</b>\n<code>{model_lines}</code>\n\n"
    f"<a href=\"{link}\">Oppna dashboard</a>"
)

payload = json.dumps({"chat_id": chat_id, "text": text, "parse_mode": "HTML", "disable_web_page_preview": True}).encode()
req = urllib.request.Request(
    f"https://api.telegram.org/bot{token}/sendMessage",
    data=payload, headers={"Content-Type": "application/json"})
urllib.request.urlopen(req, timeout=10)
print("Telegram notification sent.")
PYEOF
