# Setup: SEO-processen i OpenClaw

Steg-för-steg så att den best-in-class SEO-processen (planering → keyword → brief → skrivning) börjar fungera i OpenClaw. Du behöver SSH till servern (`tha`), OpenClaw igång och (gärna) Umami redan på plats.

---

## Översikt

| Steg | Vad du gör |
|------|-------------|
| 0 | Kontrollera att Umami-rapport redan fungerar (valfritt men rekommenderat) |
| 1 | Säkerställ att site-repos.json är ifylld med dina GitHub-repon |
| 2 | Kör install-script: kopiera agent-dokument + site-repos in i OpenClaw-containern |
| 3 | Lägg in agent instructions i OpenClaw (kort text som pekar på filerna) |
| 4 | Lägg till cron-jobb för planering, keyword och daglig lägesrapport |
| 5 | Testa med en manuell körning |

---

## Steg 0: Umami (rekommenderat)

Om du redan följt **UMAMI-GENOMFORANDE.md** har du:
- `umami-credentials.json` i `/data/.openclaw/` i containern
- `umami-daily-stats.sh` i `/data/.openclaw/scripts/`
- Cron "Umami daglig rapport" som postar till #all-tur-ab

**Kontroll:** Kör scriptet och se att du får JSON:

```bash
ssh tha 'docker exec $(docker ps --format "{{.Names}}" | grep -i openclaw | head -1) /data/.openclaw/scripts/umami-daily-stats.sh'
```

Om du inte har Umami på plats än, gör det först – se **openclaw/UMAMI-GENOMFORANDE.md**.

---

## Steg 1: site-repos.json

Filen **openclaw/agents/site-repos.json** ska innehålla dina 8 sajter med rätt GitHub-repo per sajt. Den finns redan i repot med dina repon (emilingemarkarlsson/…).

- **Kontroll:** Öppna `openclaw/agents/site-repos.json` och verifiera att `githubRepo` och `contentPath` stämmer för varje sajt.
- Om du ändrar något, spara filen – den kopieras in i containern i Steg 2.

---

## Steg 2: Installera SEO-agentens filer i containern

Från repots rot på din **lokala dator**:

```bash
cd ~/Documents/dev/tur-coolify-setup
chmod +x scripts/openclaw-install-seo-agent.sh
./scripts/openclaw-install-seo-agent.sh
```

Scriptet:
- Hittar OpenClaw-containern på `tha`
- Skapar `/data/.openclaw/agents/`
- Kopierar **SEO-SITE-AGENT.md**, **SEO-PROCESS.md**, **SEO-PLAYBOOK.md** till `/data/.openclaw/agents/`
- Kopierar **site-repos.json** till `/data/.openclaw/site-repos.json`
- Kopierar **openclaw/agents/plans/** (en fil per sajt) om mappen finns – då kan du justera planen per sajt enkelt (se nedan)

**Justera planen per sajt:** Redigera **openclaw/agents/plans/** i repot (t.ex. `theunnamedroads.md`, `finnbodahamnplan.md` – filnamn = umamiName). Kör **`./scripts/openclaw-install-seo-agent.sh`** så synkas planerna till containern. *(OpenClaw UI visar bara Core Files, inte planfilerna – redigera alltid i repot.)* Se **openclaw/agents/plans/README.md** för tabell och mall.

**Vid fel** (t.ex. "Ingen OpenClaw-container"): kör `ssh tha 'docker ps | grep openclaw'` och se till att OpenClaw körs.

---

## Steg 3: Agent instructions i OpenClaw

OpenClaw behöver veta att den här agenten ska läsa reglerna från filerna i containern.

**Alternativ A – klistra in kort instruktion (rekommenderat)**

1. Öppna **openclaw/agents/OPENCLAW-INSTRUCTIONS-SHORT.txt** i repot.
2. Kopiera **hela innehållet**.
3. I OpenClaw (Coolify / OpenClaw Dashboard):
   - Gå till inställningar för din agent (eller den agent som ska hantera SEO).
   - Klistra in texten i **Instructions**, **System prompt** eller motsvarande fält.
   - Spara.

Då kommer agenten vid SEO-uppdrag att läsa `/data/.openclaw/agents/SEO-SITE-AGENT.md` och följa process + playbook.

**Alternativ B – använd hela SEO-SITE-AGENT.md**

Om din OpenClaw inte kan läsa filer från disk vid körning, klistra in **hela innehållet** från **openclaw/agents/SEO-SITE-AGENT.md** som instructions. Nämn i slutet att PROCESS och PLAYBOOK finns i `/data/.openclaw/agents/` om agenten har tillgång till `read`-verktyget.

**Kontroll:** Verifiera i OpenClaw att agenten har tillgång till **read** (och vid behov **exec**/bash) så att den kan läsa filer och köra `umami-daily-stats.sh`. Se OpenClaw-dokumentationen för din version.

