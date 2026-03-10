# Nästa steg – SEO & Site Intelligence Agent (best-in-class process)

För att komma vidare från dagliga rapporter till en **full SEO-process** i OpenClaw: **planering → keyword-strategi → content brief → skrivning → publicering**. Processen beskrivs i **SEO-PROCESS.md**; kvalitetskrav i **SEO-PLAYBOOK.md**.

---

## Steg 1: Fyll i repo-mappningen (5–10 min)

Du behöver en lista som säger vilken **Umami-sajt** som hör till vilket **GitHub-repo**.

1. Öppna **`openclaw/agents/site-repos.example.json`**.
2. Kopiera till **`openclaw/agents/site-repos.json`** (eller spara var OpenClaw kan läsa den, t.ex. i containern under `/data/.openclaw/`).
3. Ersätt `YOUR_ORG` med ditt GitHub-org eller användarnamn.
4. Uppdatera **`githubRepo`** för varje sajt till rätt URL (t.ex. `git@github.com:dinorg/finnbodahamnplan.git`).
5. Justera **`contentPath`** och **`stack`** (astro/react) om det skiljer sig från mallen.

**Umami websiteId** har du redan i scriptets JSON-output (eller i Umami UI). Exemplet innehåller ID för finnbodahamnplan, theunnamedroads, thehockeyanalytics – lägg till/ta bort sajter efter behov.

---

## Steg 2: Bestäm hur Git ska fungera

**Alternativ A – Agenten pushar själv (full automatik)**  
- OpenClaw behöver **Git-åtkomst**: SSH-nyckel eller Personal Access Token.  
- Mounta nyckel/token i OpenClaw-containern (t.ex. via Coolify env eller volume) så att `git clone` / `git push` fungerar från agentens workspace.  
- Kräver att agenten kan köra `git` (exec) och att repon klonas någonstans (t.ex. `/data/.openclaw/repos/`).

**Alternativ B – Du pushar manuellt (enklare att komma igång)**  
- Agenten skickar **utkast till Slack** (artikel + frontmatter eller filinnehåll).  
- Du kopierar in i rätt repo, committar och pushar själv.  
- Då behöver du **inte** sätta upp Git i OpenClaw nu.

Rekommendation: börja med **B**, så kan du använda agenten direkt. När flödet känns bra kan du lägga till Git (A).

---

## Steg 3: Lägg agent-briefen och processdokument i OpenClaw

OpenClaw ska följa den fulla SEO-processen (planering, keyword, brief, skrivning).

1. **Agent-instructions:** Öppna **`SEO-SITE-AGENT.md`** – det är huvudbriefen. Inkludera den i OpenClaw (Instructions / System prompt) för agenten "SEO" eller "Site Intelligence".
2. **Process och playbook:** Antingen inkludera **SEO-PROCESS.md** och **SEO-PLAYBOOK.md** i samma instructions (kort referens), eller lägg dem någonstans agenten kan läsa (t.ex. `/data/.openclaw/agents/` i containern) och nämn i instructions: "Processen beskrivs i SEO-PROCESS.md; kvalitetskrav i SEO-PLAYBOOK.md."
3. **site-repos.json:** Se till att agenten vet var den ligger (t.ex. "/data/.openclaw/site-repos.json" om du kopierat filen dit).

---

## Steg 4: Trigga agenten (cadens)

**Cron (rekommenderad cadens)**  
- **Veckovis (t.ex. måndag) – planering:** *"Kör Fas 1 SEO-planering: pillars, gaps, prioriterad sajtlista. Rapportera till Slack (#all-tur-ab)."*  
- **Veckovis – keyword:** *"Kör Fas 2 keyword-strategi för prioriterade sajter. Leverera keyword-backlog till Slack."*  
- **Daglig – läge:** *"Analysera alla sajter via Umami + GitHub, rapportera trafik och topp-sidor till Slack."*  

**Slack (på begäran)**  
- *"@tur-openclaw analysera sajterna"* / *"keyword-strategi för [sajt]"* / *"content brief för [sajt] om [keyword]"* / *"producera artikel för [sajt] om [ämne]"*.

---

## Steg 5: Testa en analysrunda

1. Trigga manuellt (cron run med --force eller via Slack).  
2. Kontrollera att agenten:  
   - antingen kör Umami-scriptet eller anropar Umami API,  
   - och skickar en **analysrapport** till Slack (per sajt: trafik, top pages, förslag).  
3. Om något krävs (t.ex. repo-lista, Git) – agenten ska fråga i Slack. Fyll i det som saknas och kör igen.

---

## Snabbchecklista

- [ ] **site-repos.json** skapad och ifylld med dina GitHub-repon  
- [ ] **Beslut:** Git i OpenClaw (A) eller bara draft till Slack (B)  
- [ ] **SEO-SITE-AGENT.md** inlagd som instructions för SEO-agenten  
- [ ] **SEO-PROCESS.md** och **SEO-PLAYBOOK.md** tillgängliga (ingår i instructions eller i `/data/.openclaw/agents/`)  
- [ ] **Cron** satt: veckovis planering + (valfritt) veckovis keyword + daglig lägesrapport  
- [ ] **Ett testkör** gjort: t.ex. "analysera sajterna" eller "Fas 1 planering" → rapport i Slack  

När detta är klart har du en **best-in-class SEO-process** i OpenClaw: planering, keyword-strategi, content brief och skrivning med tydliga kvalitetskrav (playbook). Finjustera sedan cadens, fler sajter i site-repos, eller aktivera Git-push om du började med draft till Slack.
