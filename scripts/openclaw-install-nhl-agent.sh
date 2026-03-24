#!/usr/bin/env bash
# Installerar NHL Data Auto-agenten i OpenClaw-containern.
# Kopierar:
#   - nhl-data-fetch.sh       → /data/.openclaw/scripts/
#   - NHL-DATA-AUTO-PROMPT.md → /data/.openclaw/agents/
#   - Uppdaterad SEO-ROLLING-AUTOMATION-PROMPT.md → /data/.openclaw/agents/
#
# Kör från repots rot: ./scripts/openclaw-install-nhl-agent.sh
# Kräver SSH-alias "tha" och att OpenClaw körs på servern.
#
# Lägger INTE till cron-jobb automatiskt (kräver en påloggad terminal).
# Cron-kommandon skrivs ut i slutet – kör dem manuellt eller via:
#   ssh tha 'docker exec <container> openclaw cron add ...'

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS_DIR="$REPO_ROOT/openclaw/agents"
SCRIPTS_DIR="$REPO_ROOT/openclaw/scripts"

# ── Verify required files ──────────────────────────────────────────────────
for f in \
  "$SCRIPTS_DIR/nhl-data-fetch.sh" \
  "$AGENTS_DIR/NHL-DATA-AUTO-PROMPT.md" \
  "$AGENTS_DIR/SEO-ROLLING-AUTOMATION-PROMPT.md"; do
  if [[ ! -f "$f" ]]; then
    echo "Saknar fil: $f"
    exit 1
  fi
done

# ── Find container ─────────────────────────────────────────────────────────
echo "Hämtar OpenClaw-container från tha..."
CONTAINER=$(ssh tha 'docker ps --format "{{.Names}}" | grep -i openclaw | head -1')
if [[ -z "$CONTAINER" ]]; then
  echo "Ingen OpenClaw-container hittad på tha. Kör: ssh tha 'docker ps | grep openclaw'"
  exit 1
fi
echo "Container: $CONTAINER"

# ── Create directories ─────────────────────────────────────────────────────
echo "Skapar /data/.openclaw/scripts och /data/.openclaw/nhl-data..."
ssh tha "docker exec $CONTAINER mkdir -p /data/.openclaw/scripts /data/.openclaw/nhl-data /data/.openclaw/agents"

# ── Copy nhl-data-fetch.sh ─────────────────────────────────────────────────
echo "Kopierar nhl-data-fetch.sh..."
scp -q "$SCRIPTS_DIR/nhl-data-fetch.sh" "tha:/tmp/nhl-data-fetch.sh"
ssh tha "docker cp /tmp/nhl-data-fetch.sh $CONTAINER:/data/.openclaw/scripts/nhl-data-fetch.sh \
         && docker exec $CONTAINER chmod +x /data/.openclaw/scripts/nhl-data-fetch.sh"
ssh tha "rm -f /tmp/nhl-data-fetch.sh"
echo "  ✓ /data/.openclaw/scripts/nhl-data-fetch.sh"

# ── Copy NHL-DATA-AUTO-PROMPT.md ───────────────────────────────────────────
echo "Kopierar NHL-DATA-AUTO-PROMPT.md..."
scp -q "$AGENTS_DIR/NHL-DATA-AUTO-PROMPT.md" "tha:/tmp/NHL-DATA-AUTO-PROMPT.md"
ssh tha "docker cp /tmp/NHL-DATA-AUTO-PROMPT.md $CONTAINER:/data/.openclaw/agents/NHL-DATA-AUTO-PROMPT.md"
ssh tha "rm -f /tmp/NHL-DATA-AUTO-PROMPT.md"
echo "  ✓ /data/.openclaw/agents/NHL-DATA-AUTO-PROMPT.md"

# ── Copy updated SEO-ROLLING-AUTOMATION-PROMPT.md ─────────────────────────
echo "Kopierar SEO-ROLLING-AUTOMATION-PROMPT.md (med NHL-DATA-AUTO-sektion)..."
scp -q "$AGENTS_DIR/SEO-ROLLING-AUTOMATION-PROMPT.md" "tha:/tmp/SEO-ROLLING-AUTOMATION-PROMPT.md"
ssh tha "docker cp /tmp/SEO-ROLLING-AUTOMATION-PROMPT.md $CONTAINER:/data/.openclaw/agents/SEO-ROLLING-AUTOMATION-PROMPT.md"
ssh tha "rm -f /tmp/SEO-ROLLING-AUTOMATION-PROMPT.md"
echo "  ✓ /data/.openclaw/agents/SEO-ROLLING-AUTOMATION-PROMPT.md"

# ── Smoke test: kan scriptet nå NHL API? ───────────────────────────────────
echo ""
echo "Testar NHL API-anslutning från containern..."
API_STATUS=$(ssh tha "docker exec $CONTAINER curl -sf --max-time 10 -o /dev/null -w '%{http_code}' \
  'https://api-web.nhle.com/v1/standings/now'" 2>/dev/null || echo "000")
if [[ "$API_STATUS" == "200" ]]; then
  echo "  ✓ NHL API nåbar (HTTP $API_STATUS)"
else
  echo "  ⚠ NHL API svarade $API_STATUS – kontrollera nätverksåtkomst från containern"
fi

# ── Show cron commands ─────────────────────────────────────────────────────
cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Klar. Kör nu dessa cron-kommandon på servern (eller klistra in i terminal):

# thehockeybrain – djup analytics – måndag, onsdag, fredag kl 09:00
ssh tha 'docker exec $CONTAINER openclaw cron add \\
  --message "NHL-DATA-AUTO: thehockeybrain\\n\\nLäs /data/.openclaw/agents/NHL-DATA-AUTO-PROMPT.md för fullständiga instruktioner. Kör hela kedjan: fetch → analysera → skriv artikel (analytiskt djup, 1400–1800 ord, english) → publicera via publish-draft.sh → rapportera URL till Slack (#all-tur-ab). Ingen godkännande behövs." \\
  --cron "0 9 * * 1,3,5" \\
  --announce --channel slack --to "channel:C07TJRLTM9C"'

# thehockeyanalytics – coachfokus – tisdag, torsdag kl 09:00
ssh tha 'docker exec $CONTAINER openclaw cron add \\
  --message "NHL-DATA-AUTO: thehockeyanalytics\\n\\nLäs /data/.openclaw/agents/NHL-DATA-AUTO-PROMPT.md för fullständiga instruktioner. Kör hela kedjan: fetch → analysera → skriv artikel (tillgänglig coachfokus, 1100–1400 ord, english) → publicera via publish-draft.sh → rapportera URL till Slack (#all-tur-ab). Ingen godkännande behövs." \\
  --cron "0 9 * * 2,4" \\
  --announce --channel slack --to "channel:C07TJRLTM9C"'

# Testa manuellt (kör en gång nu):
ssh tha 'docker exec $CONTAINER /data/.openclaw/scripts/nhl-data-fetch.sh'

# Lista befintliga cron-jobb:
ssh tha 'docker exec $CONTAINER openclaw cron list'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Filer i containern:
  /data/.openclaw/scripts/nhl-data-fetch.sh
  /data/.openclaw/agents/NHL-DATA-AUTO-PROMPT.md
  /data/.openclaw/agents/SEO-ROLLING-AUTOMATION-PROMPT.md (uppdaterad)
  /data/.openclaw/nhl-data/                (output-mapp för JSON)

EOF