---

## Steg 4: Cron-jobb

Du behöver **Slack-kanalens ID** för #all-tur-ab. I denna setup används **C07TJRLTM9C** (byt om du använder annan kanal).

Kör följande på din **lokala dator** (eller via SSH till `tha`). Ersätt `C07TJRLTM9C` om ditt kanal-ID är annat.

**4a) Veckovis SEO-planering (Fas 1) – t.ex. måndag 07:00**

```bash
ssh tha 'docker exec $(docker ps --format "{{.Names}}" | grep -i openclaw | head -1) openclaw cron add \
  --name "SEO planering veckovis" \
  --cron "0 7 * * 1" \
  --tz "Europe/Stockholm" \
  --session isolated \
  --message "Du är SEO-agenten. Läs /data/.openclaw/agents/SEO-SITE-AGENT.md och kör Fas 1 (SEO-planering): content pillars, content gaps, prioriterad sajtlista. Använd Umami (script eller API) och site-repos. Rapportera resultatet till Slack (#all-tur-ab) med tydlig struktur: pillars per sajt, gap-lista, rekommenderad fokus-sajtlista för veckan." \
  --announce \
  --channel slack \
  --to "channel:C07TJRLTM9C"'
```

**4b) Veckovis keyword-strategi (Fas 2) – t.ex. tisdag 07:30**

```bash
ssh tha 'docker exec $(docker ps --format "{{.Names}}" | grep -i openclaw | head -1) openclaw cron add \
  --name "SEO keyword-strategi veckovis" \
  --cron "30 7 * * 2" \
  --tz "Europe/Stockholm" \
  --session isolated \
  --message "Du är SEO-agenten. Läs /data/.openclaw/agents/SEO-SITE-AGENT.md och kör Fas 2 (keyword-strategi) för de sajter som prioriterades i senaste planeringsrapporten. Använd web_search för research; bygg keyword-backlog med prioritet. Skicka keyword-backlog till Slack (#all-tur-ab)." \
  --announce \
  --channel slack \
  --to "channel:C07TJRLTM9C"'
```

**4c) Veckovis artikel-förslag – t.ex. onsdag 08:00**

Skickar 1–5 konkreta artikel-förslag till Slack (sajt, keyword, förslag på titel, prioritet). Därifrån kan du skriva *"producera artikel för [sajt] om [keyword]"* eller senare använda en Publicera-knapp (se SLACK-PUBLISH-SETUP.md).

```bash
ssh tha 'docker exec $(docker ps --format "{{.Names}}" | grep -i openclaw | head -1) openclaw cron add \
  --name "SEO artikel-förslag veckovis" \
  --cron "0 8 * * 3" \
  --tz "Europe/Stockholm" \
  --session isolated \
  --message "Du är SEO-agenten. Läs /data/.openclaw/agents/SEO-SITE-AGENT.md och SEO-ARTICLE-SUGGESTIONS.md. Utifrån senaste planering och keyword-backlog: skicka 1–5 artikel-förslag till Slack (#all-tur-ab) – per förslag: sajt (umamiName), domain, keyword, förslag på titel, prioritet, kort motivering. Ett förslag per meddelande eller tydlig numrering." \
  --announce \
  --channel slack \
  --to "channel:C07TJRLTM9C"'
```

**4d) Daglig lägesrapport (analys av alla sajter)**

Om du redan har "Umami daglig rapport" (08:00) behöver du inte nödvändigtvis en till. Om du vill ha en **SEO-lägesrapport** (trafik + topp-sidor + korta förslag) på en annan tid:

```bash
ssh tha 'docker exec $(docker ps --format "{{.Names}}" | grep -i openclaw | head -1) openclaw cron add \
  --name "SEO daglig lägesrapport" \
  --cron "0 8 * * *" \
  --tz "Europe/Stockholm" \
  --session isolated \
  --message "Analysera alla sajter via Umami (kör /data/.openclaw/scripts/umami-daily-stats.sh) och site-repos. Rapportera till Slack (#all-tur-ab): per sajt – senaste 30 dagar visitors/pageviews, top 5 pages, en rad med rekommendation (gap eller nästa steg). Håll det koncist." \
  --announce \
  --channel slack \
  --to "channel:C07TJRLTM9C"'
```

