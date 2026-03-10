# SEO + trafik med OpenClaw – modern automatisering

Du har redan: **Umami** (trafikdata), **OpenClaw** (cron + agent + Slack), och flera sajter (finnbodahamnplan, theunnamedroads, thehockeyanalytics, m.fl.). Här är ett sätt att använda det för att **dagligen förbättra SEO och generera mer trafik** på ett modernt sätt.

---

## Idén i kort

1. **Data först** – Umami visar vad som faktiskt får trafik och vad som inte gör det. OpenClaw kan redan hämta den datan (scriptet du kör).
2. **Agenten prioriterar** – Utifrån siffror (sidvisningar, bounces, tid på sidan) kan agenten föreslå: "Fokusera på X", "Förbättra meta på Y", "Skriv inlägg om Z".
3. **Åtgärder** – Beroende på hur dina sajter är byggda kan det vara: **förslag i Slack** (du gör ändringar manuellt), **genererad text** (meta, rubriker, inläggsutkast) som du klistrar in, eller **direkt API-uppdatering** om du har CMS/API.

---

## Extremt modernt flöde (målbild)

```
Umami (vem får trafik?) 
    → OpenClaw cron (daglig körning)
    → Agent: analyserar data + hämtar sida/URL om behövs (web_fetch)
    → Agent: genererar SEO-förbättringar (titlar, beskrivningar, förslag)
    → Leverans: Slack (daglig SEO-brief) och/eller API till sajt (om du har det)
```

- **En källa till sanning** – Umami. Ingen gissning, du förbättrar det som redan har lite trafik eller det som borde ha men inte har.
- **En agent** – OpenClaw. Samma plats som Umami-rapporten: cron, script, Slack. Inga extra “SEO-verktyg” om du inte vill.
- **Återanvändning** – Samma credentials, samma kanal (#all-tur-ab), nya cron-jobb för “SEO-daglig” och ev. “Content-ideer”.

---

## Tre nivåer (från enkelt till mer avancerat)

### Nivå 1: Daglig SEO-brief i Slack (snabbast att sätta upp)

- **Ett nytt cron-job** i OpenClaw, t.ex. 07:30 (före Umami-rapporten).
- **Prompt:** Agenten kör `umami-daily-stats.sh`, får JSON. Utifrån det ska den:
  - Identifiera 1–3 sajter eller sidor som antingen fick mest trafik eller har hög bounce / låg tid.
  - Skriva en **kort SEO-brief** på svenska: "Idag: fokus på X. Förbättra titel/meta på [URL]. Överväg inlägg om Y."
- **Leverans:** Till #all-tur-ab (samma som Umami-rapporten), formaterad som den rapport du gillar (rubrik, fetstil, bullets).

**Resultat:** Varje morgon får du ett tydligt, datadrivet förslag utan att bygga något nytt system. Du utför själv ändringarna på sajterna.

---

### Nivå 2: Agenten tittar på sidorna (titlar, meta, innehåll)

- Utöver Umami-JSON ger du agenten **URL:er** att kolla. T.ex. startsida + 2–3 viktiga sidor per sajt (lista i prompt eller fil).
- Agenten använder **web_fetch** (eller browser om inlogg krävs) för att hämta sidan.
- Utifrån innehåll + Umami-siffror: "Sidan X har titel Y (55 tecken). Förslag: [ny titel]. Meta-beskrivning: [förslag]."
- Fortfarande **leverans i Slack** – du eller din redaktion applicerar ändringarna.

**Kräver:** Beslut om vilka URL:er som ska ingå (startsida, kategori, nyckelartiklar). Kan vara en enkel lista i OpenClaw-config eller i cron-prompten.

---

### Nivå 3: Automatiska uppdateringar (API/CMS)

- Om dina sajter har **API** (WordPress REST API, Headless CMS, Netlify/Decap CMS, eget admin-API) kan agenten:
  - Få instruktion att generera titel/meta/innehållsutkast.
  - Anropa API:et (via **verktyg** eller script som du exponerar till OpenClaw) för att skriva uppdateringar.
- Detta kräver: API-nycklar, tydliga regler (vad får uppdateras), och ev. granskning (t.ex. “skicka till Slack för godkännande innan publish”).

**Modernt:** Många stackar (Next + CMS, WP, etc.) har redan API; OpenClaw blir då “SEO-robot” som föreslår eller applicerar ändringar utifrån samma Umami-data.

---

## Rekommenderat första steg: Nivå 1 (SEO-brief)

1. **Skapa ett nytt cron-job** i OpenClaw, samma stil som Umami-rapporten:
   - Schema: t.ex. `30 7 * * *` (07:30 Europe/Stockholm).
   - Session: isolated.
   - Message: Ungefär:  
     "Kör /data/.openclaw/scripts/umami-daily-stats.sh. Utifrån JSON: skriv en kort **SEO-brief** på svenska (3–5 punkter). Fokusera på: vilken sajt/sida ska prioriteras idag, konkreta förslag (t.ex. bättre titel/meta, ett inläggsämne). Formatera för Slack med rubrik (t.ex. :chart_with_upwards_trend: SEO – idag), *fetstil* och bullets. Leverera till kanalen."
   - Samma `--announce --channel slack --to "channel:C07TJRLTM9C"` (#all-tur-ab).

2. **Testa** med `openclaw cron run <job-id> --force --expect-final`.

3. **Justera prompten** efter smak (mer fokus på bounce, mer på “skriv inlägg om X”, etc.).

När det känns bra kan du gå vidare till Nivå 2 (web_fetch av specifika URL:er) och, om du vill, Nivå 3 (API-uppdateringar). Om du berättar hur dina sajter är byggda (statiska sidor, WordPress, headless CMS, etc.) kan nästa steg vara att skriva exakt prompt och ev. en enkel URL-lista eller ett litet script som agenten anropar.

---

## Full SEO & Site Intelligence Agent (Astro/React + git)

För en **avancerad agent** som analyserar Umami + GitHub, skriver 1200–2500 ord artiklar (svenska, Markdown + frontmatter) och pushar till git för auto-deploy, se **[openclaw/agents/SEO-SITE-AGENT.md](../../openclaw/agents/SEO-SITE-AGENT.md)**. Där finns:

- Krav (Umami, GitHub-repolista, Git-åtkomst, Slack)
- Arbetsflöde: datainsamling → analysrapport till Slack → keyword research → content → draft → godkännande → commit & push
- Regler (max 1 artikel per körning, alltid godkännande innan push)
- Triggers (cron dagligen, Slack @agent)

Plus **site-repos.example.json** för mappning Umami-sajt → GitHub repo. Du fyller i dina repo-URLs och ev. Git-credentials, sedan använder du agent-briefen som system prompt/instructions i OpenClaw.
