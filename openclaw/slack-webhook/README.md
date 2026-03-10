# OpenClaw Slack-webhook – knapp "Publicera"

Minimal tjänst som tar emot Slack Interactivity (knappklick) och kör `publish-draft.sh` när någon klickar på **Publicera** med slug.

## Krav

- Node 18+
- Slack-app med **Interactivity** aktiverat och **Request URL** satt till denna tjänst
- `SLACK_SIGNING_SECRET` och `PUBLISH_CMD` (se nedan)

## Konfiguration

1. **Slack:** [api.slack.com/apps](https://api.slack.com/apps) → din app → **Basic Information** → **Signing Secret** (kopiera).
2. **Request URL:** Interactivity & Shortcuts → Request URL = `https://<din-webbadress>/slack-interaction` (HTTPS krävs).

## Miljövariabler

| Variabel | Beskrivning |
|----------|-------------|
| `SLACK_SIGNING_SECRET` | Signing Secret från Slack (Basic Information). |
| `PUBLISH_CMD` | Kommando som körs vid klick; ordet **SLUG** ersätts med knappens value. Exempel: `ssh tha 'docker exec $(docker ps -q -f name=openclaw \| head -1) /data/.openclaw/scripts/publish-draft.sh SLUG'` |
| `PORT` | Port (default 3000). |

## Knappens format i Slack

För att en knapp ska trigga denna webhook måste den ha:

- `action_id`: `publish_draft`
- `value`: slug (t.ex. `n8n-data-pipeline-tutorial`)

Exempel Block Kit:

```json
{
  "type": "actions",
  "elements": [
    {
      "type": "button",
      "text": { "type": "plain_text", "text": "Publicera" },
      "action_id": "publish_draft",
      "value": "n8n-data-pipeline-tutorial"
    }
  ]
}
```

Idag skickar agenten vanlig text. För att få knappar måste antingen agenten skicka meddelanden med Block Kit (blocks), eller så postar du manuellt ett meddelande med knappar (t.ex. efter att agenten skickat draft med slug).

## Deploy (t.ex. Coolify)

1. Lägg till en ny tjänst (Node.js); källkod = denna mapp eller repo + mapp.
2. Build: `npm install`, start: `npm start`.
3. Sätt env: `SLACK_SIGNING_SECRET`, `PUBLISH_CMD`, ev. `PORT`.
4. Säkerställ att tjänsten har HTTPS (Coolify ger ofta det) och att Request URL i Slack pekar på `https://<domän>/slack-interaction`.

## Test

- `GET /health` → `{"ok":true}`.
- Klicka på en knapp i Slack med `action_id: publish_draft` och `value: <slug>` → meddelandet uppdateras med "Publicerar …" och sedan "✅ Publicerat" eller felmeddelande.
