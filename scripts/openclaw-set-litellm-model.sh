#!/usr/bin/env bash
# Sätter OpenClaw till att använda LiteLLM med modellen "claw-brain" via en custom provider,
# så att API-anropet skickar model=claw-brain (inte openai/claw-brain) till LiteLLM.
# Kör på servern där OpenClaw-containern körs.
# Användning: ./scripts/openclaw-set-litellm-model.sh

set -euo pipefail

CONTAINER=$(docker ps --format '{{.Names}}' | grep -i openclaw | head -1)
if [[ -z "$CONTAINER" ]]; then
  echo "Hittar ingen openclaw-container."
  exit 1
fi

CONFIG_PATH="/data/.openclaw/openclaw.json"
TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

# Hämta OPENAI_API_BASE från containern (LiteLLM-URL). Använd http:// så containern når LiteLLM (samma som OpenClaw env).
OPENAI_BASE=$(docker exec "$CONTAINER" sh -c 'echo "$OPENAI_API_BASE"' 2>/dev/null || true)
if [[ -z "$OPENAI_BASE" ]]; then
  echo "OPENAI_API_BASE är inte satt i containern. Sätt den i Coolify (LiteLLM-URL med /v1)."
  exit 1
fi
# Tvinga http så att anslutning från container till samma server fungerar (undvik TLS/loopback-problem)
OPENAI_BASE="${OPENAI_BASE/https:/http:}"

echo "Använder container: $CONTAINER"
echo "LiteLLM base: $OPENAI_BASE"
docker cp "$CONTAINER:$CONFIG_PATH" "$TMP_FILE" 2>/dev/null || { echo "Kunde inte kopiera openclaw.json"; exit 1; }

# apiKey använder env-referens så OpenClaw läser OPENAI_API_KEY vid körning
if command -v jq &>/dev/null; then
  jq --arg base "$OPENAI_BASE" \
    '.models.providers = ((.models.providers // {}) | .litellm = {
      baseUrl: $base,
      apiKey: "${OPENAI_API_KEY}",
      api: "openai-completions",
      models: [{ id: "claw-brain", name: "Claw Brain" }]
    }) | .agents.defaults.model.primary = "litellm/claw-brain"' \
    "$TMP_FILE" > "${TMP_FILE}.new" && mv "${TMP_FILE}.new" "$TMP_FILE"
else
  python3 -c "
import json
p = '$TMP_FILE'
base = '''$OPENAI_BASE'''
with open(p) as f:
    d = json.load(f)
d.setdefault('models', {})
d['models'].setdefault('providers', {})
d['models']['providers']['litellm'] = {
    'baseUrl': base,
    'apiKey': '\${OPENAI_API_KEY}',
    'api': 'openai-completions',
    'models': [{'id': 'claw-brain', 'name': 'Claw Brain'}]
}
d.setdefault('agents', {}).setdefault('defaults', {}).setdefault('model', {})['primary'] = 'litellm/claw-brain'
with open(p, 'w') as f:
    json.dump(d, f, indent=2)
"
fi

docker cp "$TMP_FILE" "$CONTAINER:$CONFIG_PATH"
echo "Klart. OpenClaw är satt till litellm/claw-brain. Starta om OpenClaw i Coolify (Restart)."
exit 0
