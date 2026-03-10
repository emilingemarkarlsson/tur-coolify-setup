# Genomförande: Umami daglig rapport + motfrågor (OpenClaw direkt)

Följ stegen i ordning. Du behöver: SSH till servern (`tha`), ditt Umami-användarnamn och lösenord, och Slack-kanalens ID.

---

## Steg 1: Hämta Slack-kanalens ID

Du behöver kanal-ID för den Slack-kanal där rapporten ska postas (t.ex. `#analytics` eller `#all-tur-ab`).

**Sätt A – från Slack (webb/app):**
1. Högerklicka på kanalen → **Visa kanalinformation** (eller **View channel details**).
2. Scrolla ner – **Kanal-ID** visas längst ner (format: `C01234ABCD`).

**Sätt B – från kanal-URL:**
- Öppna kanalen i webbläsaren. URL:en ser ut ungefär så här:  
  `https://app.slack.com/client/WORKSPACE_ID/C01234ABCD`  
- Den sista delen (`C01234ABCD`) är kanal-ID.

**Skriv upp värdet** – du använder det i Steg 5 (utan prefixet `channel:`).

---

## Steg 2: Skapa Umami-credentials i OpenClaw-containern

På din **lokala dator** (från repots rot). Ersätt `DITT_UMAMI_ANVÄNDARNAMN` och `DITT_UMAMI_LÖSENORD` med samma uppgifter du använder för att logga in på https://umami.theunnamedroads.com.

```bash
# Hitta OpenClaw-containern
ssh tha 'docker ps --format "{{.Names}}" | grep -i openclaw | head -1'
```

Notera container-namnet (t.ex. `openclaw-xxxx`). Sätt det som CONTAINER och skapa credentials-filen:

```bash
CONTAINER=$(ssh tha 'docker ps --format "{{.Names}}" | grep -i openclaw | head -1')
ssh tha "docker exec $CONTAINER sh -c 'mkdir -p /data/.openclaw && echo \"{\\\"username\\\":\\\"DITT_UMAMI_ANVÄNDARNAMN\\\",\\\"password\\\":\\\"DITT_UMAMI_LÖSENORD\\\"}\" > /data/.openclaw/umami-credentials.json'"
```

