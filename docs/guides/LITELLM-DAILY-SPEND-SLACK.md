# Daglig LiteLLM-påminnelse till Slack

Varje dag skickas en kort påminnelse till Slack med **länk till LiteLLM Usage-sidan** – så du kan kolla kostnadsläget (Total Spend, Daily Spend, requests) direkt i dashboarden. Ingen API-anrop, så det fungerar även när `/global/spend/report` ger 503.

## Krav

- **Slack Incoming Webhook** (samma som för SEO-påminnelsen eller en egen kanal).

## Konfiguration på servern

Scriptet behöver:

| Variabel | Beskrivning |
|----------|-------------|
| `SLACK_WEBHOOK_URL` | Slack Incoming Webhook-URL (t.ex. från `~/.slack-seo-reminder-url`) |
| `LITELLM_UI_URL` | Valfritt: exakt länk till Usage-sidan (t.ex. `https://litellm.theunnamedroads.com/ui/?page=new_usage`). Om du inte sätter den byggs länken från `LITELLM_BASE_URL` + `/ui/?page=new_usage`. |
| `LITELLM_BASE_URL` | Valfritt om du sätter `LITELLM_UI_URL`. Proxy root utan `/v1`. |

Filen `~/.litellm-daily-spend-urls` kan innehålla t.ex.:

```bash
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
LITELLM_UI_URL=https://litellm.theunnamedroads.com/ui/?page=new_usage
```

Om du bara sätter `SLACK_WEBHOOK_URL` och `LITELLM_BASE_URL` byggs Usage-länken automatiskt.

## Körning och cron

Scriptet är redan på servern som `/usr/local/bin/litellm-daily-spend-slack.sh` och cron kör det **varje dag 08:00**. Meddelandet i Slack innehåller länken till Usage-sidan så du kan klicka och se Total Spend, Daily Spend och övriga metrics i dashboarden.

## Felsökning

- **Inget meddelande i Slack** – Kontrollera `SLACK_WEBHOOK_URL` (samma som för SEO-påminnelsen).
- **Fel länk** – Sätt `LITELLM_UI_URL` till den exakta URL du använder för Usage-vyn (t.ex. med `?login=success&page=new_usage` om du vill).
