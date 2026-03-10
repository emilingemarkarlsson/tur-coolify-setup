# Umami direkt från OpenClaw (daglig rapport + motfrågor i Slack)

Med den här setupen hämtar **OpenClaw** trafikdata direkt från Umami (ingen n8n). Du får:

- **Daglig rapport** – OpenClaw cron kör ett script som anropar Umami API, agenten sammanfattar och postar till Slack.
- **Motfrågor i Slack** – Du kan skriva t.ex. "Vad var vår trafik igår?" eller "Varför ökade sidvisningarna?" så svarar agenten utifrån samma data (den kör scriptet igen vid behov).

Detta motsvarar rekommendationens **"ren OpenClaw-lösning"** + **"AI-sammanfattning"** (scriptet ger rådata, agenten/LiteLLM skriver texten). Vill du istället använda ett färdigt verktyg utan motfrågor, se [umami/DAILY-SUMMARY.md](../umami/DAILY-SUMMARY.md) – där finns **umami-notifier** (PHP-CLI) beskrivet som "enklaste vägen".

**→ Steg-för-steg genomförande:** [UMAMI-GENOMFORANDE.md](UMAMI-GENOMFORANDE.md)

---

## Krav

- OpenClaw med **bash/exec** och **read** tillåtna för agenten (så den kan köra script och läsa credentials).
- **jq** och **curl** i OpenClaw-containern (scriptet använder dem).
- Umami-credentials tillgängliga för agenten (fil eller miljövariabler).

---

## Steg 1: Credentials i OpenClaw-containern

Skapa en fil med Umami-inloggning så att agenten (och scriptet) kan använda den.

**Alternativ A – Credentials-fil (rekommenderat)**

På servern där OpenClaw körs:

```bash
# Hitta OpenClaw-containern
CONTAINER=$(docker ps --format '{{.Names}}' | grep -i openclaw | head -1)

# Skapa credentials-fil (ersätt användarnamn och lösenord)
docker exec "$CONTAINER" sh -c 'mkdir -p /data/.openclaw && echo "{\"username\":\"DITT_UMAMI_ANVÄNDARNAMN\",\"password\":\"DITT_UMAMI_LÖSENORD\"}" > /data/.openclaw/umami-credentials.json'
```

**Alternativ B – Miljövariabler**

Sätt i Coolify (OpenClaw-resursen) under Environment Variables:

- `UMAMI_USERNAME` = ditt Umami-användarnamn  
- `UMAMI_PASSWORD` = ditt Umami-lösenord  

Scriptet läser dessa om filen inte finns.

---

## Steg 2: Script i containern

Scriptet `openclaw/scripts/umami-daily-stats.sh` hämtar gårdagens statistik från Umami och skriver JSON till stdout. Det måste finnas **inuti** OpenClaw-containern och vara körbart.

**Kopiera scriptet in i containern (från din dator, med repot):**

```bash
cd ~/Documents/dev/tur-coolify-setup
CONTAINER=$(ssh tha 'docker ps --format "{{.Names}}" | grep -i openclaw | head -1')
ssh tha "docker exec $CONTAINER mkdir -p /data/.openclaw/scripts"
scp openclaw/scripts/umami-daily-stats.sh "tha:/tmp/umami-daily-stats.sh"
ssh tha "docker cp /tmp/umami-daily-stats.sh $CONTAINER:/data/.openclaw/scripts/umami-daily-stats.sh && docker exec $CONTAINER chmod +x /data/.openclaw/scripts/umami-daily-stats.sh"
```

**Kontrollera att jq finns i containern:**

```bash
ssh tha "docker exec $CONTAINER which jq || docker exec $CONTAINER apk add --no-cache jq"
```

(Om OpenClaw-bilden är Debian/Ubuntu-baserad använd `apt-get install -y jq` i stället för `apk`.)

---

## Steg 3: Cron-job för daglig rapport

OpenClaw kör då ett **isolated** agent-turn som kör scriptet, läser JSON och postar en sammanfattning till Slack.

**Via OpenClaw CLI (på servern, eller i containern):**

