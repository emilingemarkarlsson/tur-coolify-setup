# Kör dessa steg – SEO-agenten igång

Jag kunde inte köra SSH/cron åt dig. Gör följande i ordning.

---

## Steg 1: Installera filer i OpenClaw-containern (terminal)

Öppna terminal, gå till repot och kör:

```bash
cd ~/Documents/dev/tur-coolify-setup
chmod +x scripts/openclaw-install-seo-agent.sh
./scripts/openclaw-install-seo-agent.sh
```

**Förväntat:** "Klar. Filer i containern: ..."  
**Om fel:** T.ex. "Ingen OpenClaw-container" → kontrollera att OpenClaw körs på servern (`ssh tha 'docker ps | grep openclaw'`).

---

## Steg 2: Klistra in agent instructions i OpenClaw (du måste göra detta manuellt)

1. Öppna **Coolify** (eller OpenClaw Dashboard) och gå till din **OpenClaw-tjänst**.
2. Hitta inställningar för **Agent** / **Instructions** / **System prompt** (det fält där man anger hur agenten ska bete sig).
3. Öppna filen **`openclaw/agents/OPENCLAW-INSTRUCTIONS-SHORT.txt`** i denna repo.
4. **Kopiera hela innehållet** (Ctrl+A, Ctrl+C).
5. **Klistra in** i Instructions-fältet i OpenClaw (ersätt eller lägg till så att detta är det som gäller för SEO).
6. **Spara** (t.ex. "Save" / "Update").

---

## Steg 3: Lägg till cron-jobb (terminal)

Kör **ett kommando i taget** i terminal. Använd kanal-ID **C07TJRLTM9C** för #all-tur-ab (byt om du har annat kanal-ID).

**3a) Veckovis planering (måndag 07:00):**

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

**3b) Veckovis keyword (tisdag 07:30):**

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

**3c) Daglig SEO-lägesrapport (08:00):**

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

**Kontrollera att jobben finns:**

```bash
ssh tha 'docker exec $(docker ps --format "{{.Names}}" | grep -i openclaw | head -1) openclaw cron list'
```

Notera ett **JOB_ID** (UUID) om du vill köra ett jobb manuellt i Steg 4.

---

## Steg 4: Testa (valfritt)

**Alternativ A – kör planeringen nu:**

Ersätt `<JOB_ID>` med ID för "SEO planering veckovis" från `openclaw cron list`:

```bash
ssh tha 'docker exec $(docker ps --format "{{.Names}}" | grep -i openclaw | head -1) openclaw cron run <JOB_ID> --force --expect-final --timeout 120000'
```

**Alternativ B – testa från Slack:**

Skriv i #all-tur-ab:

- `@tur-openclaw analysera sajterna`

Du ska få svar med trafik/analys i kanalen.

---

## Sammanfattning

| Steg | Vad | Vem |
|------|-----|-----|
| 1 | Köra install-script i terminal | Du |
| 2 | Klistra in OPENCLAW-INSTRUCTIONS-SHORT.txt i OpenClaw UI | Du |
| 3 | Köra de tre `openclaw cron add`-kommandona i terminal | Du |
| 4 | Testa med cron run eller Slack | Du |

Jag kunde inte göra steg 1 och 3 åt dig eftersom de kräver SSH till din server (tha).