**Lista cron-jobb:**

```bash
ssh tha 'docker exec $(docker ps --format "{{.Names}}" | grep -i openclaw | head -1) openclaw cron list'
```

Notera jobb-ID (t.ex. UUID) om du vill köra ett jobb manuellt (Steg 5).

---

## Steg 5: Testa

**Kör planeringen manuellt (Fas 1):**

Hämta jobb-ID från `openclaw cron list` (t.ex. för "SEO planering veckovis"), ersätt `<JOB_ID>` nedan:

```bash
ssh tha 'docker exec $(docker ps --format "{{.Names}}" | grep -i openclaw | head -1) openclaw cron run <JOB_ID> --force --expect-final --timeout 120000'
```

Du ska inom några sekunder/minuter få en post i **#all-tur-ab** med pillars, gaps och prioriterad sajtlista (eller ett felmeddelande om något saknas – t.ex. credentials).

**Testa från Slack:**

Skriv i #all-tur-ab (eller där OpenClaw svarar):

- *"@tur-openclaw analysera sajterna"*
- *"Keyword-strategi för theunnamedroads"*

Agenten ska då läsa SEO-SITE-AGENT.md och utföra rätt fas, och svara i kanalen.

---

## Checklista

- [ ] **Steg 0:** Umami script + credentials fungerar (valfritt)
- [ ] **Steg 1:** site-repos.json granskad och korrekt
- [ ] **Steg 2:** `./scripts/openclaw-install-seo-agent.sh` kört utan fel
- [ ] **Steg 3:** OPENCLAW-INSTRUCTIONS-SHORT.txt inlagd som agent instructions
- [ ] **Steg 4:** Minst ett cron-jobb tillagt (planering och/eller keyword och/eller daglig rapport)
- [ ] **Steg 5:** Manuell cron run eller Slack-test genomfört; rapport/fråga besvarad i #all-tur-ab

---

## Felsökning

| Problem | Åtgärd |
|--------|--------|
| Install-script: "Ingen OpenClaw-container" | `ssh tha 'docker ps \| grep openclaw'` – starta OpenClaw i Coolify om den inte körs. |
| Install-script: "Saknar site-repos.json" | Skapa från `openclaw/agents/site-repos.example.json`, döp till `site-repos.json` och fyll i. |
| Agenten svarar inte med SEO-innehåll | Kontrollera att instructions är inlagda och att agenten har **read**-åtkomst till `/data/.openclaw/agents/`. |
| "openclaw cron add" finns inte | Använd OpenClaw Gateway API eller Coolify scheduled tasks enligt din version; anpassa meddelandena från 4a–4c. |
| Inget i Slack / not_in_channel | Använd samma kanal som Umami-rapporten (#all-tur-ab, C07TJRLTM9C). Se UMAMI-GENOMFORANDE.md om boten inte är i kanalen. |
| Agenten hittar inte site-repos | Efter install: filen ligger i `/data/.openclaw/site-repos.json`. Instructions säger att agenten ska läsa den. |

---

## Efter setup

- **Artikel-förslag:** Cron "SEO artikel-förslag veckovis" (4c) skickar förslag till Slack. Du kan också skriva *"artikel-förslag för [sajt]"*. För att publicera: skriv *"producera artikel för [sajt] om [keyword]"* – eller koppla en Publicera-knapp (se **openclaw/SLACK-PUBLISH-SETUP.md**).
- **Artiklar:** Be agenten om en **content brief** för en sajt + keyword, godkänn i Slack, be sedan om **"producera artikel"** – då följer den playbook och skickar draft till Slack.
- **Git:** Om du inte satt upp Git i OpenClaw pushar du själv efter att du kopierat draft från Slack till rätt repo. Om du vill att agenten ska pusha: konfigurera SSH eller PAT i containern enligt NASTA-STEG.md.
- **Uppdatera filer:** Om du ändrar SEO-SITE-AGENT.md, SEO-PROCESS.md eller SEO-PLAYBOOK.md i repot, kör **igen** `./scripts/openclaw-install-seo-agent.sh` så att containern får senaste versionen.