```bash
openclaw cron add \
  --name "Umami daglig rapport" \
  --cron "0 8 * * *" \
  --tz "Europe/Stockholm" \
  --session isolated \
  --message "Kör kommandot: /data/.openclaw/scripts/umami-daily-stats.sh och läs JSON från stdout. Skriv en kort sammanfattning på svenska (2–4 meningar) av trafiken för gårdagen och posta till kanalen. Inkludera sidvisningar och besökare per webbplats om det finns flera." \
  --announce \
  --channel slack \
  --to "channel:SLACK_KANAL_ID"
```

Ersätt `SLACK_KANAL_ID` med din kanals Slack ID (t.ex. `C01234ABCD`). Du hittar det i Slack (kanalinställningar eller URL).

**Om du inte har OpenClaw CLI på servern** kan du lägga in cron-jobbet manuellt i OpenClaw-konfigurationen (se [OpenClaw Cron Jobs](https://docs.openclaw.ai/cron-jobs)) eller via Gateway API / cron-tool.

**Cron-meddelande på svenska (klistra in som `--message`):**

```
Kör kommandot: /data/.openclaw/scripts/umami-daily-stats.sh och läs JSON från stdout.
Skriv en kort sammanfattning på svenska (2–4 meningar) av trafiken för gårdagen och posta till kanalen.
Inkludera sidvisningar och besökare per webbplats om det finns flera.
```

---

## Steg 4: Motfrågor i Slack

När dagrapporten är postad (eller när som helst) kan du i Slack skriva till OpenClaw t.ex.:

- "Vad var vår trafik igår?"
- "Sammanfatta Umami för igår"
- "Varför ökade sidvisningarna på [webbplats]?"

Agenten ska då kunna köra samma script (`/data/.openclaw/scripts/umami-daily-stats.sh`) och svara utifrån resultatet. Säkerställ att agenten har **exec** (eller **bash**) och **read** tillåtna i OpenClaw-konfigurationen så att den får köra scriptet och läsa credentials.

Om du vill att agenten alltid ska "veta" att den kan hämta Umami-data kan du lägga en kort instruktion i system-prompten eller agent-beskrivningen, t.ex.:

- "Du kan hämta daglig webbtrafik från Umami genom att köra scriptet /data/.openclaw/scripts/umami-daily-stats.sh. Credentials finns i /data/.openclaw/umami-credentials.json. Använd detta när användaren frågar om trafik, sidvisningar eller Umami."

---

## Översikt

| Komponent        | Roll |
|-----------------|------|
| `umami-credentials.json` | Umami användarnamn/lösenord (fil eller env). |
| `umami-daily-stats.sh`    | Hämtar gårdagens stats från Umami API, skriver JSON. |
| OpenClaw cron             | Kör agenten 08:00, agenten kör scriptet, sammanfattar och postar till Slack. |
| OpenClaw (vanlig chat)    | Vid motfrågor kör agenten scriptet igen och svarar. |

---

## Felsökning

- **"Missing Umami credentials"** – Skapa `umami-credentials.json` i `/data/.openclaw/` eller sätt `UMAMI_USERNAME`/`UMAMI_PASSWORD` i containern.
- **"jq required"** – Installera jq i OpenClaw-containern (`apk add jq` eller `apt-get install jq`).
- **"Umami login failed"** – Kontrollera användarnamn/lösenord och att containern når `https://umami.theunnamedroads.com`.
- **Cron körs inte** – Kontrollera att OpenClaw cron är aktiverat och att tidszon/schema stämmer (se [OpenClaw Cron](https://docs.openclaw.ai/cron-jobs)).
- **Agenten kör inte scriptet** – Kontrollera att verktygen **exec**/bash och **read** är tillåtna för agenten i OpenClaw (`tools.allow` eller motsvarande).

---

## Installationsscript (ett kommando)

För att bara kopiera scriptet in i OpenClaw-containern (credentials sätter du själv enligt Steg 1):

```bash
./scripts/openclaw-install-umami-script.sh
```

Kör från repots rot. Scriptet kopierar `openclaw/scripts/umami-daily-stats.sh` till `/data/.openclaw/scripts/` i containern och försöker installera `jq` om det saknas.