**Viktigt:** Ersätt `DITT_UMAMI_ANVÄNDARNAMN` och `DITT_UMAMI_LÖSENORD` med dina riktiga uppgifter. Om lösenordet innehåller citattecken (`"`) eller backslash (`\`) kan kommandot bryta – använd då **Alternativ** nedan (skapa fil lokalt och kopiera in).

**Alternativ – skapa filen lokalt och kopiera in:**

Skapa en fil `umami-credentials.json` (lägg den **inte** i git):

```json
{"username":"ditt_användarnamn","password":"ditt_lösenord"}
```

Kopiera in i containern:

```bash
CONTAINER=$(ssh tha 'docker ps --format "{{.Names}}" | grep -i openclaw | head -1')
scp umami-credentials.json tha:/tmp/
ssh tha "docker cp /tmp/umami-credentials.json $CONTAINER:/data/.openclaw/umami-credentials.json"
ssh tha "rm /tmp/umami-credentials.json"
```

---

## Steg 3: Installera scriptet och jq

Från repots rot på din dator:

```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/openclaw-install-umami-script.sh
```

Scriptet kopierar `umami-daily-stats.sh` in i containern och försöker installera `jq` om det saknas. Om något steg misslyckas, se [Felsökning](#felsökning) nedan.

---

## Steg 4: Testa att scriptet fungerar

Kör scriptet manuellt inifrån containern. Du ska få JSON med trafik för gårdagen.

```bash
CONTAINER=$(ssh tha 'docker ps --format "{{.Names}}" | grep -i openclaw | head -1')
ssh tha "docker exec $CONTAINER /data/.openclaw/scripts/umami-daily-stats.sh"
```

**Förväntat:** En rad JSON med `date`, `websites`, `pageviews`, `visitors` osv.  
**Om du får `"error":"Missing Umami credentials"`** – gå tillbaka till Steg 2.  
**Om du får `"error":"jq required"`** – installera jq i containern, t.ex.:

```bash
ssh tha "docker exec $CONTAINER apk add --no-cache jq"
# eller om det är Debian/Ubuntu-baserad:
# ssh tha "docker exec $CONTAINER apt-get update && apt-get install -y jq"
```

---

## Steg 5: Lägg till OpenClaw cron-jobbet

OpenClaw ska varje morgon (08:00, Europe/Stockholm) köra agenten med ett meddelande som säger att den ska köra scriptet, läsa JSON och posta en sammanfattning till Slack.

**Om du har OpenClaw CLI** (på servern eller i containern):

Kör (ersätt `SLACK_KANAL_ID` med värdet från Steg 1, t.ex. `C01234ABCD`):

```bash
ssh tha 'docker exec $(docker ps --format "{{.Names}}" | grep -i openclaw | head -1) openclaw cron add \
  --name "Umami daglig rapport" \
  --cron "0 8 * * *" \
  --tz "Europe/Stockholm" \
  --session isolated \
  --message "Kör kommandot: /data/.openclaw/scripts/umami-daily-stats.sh och läs JSON från stdout. Skriv en kort sammanfattning på svenska (2–4 meningar) av trafiken för gårdagen. Formatera för Slack: använd *fetstil* för webbplatsnamn och siffror, en rad eller bullet per webbplats, inled med en tydlig rubrik (t.ex. 📊 Umami – gårdagen). Håll det lättläst och koncist." \
  --announce \
  --channel slack \
  --to "channel:SLACK_KANAL_ID"'
```

**Om OpenClaw CLI inte finns** i containern kan du lägga in jobbet via OpenClaw Gateway API eller genom att redigera cron-filen när Gateway är stoppad (se [OpenClaw Cron Jobs](https://docs.openclaw.ai/cron-jobs)). Alternativt: be din Coolify/OpenClaw-setup att exponera CLI eller använd deras sätt att lägga till scheduled tasks.

**Kontrollera att jobbet finns:**

```bash
ssh tha 'docker exec $(docker ps --format "{{.Names}}" | grep -i openclaw | head -1) openclaw cron list'
```

---

## Steg 6: Säkerställ att agenten får köra script och läsa filer

OpenClaw-agenten måste ha **exec** (eller **bash**) och **read** tillåtna så att den kan:
- köra `/data/.openclaw/scripts/umami-daily-stats.sh`
- läsa credentials vid behov (scriptet läser själv, men vid motfrågor kan agenten behöva förstå var datan kommer ifrån).

Kontrollera i OpenClaw-konfigurationen (t.ex. `openclaw.json` eller Coolify-miljö) att verktyg som `exec`/`bash` och `read` inte är blockerade. Se [OpenClaw docs – tools](https://docs.openclaw.ai/) för din version.

---

## Testa manuellt (köra rapporten nu)

Du behöver inte vänta till 08:00. Kör jobbet med **force** så det körs omedelbart:

```bash
ssh tha 'docker exec $(docker ps --format "{{.Names}}" | grep -i openclaw | head -1) openclaw cron run aa1c7fb5-09e7-44be-9ee4-a2a3bafd0085 --force --expect-final --timeout 120000'
```

(Ersätt jobb-ID om du skapat ett nytt cron-job med annat ID – hämta med `openclaw cron list`.)

Du ska då få en post i Slack-kanalen inom några sekunder. Om du inte ser något, kontrollera att kanal-ID:t stämmer och att OpenClaw har behörighet att posta i kanalen.

---

## Vad du ser i OpenClaw UI

- **Cron / Scheduled tasks** – Om din OpenClaw-instans (t.ex. Coolify eller OpenClaw Dashboard) har en sektion för schemalagda jobb ser du **"Umami daglig rapport"** i listan med nästa körning (08:00 Europe/Stockholm).
- **Körhistorik** – Vissa setup har **cron run history** (t.ex. `openclaw cron runs --id <job-id>`) eller loggar där du ser att jobbet körts och om det lyckades.
- **Slack** – Det viktigaste: själva rapporten och motfrågor syns i **Slack-kanalen** (#all-tur-ab, ID C07TJRLTM9C). OpenClaw postar där; det är inte alltid att varje cron-run syns tydligt i OpenClaw UI, men resultatet finns i Slack.

Om du inte hittar cron i UI:t kan du alltid lista och köra från terminalen:  
`openclaw cron list` och `openclaw cron run <job-id> --force --expect-final`.

---

## Motfrågor i Slack

När rapporten körts (eller när som helst) kan du i Slack skriva till OpenClaw t.ex.:

- "Vad var vår trafik igår?"
- "Sammanfatta Umami för igår"
- "Varför ökade sidvisningarna på [webbplats]?"

Agenten ska då kunna köra samma script och svara utifrån resultatet. Om den inte gör det, kontrollera att exec/read är tillåtna (Steg 6).

---

## Felsökning

| Problem | Åtgärd |
|--------|--------|
| `openclaw-install-umami-script.sh` hittar inte container | Kör `ssh tha 'docker ps \| grep openclaw'` – OpenClaw måste vara igång. |
| `Missing Umami credentials` | Skapa `/data/.openclaw/umami-credentials.json` i containern (Steg 2). |
| `jq required` | Installera jq i containern: `docker exec <container> apk add jq` eller `apt-get install jq`. |
| `Umami login failed` | Kontrollera användarnamn/lösenord; kontrollera att containern når `https://umami.theunnamedroads.com`. |
| `openclaw cron add` finns inte | Använd Gateway API eller redigera cron store enligt OpenClaw-dokumentationen. |
| Cron körs inte klockan 08:00 | Kontrollera tidszon `Europe/Stockholm` och att OpenClaw Gateway körs kontinuerligt. |
| Inget i Slack / fel `not_in_channel` | OpenClaw-boten måste vara med i kanalen. **Enklast:** använd en kanal där boten redan finns (t.ex. #all-tur-ab). Uppdatera cron: `openclaw cron edit <job-id> --channel slack --to "channel:C07TJRLTM9C"`. Om du vill använda en annan kanal: lägg till appen där (Kanal → Integreringar → Lägg till appar → tur-openclaw). På Slack Free kan app-gränsen hindra – då är en befintlig kanal säkrast. |

---

## Checklista

- [ ] Steg 1: Slack-kanal-ID noterat
- [ ] Steg 2: `umami-credentials.json` skapad i `/data/.openclaw/` i containern
- [ ] Steg 3: `./scripts/openclaw-install-umami-script.sh` kört
- [ ] Steg 4: `umami-daily-stats.sh` testat och ger JSON
- [ ] Steg 5: Cron-jobbet "Umami daglig rapport" tillagt
- [ ] Steg 6: exec/read tillåtna för agenten

När allt är kryssat ska du få en daglig rapport i Slack och kunna ställa motfrågor.

---

## Säkerhet

- Ta bort credentials från serverns `/tmp` efter att du kopierat in dem i containern: `ssh tha 'rm -f /tmp/umami-credentials.json'`.
- Credentials finns nu **bara** i containern under `/data/.openclaw/umami-credentials.json`. Backa inte upp den filen till opna platser.
