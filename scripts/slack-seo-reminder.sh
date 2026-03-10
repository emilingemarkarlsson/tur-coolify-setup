#!/usr/bin/env bash
# Skickar en schemalagd påminnelse till Slack om att det är dags att överväga en ny artikel.
# Använder Slack Incoming Webhook – ingen OpenClaw, inga AI-krediter.
#
# Webhook-URL: miljö SLACK_WEBHOOK_URL, eller fil ~/.slack-seo-reminder-url, eller /etc/slack-seo-reminder-url.
# Schemalägg med cron på en server (t.ex. tha) så påminnelsen går ut även när din dator är av.

set -euo pipefail

WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
if [[ -z "$WEBHOOK_URL" ]]; then
  for f in "${HOME:-}/.slack-seo-reminder-url" /etc/slack-seo-reminder-url; do
    if [[ -f "$f" ]]; then
      WEBHOOK_URL=$(cat "$f" | tr -d '\n\r')
      break
    fi
  done
fi
if [[ -z "$WEBHOOK_URL" ]]; then
  echo "SLACK_WEBHOOK_URL inte satt och ingen fil ~/.slack-seo-reminder-url eller /etc/slack-seo-reminder-url. Skapa en Incoming Webhook i Slack." >&2
  exit 1
fi

# Påminnelse – kort och tydlig, med nästa steg (JSON: escape " och \)
PAYLOAD='{"text":"📝 *Påminnelse – ny artikel på emilingemarkarlsson.com*\n\nIdag är en bra dag att posta en ny artikel för att nå våra SEO-mål.\n\n*Nästa steg:* Skriv i denna kanal: `@tur-openclaw artikel-förslag för emilingemarkarlsson` – sedan välj ett förslag (t.ex. skriv `2`) och följ flödet."}'

curl -sS -X POST -H 'Content-type: application/json' --data "$PAYLOAD" "$WEBHOOK_URL" >/dev/null || true
