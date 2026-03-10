# Daglig trafiksammanfattning från Umami

Du kan få en daglig sammanfattning av trafiken på alla dina webbplatser (som sparas i Umami) på tre sätt:

- **n8n** – schemalagd hämtning från Umami API och postning till Slack (enkel, stabil).
- **OpenClaw hybrid** – n8n hämtar data, OpenClaw skriver och postar sammanfattningen till Slack.
- **OpenClaw direkt** – OpenClaw hämtar själv från Umami (script + cron) och postar; du kan dessutom **ställa motfrågor i Slack** ("Vad var vår trafik igår?", "Varför ökade sidvisningarna?") och få svar utifrån samma data. Se **[openclaw/UMAMI-DIRECT.md](../openclaw/UMAMI-DIRECT.md)**.

---

## Quick start (n8n)

1. **n8n Environment Variables:** Sätt `UMAMI_USERNAME` och `UMAMI_PASSWORD` (samma som inloggning på https://umami.theunnamedroads.com).
2. **Importera workflow:** I n8n → Workflows → Import from File → välj `umami/n8n-workflow-daily-umami-summary.json`.
3. **Slack:** Öppna noden **Slack – skicka rapport**, välj kanal (t.ex. `#general`) och koppla dina Slack-credentials.
4. **Aktivera** workflowen. Den kör då varje dag 08:00 (Europe/Stockholm) och skickar en trafikrapport för gårdagen till Slack.

### Quick start (OpenClaw-variant)

1. **OpenClaw webhooks:** Aktivera webhooks i OpenClaw och sätt en token (se [Variant med OpenClaw](#variant-med-openclaw-modernare) nedan).
2. **n8n Environment Variables:** Sätt `UMAMI_USERNAME`, `UMAMI_PASSWORD`, `OPENCLAW_HOOKS_URL` (t.ex. `https://openclaw.theunnamedroads.com`), `OPENCLAW_HOOKS_TOKEN` och `OPENCLAW_SLACK_CHANNEL_ID` (Slack-kanalens ID, t.ex. `C01234ABCD`).
3. **Importera workflow:** Välj `umami/n8n-workflow-daily-umami-openclaw.json`.
4. **Aktivera** workflowen. Varje morgon hämtar n8n data från Umami och skickar till OpenClaw, som skriver en kort sammanfattning och postar till Slack från din assistent.

---

## Tre vägar (rekommendation)

En vanlig rekommendation för Umami + OpenClaw är att välja mellan tre nivåer. Här är hur de mapas mot det vi redan har i repot:

| Nivå | Beskrivning | Vår lösning i repot |
|------|-------------|----------------------|
| **1. Enklast** | Färdigt verktyg som skickar Umami → Slack; kör som cron (eller triggas av OpenClaw). | **[umami-notifier](#alternativ-umami-notifier)** (PHP-CLI) – se nedan. |
| **2. Ren OpenClaw** | Custom script/skill som anropar Umami API, formaterar rapport och skickar till Slack. | **OpenClaw direkt** – scriptet `openclaw/scripts/umami-daily-stats.sh` + cron (se [openclaw/UMAMI-DIRECT.md](../openclaw/UMAMI-DIRECT.md)). |
| **3. Med AI-sammanfattning** | Samma som 2, men rådata skickas till LLM för en kort, läsbar sammanfattning innan Slack. | **OpenClaw direkt** (agenten sammanfattar utifrån scriptets JSON) och **n8n → OpenClaw** (n8n hämtar data, OpenClaw skriver text med LiteLLM). |

**Bonus:** Med **OpenClaw direkt** kan du dessutom **ställa motfrågor i Slack** ("Vad var vår trafik igår?", "Varför ökade sidvisningarna?") – då kör agenten samma script igen och svarar. Det får du inte med en ren CLI-notifier.

---

## Alternativ: umami-notifier

[umami-notifier](https://github.com/schmidfelix/umami-notifier) är en färdig PHP/Composer-CLI som hämtar statistik från Umami och skickar till Slack via Incoming Webhooks. Bra om du vill ha **enklaste vägen** utan eget script.

- **Installation:** `git clone` + `composer install`, konfigurera `.env` (Umami-URL, användarnamn, lösenord, intervall).
- **Sajter:** Kör `php umami sites:add` per webbplats (site id, visningsnamn, Slack webhook-URL).
- **Daglig körning:** `php umami sites:notify` – lägg i crontab eller låt OpenClaw cron köra detta kommando (t.ex. via exec).

**Jämfört med vår OpenClaw-direktlösning:** umami-notifier kräver PHP och att du registrerar varje sajt manuellt; vårt bash-script upptäcker alla webbplatser automatiskt, kräver bara curl + jq, och ger dig motfrågor i Slack. Välj notifier om du föredrar färdig CLI; välj scriptet om du vill ha allt i OpenClaw med möjlighet till uppföljningsfrågor.

---

## Översikt

1. **n8n** triggas en gång per dag (Schedule).
2. Logga in mot **Umami API** → hämta lista över webbplatser → för varje webbplats hämta **stats** för gårdagen.
3. Formatera en textrapport (och valfritt: skicka siffrorna till **LiteLLM** för en kort sammanfattning).
4. Skicka resultatet till **Slack** (eller e-post / spara i MinIO).

---

## Förberedelser

### 1. Umami-inloggning

Du behöver ett användarnamn och lösenord för din Umami-instans (samma som du loggar in på https://umami.theunnamedroads.com med). API:t använder:

- **POST** `https://umami.theunnamedroads.com/api/auth/login`  
  Body: `{ "username": "ditt-användarnamn", "password": "ditt-lösenord" }`  
  Svar: `{ "token": "..." }` – token används i header `Authorization: Bearer <token>` för alla andra anrop.

### 2. n8n-credentials

I n8n (https://n8n.theunnamedroads.com):

- Skapa **Credentials** (eller använd Environment Variables) för:
  - **Umami:** användarnamn + lösenord (eller spara token om du vill cache:a).
  - **Slack:** om du ska posta till en kanal – Bot Token eller Webhook URL.
  - **LiteLLM:** (valfritt) API-nyckel + Base URL för din LiteLLM-instans.

---

## API-anrop du behöver

| Steg | Metod | URL | Beskrivning |
|------|--------|-----|-------------|
| 1 | POST | `https://umami.theunnamedroads.com/api/auth/login` | Body: `{"username":"...","password":"..."}` → spara `token` |
| 2 | GET | `https://umami.theunnamedroads.com/api/websites` | Header: `Authorization: Bearer <token>` → lista med `id`, `name`, `domain` |
| 3 | GET | `https://umami.theunnamedroads.com/api/websites/:websiteId/stats?startAt=...&endAt=...` | `startAt` och `endAt` i **millisekunder** (t.ex. gårdagen 00:00–23:59) |

**Stats-svar** (för en webbplats, ett datumintervall):

```json
{
  "pageviews": 1234,
  "visitors": 456,
  "visits": 789,
  "bounces": 100,
  "totaltime": 123456
}
```

- **pageviews** = sidvisningar  
- **visitors** = unika besökare  
- **visits** = besök (sessions)  
- **bounces** = besök med bara en sidvisning  
- **totaltime** = total tid på sidan (sekunder)

---

## n8n-workflow (steg för steg)

### Trigger

- **Schedule Trigger** – t.ex. `0 8 * * *` (varje dag 08:00).

### Noder (kort)

1. **HTTP Request – Login**  
   - Method: POST  
   - URL: `https://umami.theunnamedroads.com/api/auth/login`  
   - Body: JSON med `username` och `password` (från credentials eller variabler).  
   - Spara utdata (token) för nästa steg.

2. **HTTP Request – Lista webbplatser**  
   - Method: GET  
   - URL: `https://umami.theunnamedroads.com/api/websites`  
   - Header: `Authorization: Bearer {{ $node["Login"].json.token }}`  
   - Utdata: `data`-array med objekt med `id`, `name`, `domain`.

3. **Split Out** (eller **Loop Over Items**)  
   - Iterera över `data` från steg 2 så att du har en item per webbplats.

4. **Code** eller **Set** – räkna ut gårdagens start/slut i ms  
   - Tidszon: Europe/Stockholm (eller din).  
   - Gårdagen 00:00:00 → `startAt`  
   - Idag 00:00:00 → `endAt`  
   - I JavaScript:  
     `const d = new Date(); d.setHours(0,0,0,0); const endAt = d.getTime(); d.setDate(d.getDate()-1); const startAt = d.getTime();`

5. **HTTP Request – Stats per webbplats**  
   - Method: GET  
   - URL: `https://umami.theunnamedroads.com/api/websites/{{ $json.id }}/stats?startAt={{ $json.startAt }}&endAt={{ $json.endAt }}`  
   - Header: `Authorization: Bearer {{ $node["Login"].json.token }}`  
   - (startAt/endAt måste sättas i föregående nod för varje webbplats.)

6. **Merge / Aggregate**  
   - Samla alla stats + webbplatsnamn till en enda text, t.ex.:  
     `[Webbplats] Sidvisningar: X, Besökare: Y, Besök: Z, Bounces: W, Total tid: T sek`

7. **(Valfritt) LiteLLM – Sammanfattning**  
   - HTTP Request till din LiteLLM `/v1/chat/completions` med den samlade texten och en prompt som:  
     "Sammanfatta följande webbtrafik för gårdagen i 2–3 meningar på svenska."

8. **Slack**  
   - Posta den formaterade rapporten (eller AI-sammanfattningen) till en kanal.

---

## Importera färdig workflow

En färdig workflow finns i **`umami/n8n-workflow-daily-umami-summary.json`**. Importera den i n8n (Workflows → Import from File), sätt dina **credentials** (Umami, Slack, ev. LiteLLM) och justera Schedule om du vill.

Efter import:

1. Sätt Umami-användarnamn och lösenord (Credentials eller variabler).
2. Sätt Slack-kanal eller Webhook.
3. (Valfritt) Sätt LiteLLM Base URL och API Key om du använder AI-sammanfattning.
4. Aktivera workflowen.

---

## Tidszon och datum

Umami API använder **timestamp i millisekunder**. För "gårdagen" i Sverige:

- **startAt:** gårdagen 00:00:00 i din tidszon, konverterad till ms.
- **endAt:** idag 00:00:00 i din tidszon, konverterad till ms.

I n8n kan du använda **Code**-nod med `Date` i Europe/Stockholm, eller **Schedule** med timezone så att körningstiden är rätt och du räknar "gårdagen" utifrån körningsdatum.

---

## Felsökning

- **401 på /api/websites eller /stats** → Kontrollera att token från login används i `Authorization: Bearer ...`.
- **Tom data** → Kontrollera att `startAt`/`endAt` är i ms och att tidsintervallet är rätt (gårdagen).
- **Umami nås inte från n8n** → Om n8n och Umami körs på samma server (Coolify), använd samma domän (https://umami.theunnamedroads.com) så att DNS och cert fungerar.

Om du vill kan nästa steg vara att lägga till topp-sidor (pageviews per sida) via `/api/websites/:id/metrics?type=path` för en rikare daglig rapport.

---

## Variant med OpenClaw (mer modernt)

Istället för att n8n postar en färdig text till Slack kan **OpenClaw** skriva och posta sammanfattningen. Då kommer rapporten från din AI-assistent (@tur-openclaw eller motsvarande) – mer naturligt och konsekvent med resten av din Slack-användning.

### Alternativ A: Hybrid (rekommenderat)

n8n hämtar trafikdata från Umami (samma workflow som ovan). I stället för (eller utöver) Slack-noden skickar n8n datan till **OpenClaw webhook** med en prompt; OpenClaw kör en agent-turn, skriver en kort sammanfattning med LiteLLM och postar till Slack.

**Fördelar:** Umami-credentials ligger kvar i n8n. OpenClaw behöver inte anropa Umami själv; den får färdiga siffror och gör det den är bra på – att formulera och leverera.

**Steg:**

1. **Aktivera webhooks i OpenClaw**  
   I OpenClaw-konfiguration (t.ex. `openclaw.json` eller miljövariabler): sätt `hooks.enabled: true` och `hooks.token` till en hemlig token. Dokumentation: [OpenClaw Webhooks](https://docs.openclaw.ai/automation/webhook).

2. **Slack-kanal**  
   Bestäm vilken kanal rapporten ska till (t.ex. `#analytics` eller `#all-tur-ab`). Du behöver kanalens Slack ID (t.ex. `C01234ABCD`) för webhook-anropet – eller använd `channel: "last"` så postas till senast använda kanal.

3. **I n8n:** efter noden **Formatera sammanfattning** (eller en nod som skickar ut rådata), lägg till en **HTTP Request**-nod:
   - **Method:** POST  
   - **URL:** `https://<din-openclaw-domän>/hooks/agent`  
   - **Headers:**  
     - `Authorization: Bearer <hooks.token>` eller `x-openclaw-token: <hooks.token>`  
     - `Content-Type: application/json`  
   - **Body (JSON):**
     ```json
     {
       "message": "Här är gårdagens webbtrafik från Umami:\n\n{{ $json.text }}\n\nSkriv en kort, vänlig sammanfattning på svenska (2–4 meningar) och posta till angiven kanal. Fokusera på trender och vad som sticker ut.",
       "name": "Umami daglig",
       "wakeMode": "now",
       "deliver": true,
       "channel": "slack",
       "to": "channel:C01234ABCD"
     }
     ```
   - Ersätt `{{ $json.text }}` med den formaterade rapporten från föregående nod (eller skicka rå-JSON om du vill att OpenClaw ska tolka siffrorna själv). Ersätt `to` med din kanal-ID.

4. **Valfritt:** Om du använder OpenClaw för leverans behöver du inte längre den gamla **Slack**-noden – du kan ta bort den eller behålla den som backup (t.ex. posta rådata till en annan kanal).

En färdig **n8n-workflow som använder OpenClaw** finns i **`umami/n8n-workflow-daily-umami-openclaw.json`** – den skickar datan till OpenClaw webhook i stället av (eller före) direkt Slack-post.

### Alternativ B: Ren OpenClaw-cron

OpenClaw har inbyggt **cron** (se [OpenClaw Cron Jobs](https://docs.openclaw.ai/cron-jobs)). Du kan schemalägga en isolerad agent-turn som varje morgon får prompten att hämta trafik från Umami och sammanfatta.

Agenten kan använda verktyget **web_fetch** för HTTP-anrop. Då måste Umami-användarnamn och lösenord finnas tillgängliga för agenten (t.ex. i en konfigurerad variabel eller i prompten – inte idealt av säkerhetsskäl). Om du vill använda denna variant:

- Skapa en cron-job med t.ex. `openclaw cron add`:
  - **Schedule:** `0 8 * * *` (08:00), tidszon `Europe/Stockholm`
  - **Session:** isolated  
  - **Message:** en prompt som beskriver att agenten ska anropa Umami API (login → webbplatser → stats för gårdagen), sedan skriva en kort sammanfattning och posta till angiven Slack-kanal.
- Du måste på något sätt ge agenten tillgång till Umami-credentials (t.ex. via en säker tool-config eller miljövariabel som agenten kan referera till).

För de flesta är **hybriden (Alternativ A)** enklare och säkrare: n8n gör API-anropen, OpenClaw gör sammanfattning och leverans.
