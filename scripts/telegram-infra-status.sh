#!/usr/bin/env bash
# Daglig infrastrukturrapport till Telegram.
# Visar server-hälsa (CPU, RAM, disk) och status på alla Docker-containers.
#
# Cron (t.ex. 08:05): 5 8 * * * /usr/local/bin/telegram-infra-status.sh

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

# --- Samla server-metrics ---
UPTIME_RAW=$(uptime)
LOAD=$(awk '{print $1" "$2" "$3}' /proc/loadavg)
UPTIME_DAYS=$(awk '{d=int($1/86400); h=int(($1%86400)/3600); printf "%dd %dh", d, h}' /proc/uptime)

MEM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
MEM_AVAIL=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
MEM_USED=$(( MEM_TOTAL - MEM_AVAIL ))
MEM_PCT=$(( MEM_USED * 100 / MEM_TOTAL ))
MEM_USED_GB=$(awk "BEGIN {printf \"%.1f\", $MEM_USED/1048576}")
MEM_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $MEM_TOTAL/1048576}")

SWAP_TOTAL=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
SWAP_FREE=$(awk '/SwapFree/ {print $2}' /proc/meminfo)
SWAP_USED=$(( SWAP_TOTAL - SWAP_FREE ))
SWAP_USED_GB=$(awk "BEGIN {printf \"%.1f\", $SWAP_USED/1048576}")
SWAP_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $SWAP_TOTAL/1048576}")

DISK_INFO=$(df -h / | awk 'NR==2 {print $3" / "$2" ("$5")"}')

# --- Samla container-status ---
CONTAINER_JSON=$(docker ps -a --format '{"name":"{{.Names}}","status":"{{.Status}}","health":"{{.Status}}"}' | \
  python3 -c "
import sys, json

lines = sys.stdin.read().strip().splitlines()
containers = []
for line in lines:
    d = json.loads(line)
    s = d['status']
    name = d['name']
    # Kategorisera
    if '(healthy)' in s:
        state = 'healthy'
    elif '(unhealthy)' in s:
        state = 'unhealthy'
    elif s.startswith('Up'):
        state = 'up'
    elif s.startswith('Exited') or s.startswith('Dead'):
        state = 'down'
    else:
        state = 'unknown'
    # Uptime-siffra
    uptime_str = s.split('(')[0].strip().replace('Up ', '')
    containers.append({'name': name, 'state': state, 'uptime': uptime_str})
print(json.dumps(containers))
")

# --- Bygg Telegram-meddelande via Python ---
python3 - "$TOKEN" "$CHAT_ID" "$UPTIME_DAYS" "$LOAD" \
  "$MEM_USED_GB" "$MEM_TOTAL_GB" "$MEM_PCT" \
  "$SWAP_USED_GB" "$SWAP_TOTAL_GB" \
  "$DISK_INFO" "$CONTAINER_JSON" << 'PYEOF'
import json, sys, urllib.request

token, chat_id, uptime, load, mem_used, mem_total, mem_pct, swap_used, swap_total, disk, containers_raw = sys.argv[1:]

containers = json.loads(containers_raw)

total = len(containers)
healthy_count = sum(1 for c in containers if c['state'] in ('healthy', 'up'))
problem = [c for c in containers if c['state'] in ('unhealthy', 'down', 'unknown')]

def mem_bar(pct):
    pct = int(pct)
    filled = round(pct / 10)
    return '█' * filled + '░' * (10 - filled) + f' {pct}%'

# Key services to highlight (others grouped)
key_services = [
    'coolify', 'coolify-proxy', 'n8n', 'litellm', 'openclaw',
    'minio', 'umami', 'open-webui', 'listmonk', 'qdrant', 'charts-api'
]

icon_map = {'healthy': '✅', 'up': '🟡', 'unhealthy': '❌', 'down': '❌', 'unknown': '⚠️'}

lines = []
for svc in key_services:
    match = next((c for c in containers if c['name'].startswith(svc)), None)
    if match:
        icon = icon_map.get(match['state'], '⚠️')
        note = ' (ingen healthcheck)' if match['state'] == 'up' else ''
        lines.append(f"{icon} {svc} – {match['uptime']}{note}")

svc_block = '\n'.join(lines) if lines else '(inga containers)'

problem_block = ''
if problem:
    problem_block = '\n\n<b>Problem:</b>\n' + '\n'.join(
        f"❌ {c['name']} ({c['state']})" for c in problem
    )

status_emoji = '✅' if not problem else '❌'

text = (
    f"<b>Infrastruktur – daglig status</b> {status_emoji}\n\n"
    f"<b>Hetzner (tha)</b>\n"
    f"Uppe: {uptime}  |  Load: {load}\n"
    f"RAM:  {mem_used} / {mem_total} GB  {mem_bar(mem_pct)}\n"
    f"Swap: {swap_used} / {swap_total} GB\n"
    f"Disk: {disk}\n\n"
    f"<b>Containers ({healthy_count}/{total} OK)</b>\n"
    f"<code>{svc_block}</code>"
    f"{problem_block}"
)

payload = json.dumps({
    "chat_id": chat_id,
    "text": text,
    "parse_mode": "HTML",
    "disable_web_page_preview": True
}).encode()

req = urllib.request.Request(
    f"https://api.telegram.org/bot{token}/sendMessage",
    data=payload, headers={"Content-Type": "application/json"})
urllib.request.urlopen(req, timeout=10)
print("Infra status sent.")
PYEOF
