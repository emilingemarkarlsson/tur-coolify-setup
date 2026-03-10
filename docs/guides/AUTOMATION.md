# Automatisera din setup – max ut av stacken

Din stack (Coolify, LiteLLM, Open WebUI, OpenClaw, n8n, MinIO, Langflow) kan automatiseras på flera nivåer. Här är en strukturerad guide.

---

## 1. n8n som automationsnav (rekommenderat först)

**n8n** (n8n.theunnamedroads.com) är din workflow-motor. Använd den för att koppla ihop tjänster och AI utan att skriva kod.

### Koppla n8n till resten

| Vad | Hur |
|-----|-----|
| **LiteLLM (AI)** | I n8n: **HTTP Request** eller **OpenAI**-nod → Base URL = din LiteLLM-URL (`https://.../v1`), API Key = LiteLLM master key. Då kan workflows anropa samma modeller som Open WebUI/OpenClaw. |
| **Slack** | n8n: **Slack**-nod (OAuth eller Bot Token). Trigga på nya meddelanden, skicka svar, posta till kanaler. |
| **MinIO** | n8n: **S3**-nod (MinIO är S3-kompatibel). Läs/skriv filer, backup, arkiv. |
| **Webhooks** | n8n: **Webhook**-trigger. Anropas från hemsidor (t.ex. kontaktformulär), andra tjänster eller cron. |

### Automatiseringar att börja med

- **Kontaktformulär → Slack + AI-sammanfattning**  
  Webhook från webb → n8n → (valfritt: LiteLLM för att sammanfatta) → posta till #all-tur-contactforms eller liknande.
- **Daglig/weekly sammanfattning**  
  Schedule-trigger i n8n → hämta data (API, MinIO, databas) → LiteLLM för sammanfattning → skicka till Slack eller e-post.
- **Filer till MinIO + notis**  
  Webhook eller Schedule → n8n → spara till MinIO → notis i Slack.
- **Slack-kommandon**  
  Slack trigger (slash command eller @mention till bot) → n8n → LiteLLM eller annan logik → svar tillbaka i Slack (komplement till OpenClaw när du vill enklare, fasta flöden).

---

## 2. Coolify Scheduled Tasks

I Coolify kan du köra **scheduled tasks** (cron-liknande) på resursnivå eller projektnivå.

- **Backup** – t.ex. periodisk export av n8n-workflows eller databasdump (om du har sådana resurser).
- **Health check** – anropa en enkel endpoint eller ett script som verifierar att tjänster svarar; vid fel kan du få notis (om du kopplat notifiering).
- **Rensa loggar/cache** – om du har script som rensar gamla loggar eller temporära filer.

Öppna **Coolify** → **Projekt** → **Scheduled Tasks** (eller per resurs) och lägg in cron-uttryck + kommando (t.ex. curl eller `docker exec ...`).

---

## 3. Cron på servern (via SSH)

För saker som inte Coolify hanterar, använd **cron** på Hetzner-servern.

```bash
ssh tha
crontab -e
```

**Förslag:**

| Syfte | Cron | Kommando (kör från rätt katalog om det krävs) |
|-------|------|-----------------------------------------------|
| **Server-health** | Varje morgon | `0 7 * * * /path/to/scripts/server-health.sh >> /var/log/server-health.log 2>&1` |
| **Docker-cleanup** | Veckovis | `0 3 * * 0 /path/to/scripts/docker-cleanup.sh` |
| **OpenClaw-config efter deploy** | Efter deploy/omstart av OpenClaw | `./scripts/openclaw-apply-config.sh` (från repots rot) kör både Slack-kanaler och LiteLLM-modell i ett steg. |

Se även [MONITORING.md](MONITORING.md) för health-check och notiser.

---

## 4. LiteLLM – kostnad och nycklar

- **Virtuella nycklar** – skapa en nyckel per tjänst (Open WebUI, OpenClaw, n8n) i LiteLLM UI så du ser användning per källa.
- **Budget/spend** – sätt budget per nyckel eller totalt så du får varningar och kan styra kostnader.
- **Loggar** – använd LiteLLM-loggar för att se vilka modeller som anropas och från vilken källa.

Detta är inte “automation” i sig men gör att du kan **automatisera med AI** (via n8n/OpenClaw) utan att tappa kollen på kostnad.

---

## 5. Översikt: vad du redan har

| Komponent | Roll | Automatisering |
|-----------|------|----------------|
| **LiteLLM** | En API för alla modeller | Anropas av Open WebUI, OpenClaw, n8n |
| **Open WebUI** | Chat UI | Manuell användning; kan kompletteras med n8n för automatiserade rapporter/chat-flöden |
| **OpenClaw** | Slack-agent + kod/agent | Redan “automatiserat” i Slack; kan utökas med fler kanaler/kommandon |
| **n8n** | Workflows | **Här** bygger du triggers (schedule, webhook, Slack) + steg (LiteLLM, MinIO, Slack, HTTP). |
| **MinIO** | Lagring | Backup, filpipeliner, arkiv från n8n eller andra tjänster |
| **Langflow** | Flöden/agents | Kan anropas från n8n eller andra tjänster för mer avancerade flöden |

---

## 6. Prioriterad ordning

1. **n8n + LiteLLM** – en workflow som triggas (t.ex. Schedule eller Webhook), anropar LiteLLM, och skickar resultat till Slack eller sparar i MinIO. Då har du en “AI-automation” från start.
2. **n8n + Slack** – Slack-trigger eller webhook som postar till en kanal; koppla sedan in LiteLLM för svar eller sammanfattning.
3. **Coolify Scheduled Tasks** – backup eller enkel health check.
4. **Cron på servern** – server-health, docker-cleanup, ev. backup-script.
5. **LiteLLM-nycklar och budget** – så du kan automatisera mer utan att tappa kontroll på kostnad.

När du har en eller två n8n-workflows som använder LiteLLM och Slack har du redan fått ut mycket av setupen; bygg sedan vidare utifrån behov (kontaktformulär, rapporter, filer, notiser).
