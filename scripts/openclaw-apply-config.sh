#!/usr/bin/env bash
# Kör både Slack-kanal- och LiteLLM-modell-konfiguration för OpenClaw.
# Använd efter deploy eller om config har blivit återställd.
# Kör från repots rot (lokal maskin): ./scripts/openclaw-apply-config.sh
# Kräver att SSH-alias "tha" är konfigurerat.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== OpenClaw apply config (Slack channels + LiteLLM model) ==="
ssh tha 'bash -s' < "$SCRIPT_DIR/openclaw-slack-allow-channels.sh"
ssh tha 'bash -s' < "$SCRIPT_DIR/openclaw-set-litellm-model.sh"
echo "=== Klart ==="
