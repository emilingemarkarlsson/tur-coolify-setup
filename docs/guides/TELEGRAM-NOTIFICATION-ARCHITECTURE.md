# Telegram Notification Architecture

> Senast uppdaterad: 2026-04-10
> Status: Fas 1 implementerad. Fas 2 (Topics/forum-mode) kräver manuell Telegram-setup.

## Kanalöversikt

| chat_id | Label | Syfte |
|---|---|---|
| `-1003767033253` | logs | Publiceringar, rapporter, systemloggar, kontaktnotiser |
| `-1003841635229` | thehockeyanalytics | THA-specifika publiceringar (via OpenClaw) |
| `-1003765951395` | thehockeybrain | THB-specifika publiceringar (via OpenClaw) |
| `-1003833003860` | approvals | Redaktionella godkännanden (EIK editorial) |

Bot-token lagras i OpenClaw-config och är **hårdkodad i n8n Code-noder** (inte via `$env` — fungerar ej i n8n Code-noder).

---

## Notifieringskategorier

| Kategori | Kanal | Exempel |
|---|---|---|
| `CONTACT` | logs | Kontaktformulär, nyhetsbrevs-signup |
| `APPROVAL` | approvals | EIK redaktionellt godkännande |
| `PUBLISH` | logs (generiska) / site-kanal (THA/THB) | Artikel publicerad |
| `SEO_REPORT` | logs | Daglig/vecko/månadsrapport |
| `SYSTEM_LOG` | logs | Keyword research-sammanfattning, AEO-optimering |
| `SYSTEM_ERROR` | logs | Workflow-fel via errorTrigger |

---

## Referensimplementation: artikel-generator

**Rätt mönster** (TPR, nu även TUR/TAN/TAF):
```
Webhook/Schedule → Generate → Publish via OpenClaw
                                      ↓
                              OpenClaw publish-draft.sh
                              skickar EN Telegram-notis
```

**Fel mönster** (var fallet för TUR/TAN/TAF, nu fixat):
```
Webhook/Schedule → Generate → Publish via OpenClaw → Notify Telegram  ← TA BORT
                                      ↓
                              OpenClaw publish-draft.sh → Notify Telegram (dubblett!)
```

**Regel**: Workflow-noder skickar ALDRIG Telegram-notis för publiceringar som går via OpenClaw. OpenClaw äger publish-notisen.

---

## OpenClaw Publish-routing

Definierad i `/data/.openclaw/telegram-config.json` på servern:

| umamiName | TG_CHANNEL | chat_id |
|---|---|---|
| thehockeyanalytics | thehockeyanalytics | -1003841635229 |
| thehockeybrain | thehockeybrain | -1003765951395 |
| theunnamedroads | logs | -1003767033253 |
| theprintroute | logs | -1003767033253 |
| theatomicnetwork | logs | -1003767033253 |
| theagentfabric | logs | -1003767033253 |
| emilingemarkarlsson | logs | -1003767033253 |

---

## Dedup-skydd

Aktiva workflows med dedup (via `$getWorkflowStaticData('global')`, TTL 10 min):

| Workflow | Nyckel |
|---|---|
| `tur-contactnotificationtotelegram` | email + meddelandehash |
| `tpr-earlyaccess-telegram` | email |

Övriga workflows (rapporter, publiceringar) behöver inte dedup — varje körning är unik.

---

## Fas 2: Forum-mode / Topics (EJ implementerat)

För att minska brus i `logs`-kanalen och separera signaltyper:

### Vad du behöver göra manuellt i Telegram

1. Öppna supergruppen `-1003767033253` i Telegram
2. **Inställningar → Topics → Aktivera Topics** (Forum mode)
3. Skapa dessa topics:

| Topic-namn | Kategori | Workflows att flytta |
|---|---|---|
| 📬 Kontakter & Leads | CONTACT | tur-contactnotificationtotelegram, Newsletter Signup Handler |
| 📰 Publiceringar | PUBLISH | alla article-generators, tha-seogenerator, eik-seo-publisher |
| 📊 Rapporter | SEO_REPORT + SYSTEM_LOG | daily/weekly/monthly report, keyword-research, aeo-optimizer |
| 🚨 Systemlarm | SYSTEM_ERROR | Monitor – Telegram on Error |

4. Skicka mig `message_thread_id` för varje topic (syns via `@getidsbot` eller via Telegram API)
5. Jag uppdaterar sedan alla workflows med rätt `message_thread_id`

### Hur topics sätts i n8n

I httpRequest-noder (jsonBody):
```json
{
  "chat_id": -1003767033253,
  "message_thread_id": TOPIC_ID_HÄR,
  "text": "...",
  "parse_mode": "HTML"
}
```

I Telegram-noder (additionalFields):
```
message_thread_id: TOPIC_ID_HÄR
```

---

## Driftrutin: Ansluta nytt workflow

1. **Bestäm kategori**: CONTACT / APPROVAL / PUBLISH / SEO_REPORT / SYSTEM_LOG / SYSTEM_ERROR
2. **Välj rätt kanal** per tabellen ovan
3. **Välj rätt topic** (när Fas 2 är aktiverad) per tabellen ovan
4. **Lägg till dedup** om det är ett event-drivet webhook-flöde (kontakt/lead)
5. **Namnstandard**: `{site}-{typ}-telegram` eller `{site}-{typ}-{action}`
6. **Token**: använd hårdkodad bot-token (inte `$env.TELEGRAM_BOT_TOKEN` — fungerar ej)
7. **Source**: inkludera alltid källsajt i meddelanderubrik

### Meddelandemall

```
{EMOJI} <b>{Händelsetyp} – {Sajt}</b>

<b>Fält:</b> {värde}
...
<b>Källa:</b> {site}
<b>Tid:</b> {timestamp}
```

---

## Release-checklista

Innan ett nytt notifieringsflöde aktiveras:

- [ ] Kategori vald och rätt kanal/topic angiven
- [ ] Source/site inkluderat i meddelande
- [ ] Dedup implementerat (om event-webhook)
- [ ] Testpayload skickad, exakt 1 meddelande i rätt kanal
- [ ] Dubbletttest kört (2 identiska payloads < 10 min → bara 1 meddelande)
- [ ] Workflow-namn följer naming-standard
- [ ] Ingen n8n Telegram-nod i OpenClaw-baserade publish-flöden
- [ ] Local JSON-fil i `n8n/workflows/` uppdaterad efter deploy

---

## Rollback-plan

Varje workflow-ändring:
```bash
# Hämta live-version INNAN ändring
curl -s -H "X-N8N-API-KEY: $KEY" "$N8N_URL/api/v1/workflows/{ID}" > backup-{ID}.json

# Återställ
curl -s -X PUT -H "X-N8N-API-KEY: $KEY" \
  -H "Content-Type: application/json" \
  -d @backup-{ID}.json \
  "$N8N_URL/api/v1/workflows/{ID}"
```

Lokala JSON-filer i `n8n/workflows/` fungerar som git-baserad backup.
