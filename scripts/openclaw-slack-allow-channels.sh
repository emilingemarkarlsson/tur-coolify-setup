#!/usr/bin/env bash
# Sätter OpenClaw Slack groupPolicy till "open" så att alla kanaler accepteras.
# Kör på servern där OpenClaw-containern körs (SSH eller Coolify Terminal på host).
# Användning: ./scripts/openclaw-slack-allow-channels.sh

set -euo pipefail

CONTAINER=$(docker ps --format '{{.Names}}' | grep -i openclaw | head -1)
if [[ -z "$CONTAINER" ]]; then
  echo "Hittar ingen openclaw-container. Kör: docker ps | grep openclaw"
  exit 1
fi

CONFIG_PATH="/data/.openclaw/openclaw.json"
TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

echo "Använder container: $CONTAINER"
echo "Kopierar $CONFIG_PATH från container..."
docker cp "$CONTAINER:$CONFIG_PATH" "$TMP_FILE" 2>/dev/null || {
  echo "Kunde inte kopiera. Kontrollera att containern heter något med 'openclaw' och att $CONFIG_PATH finns."
  exit 1
}

# Sätt channels.slack.groupPolicy = "open"
if command -v jq &>/dev/null; then
  jq '.channels = ((.channels // {}) | .slack = ((.slack // {}) | .groupPolicy = "open"))' \
    "$TMP_FILE" > "${TMP_FILE}.new" && mv "${TMP_FILE}.new" "$TMP_FILE"
else
  python3 -c "
import json
p = '$TMP_FILE'
with open(p) as f:
    d = json.load(f)
d.setdefault('channels', {})
d['channels'].setdefault('slack', {})
d['channels']['slack']['groupPolicy'] = 'open'
with open(p, 'w') as f:
    json.dump(d, f, indent=2)
"
fi

echo "Sätter tillbaka konfigurationen..."
docker cp "$TMP_FILE" "$CONTAINER:$CONFIG_PATH"
echo "Klart. Starta om OpenClaw i Coolify (Restart) så att ändringen träder i kraft."
exit 0
