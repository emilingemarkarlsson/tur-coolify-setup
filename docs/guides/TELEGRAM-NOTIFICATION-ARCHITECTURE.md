# Telegram Notification Architecture

> Senast uppdaterad: 2026-04-10
> Status: Migrerad till supergrupp med Topics (Fas 2 implementerad 2026-04-10).

## Ny struktur: Supergrupp med Topics

**Supergrupp chat_id:** `-1003919428238`

| Topic | thread_id | Kategori | Exempel |
|---|---|---|---|
| Contacts | `2` | CONTACT | Kontaktformulär, nyhetsbrevs-signup |
| Approvals | `3` | APPROVAL | EIK redaktionellt godkännande |
| Publishes | `4` | PUBLISH | Alla artikel-publiceringar (alla sajter) |
| Reports | `5` | REPORT | Daglig/vecko/månadsrapport, keyword-research, AEO |
| System Alerts | `6` | SYSTEM_ERROR | Workflow-fel via errorTrigger |

Bot-token: `8683132686:AAF5yJ206OcLKsSBx0n4Nm4uBAxcQlRbwyc`
Token lagras hårdkodat i n8n Code-noder och i `/data/.openclaw/telegram-config.json` (ej via `$env` — fungerar ej i n8n Code-noder).

---

## Gamla kanaler (avvecklade 2026-04-10)

| chat_id | Label | Ersatt av |
|---|---|---|
| `-1003767033253` | logs | Rätt topic i supergruppen |
| `-1003841635229` | thehockeyanalytics | Publishes (thread 4) |
| `-1003765951395` | thehockeybrain | Publishes (thread 4) |
| `-1003833003860` | approvals | Approvals (thread 3) |

---

## Workflow-routing

| Workflow ID | Namn | Topic | thread_id |
|---|---|---|---|
| `pba3YnrjQg893jqU` | tur-contactnotificationtotelegram | Contacts | 2 |
| `Vfbb93XU1UmBgwQ8` | Newsletter Signup Handler | Contacts | 2 |
| `YwlTkR687mZ1HMEY` | eik-seo-generator | Approvals | 3 |
| `9gn1VOZgC3usXUMw` | eik-keyword-approver | Approvals | 3 |
| `rPKUeMG0YZo8OCBY` | TUR – Telegram Approvals | Approvals | 3 |
| `9R1IVjLC2c2LN51n` | tha-seogenerator | Publishes | 4 |
| `QRgvi4BoB5CYJc2o` | tha-seopublisher | Publishes | 4 |
| `Np5AjkExWJNaW7Iq` | eik-seo-publisher | Publishes | 4 |
| `amDvkYTucdcSRBWP` | THB Daily | Publishes | 4 |
| `ZG4Jv9RD7liDpcmM` | tur-article-generator | Publishes | 4 |
| `XdnfbkbCL8NDjBdo` | tan-article-generator | Publishes | 4 |
| `ExMw8CCe97Y0ADOl` | taf-article-generator | Publishes | 4 |
| `xDuxJANXD3CsKsRq` | tpr-article-generator | Publishes | 4 |
| `j3gxGYKpnD6uHC8h` | Article Published – Newsletter Dispatch | Publishes | 4 |
| `9Tx4DtIhyUAcyRlu` | daily-consolidated-report | Reports | 5 |
| `zOEBV8UKnYhLj59r` | Weekly Traffic Report | Reports | 5 |
| `cwdzdxHIA4AOD6ND` | Monthly Report | Reports | 5 |
| `lGsFrLuD0nlRCz8w` | content-performance-feedback | Reports | 5 |
| `CjmhE3fQLFHpgCNj` | tha-keyword-research | Reports | 5 |
| `5ofsXkbkRdfwje6W` | eik-keyword-research | Reports | 5 |
| `US2yWNOVA985F0D5` | aeo-content-optimizer | Reports | 5 |
| `QTdyZOekzgAzvBO2` | Monitor – Telegram on Error | System Alerts | 6 |

---

## OpenClaw Publish-routing

Definierad i `/data/.openclaw/telegram-config.json` på servern (läses av `telegram-notify.sh`):

```json
{
  "bot_token": "8683132686:AAF5yJ206OcLKsSBx0n4Nm4uBAxcQlRbwyc",
  "channels": {
    "thehockeyanalytics": { "chat_id": "-1003919428238", "thread_id": 4 },
    "thehockeybrain":     { "chat_id": "-1003919428238", "thread_id": 4 },
    "theunnamedroads":    { "chat_id": "-1003919428238", "thread_id": 4 },
    "theprintroute":      { "chat_id": "-1003919428238", "thread_id": 4 },
    "theatomicnetwork":   { "chat_id": "-1003919428238", "thread_id": 4 },
    "theagentfabric":     { "chat_id": "-1003919428238", "thread_id": 4 },
    "emilingemarkarlsson":{ "chat_id": "-1003919428238", "thread_id": 4 },
    "finnbodahamnplan":   { "chat_id": "-1003919428238", "thread_id": 4 },
    "logs":               { "chat_id": "-1003919428238", "thread_id": 4 },
    "approvals":          { "chat_id": "-1003919428238", "thread_id": 3 }
  }
}
```

`telegram-notify.sh` stödjer nu både gammalt format (string) och nytt format (objekt med `chat_id` + `thread_id`).

---

## Implementation-mönster

### httpRequest-noder (jsonBody):
```json
{
  "chat_id": "-1003919428238",
  "message_thread_id": THREAD_ID,
  "text": "...",
  "parse_mode": "HTML"
}
```

### n8n Telegram-noder (additionalFields):
```
chatId: -1003919428238
additionalFields.message_thread_id: THREAD_ID
```

### Code-noder (fetch):
```javascript
const chatId = '-1003919428238';
body: JSON.stringify({ chat_id: chatId, text, parse_mode: 'HTML', message_thread_id: THREAD_ID })
```

---

## Referensimplementation: artikel-generator

**Rätt mönster** (TPR, TUR, TAN, TAF):
```
Webhook/Schedule → Generate → Publish via OpenClaw
                                      ↓
                              OpenClaw publish-draft.sh
                              skickar EN Telegram-notis (Publishes topic)
```

**Regel**: Workflow-noder skickar ALDRIG Telegram-notis för publiceringar som går via OpenClaw. OpenClaw äger publish-notisen.

---

## Dedup-skydd

Aktiva workflows med dedup (via `$getWorkflowStaticData('global')`, TTL 10 min):

| Workflow | Nyckel |
|---|---|
| `tur-contactnotificationtotelegram` | email + meddelandehash |
| `tpr-earlyaccess-telegram` | email |

---

## Driftrutin: Ansluta nytt workflow

1. **Bestäm kategori**: CONTACT / APPROVAL / PUBLISH / REPORT / SYSTEM_ERROR
2. **Välj rätt thread_id** per tabellen ovan (2/3/4/5/6)
3. **chat_id alltid**: `-1003919428238`
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

- [ ] Kategori vald och rätt thread_id angiven
- [ ] chat_id är `-1003919428238`
- [ ] Source/site inkluderat i meddelande
- [ ] Dedup implementerat (om event-webhook)
- [ ] Testmeddelande skickat, exakt 1 meddelande i rätt topic
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
