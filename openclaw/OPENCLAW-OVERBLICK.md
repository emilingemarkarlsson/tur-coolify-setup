# OpenClaw SEO – översikt och status

Översikt över vad som körs automatiskt, vad som är manuellt/on-demand, säkerhet och hur du lägger till nästa sajt.

---

## Vad körs automatiskt?

| Vad | Var | När | Krediter |
|-----|-----|-----|----------|
| **Påminnelse – ny artikel** | Servern (tha), cron | Varje dag 09:00 | Inga (bara Slack Incoming Webhook) |
| **SEO planering (Fas 1)** | OpenClaw cron | Om du lagt in: måndag 07:00 | Ja (agentkörning) |
| **Keyword-strategi (Fas 2)** | OpenClaw cron | Om du lagt in: tisdag 07:30 | Ja |
| **Artikel-förslag till Slack** | OpenClaw cron | Om du lagt in: onsdag 08:00 | Ja |
| **Daglig lägesrapport / Umami** | OpenClaw cron | Om du lagt in: t.ex. 08:00 | Ja |

**Idag är säkert igång:** Påminnelsen (tha, 09:00). Övriga rader körs bara om du själv har kört `openclaw cron add` för dem (se SETUP-SEO-OPENCLAW.md steg 4).

**På begäran (Slack):** Du skriver i #all-tur-ab – ingen cron behövs för själva artikelflödet:
- `@tur-openclaw artikel-förslag för emilingemarkarlsson` → förslag
- `2` (eller annan siffra) → välj förslag, agenten skickar brief
- `Godkänn` → agenten skriver artikel, skickar draft
- `publicera <slug>` → agenten kör script, push till GitHub, Netlify bygger

---

## Säkerhet – vad ligger var?

| Vad | Var det ligger | I repot? |
|-----|-----------------|----------|
| **GITHUB_TOKEN** | Coolify → OpenClaw → Environment Variables (eller fil i container) | Nej |
| **Slack Incoming Webhook (påminnelse)** | Servern tha: `~/.slack-seo-reminder-url` | Nej |
| **Slack Signing Secret (knappar)** | Endast om du kör slack-webhook-tjänsten: env där | Nej |
| **site-repos.json** | Repot (openclaw/agents/) + kopieras till container | Ja – inga secrets, bara repo-URL:er |
| **Agentinstruktioner, planer, playbook** | Repot, synkas till container via install-script | Ja |

**Rekommendation:** Lägg aldrig webhook-URL:er eller API-nycklar i filer som committas. Använd miljövariabler eller filer på servern (t.ex. `~/.slack-seo-reminder-url`).

---

## Optimering och effektivitet

- **En agent (main)** – en instruktionsuppsättning (AGENTS.md, SEO-SITE-AGENT.md) för alla sajter; sajt väljs via `artikel-förslag för [umamiName]` eller `producera artikel för [sajt] om [keyword]`.
- **Ett repo per sajt** – site-repos.json mappar umamiName → githubRepo, contentPath, domain. publish-draft.sh läser den och pushar till rätt repo.
- **Samma GITHUB_TOKEN** – kan ha åtkomst till flera repon (GitHub PAT med "Only select repositories" eller scope repo för alla). Inget nytt token behövs per sajt.
- **Plan per sajt** – openclaw/agents/plans/{umamiName}.md (språk, stil, pillars). Install-scriptet synkar till containern. Ny sajt = ny planfil + en rad i site-repos.json.
- **Påminnelse utan AI** – daglig påminnelse går via enkel curl till Slack; ingen OpenClaw-körning, inga krediter.

---

## Lägg till nästa sajt (checklista)

1. **site-repos.json** – lägg till ett objekt i `sites` med `umamiName`, `domain`, `githubRepo`, `contentPath`, `stack` (och ev. `umamiWebsiteId` om du använder Umami för den sajten).
2. **Planfil** – skapa `openclaw/agents/plans/{umamiName}.md` (språk, stil, pillars, gaps). Se `emilingemarkarlsson.md` eller `plans/README.md` som mall.
3. **GitHub** – om PAT är "Only select repositories", lägg till det nya repot under samma token. Annars om du använder scope repo är det redan täckt.
4. **Kör install** – `./scripts/openclaw-install-seo-agent.sh` så att site-repos.json och nya planen synkas till containern.
5. **Testa i Slack** – `@tur-openclaw artikel-förslag för <umamiName>`.

Om sajten bygger på Netlify/Vercel vid push till main behöver du inte konfigurera något mer för deploy – publish-draft.sh pushar till rätt repo och CI gör resten.

**Frontmatter:** Om sajten är Astro med content collections, kolla om den använder `publishDate` eller `pubDate` och dokumentera i planfilen (som för emilingemarkarlsson) så att agenten skriver rätt fält.

---

## Snabbreferens – viktiga filer

| Fil | Syfte |
|-----|--------|
| **openclaw/agents/SEO-SITE-AGENT.md** | Huvudregler för agenten (fyra faser, publicera, Nästa steg) |
| **openclaw/agents/site-repos.json** | Sajt → repo, contentPath, domain |
| **openclaw/agents/plans/{umamiName}.md** | Plan per sajt (språk, stil, pillars) |
| **openclaw/scripts/publish-draft.sh** | Körs vid "publicera {slug}" – läser draft + site-repos, pushar till GitHub |
| **openclaw/SNABBKOMMANDON.md** | Korta kommandon i Slack |
| **openclaw/REMINDER-CRON.md** | Påminnelse på servern (tha) |
| **openclaw/GIT-SETUP.md** | GITHUB_TOKEN, publish-script |
| **openclaw/SETUP-SEO-OPENCLAW.md** | Full setup inkl. valfria OpenClaw-cron-jobb |

---

## Felsökning

- **Agenten säger "jq required" / "scriptet kräver jq"** – Både `publish-draft.sh` och `umami-daily-stats.sh` använder nu **python3** som fallback (ingen jq). Kör **`./scripts/openclaw-install-seo-agent.sh`** så att den senaste versionen av scripten (inkl. umami-daily-stats.sh) kopieras till containern.
- **"Invalid OpenAI API key" / memory search fungerar inte** – Se nedan: **Så fixar du API-nyckeln**.

---

## Så fixar du API-nyckeln (memory search)

När agenten skriver *"Invalid OpenAI API key"* eller att memory search inte fungerar använder OpenClaw en API-nyckel för att prata med AI:n (LiteLLM eller annan provider). Den nyckeln används både för chat och för verktyg som "memory search". Om den är fel eller utgången fungerar inte memory – och då kan t.ex. Fas 2 (keyword-strategi) som försöker läsa "prioriterade sajter från senaste planering" ge fel.

**Steg 1 – Öppna miljövariablerna**

1. Öppna **Coolify** i webbläsaren.
2. Gå till det **projekt** där OpenClaw ligger.
3. Klicka på **OpenClaw-tjänsten** (den container som heter openclaw eller liknande).
4. Leta efter **Environment Variables** / **Variabler** / **Env** och klicka så att du ser listan med variabler.

**Steg 2 – Kontrollera vad OpenClaw använder**

- Om du kör **LiteLLM** (vanligt i denna setup): OpenClaw pratar med LiteLLM, inte direkt med OpenAI. Då ska du ha något i stil med:
  - **OPENAI_API_KEY** = samma värde som LiteLLM:s **master key** (eller en egen nyckel du skapat i LiteLLM). Det är *inte* en riktig OpenAI-nyckel, utan den som LiteLLM kräver för att acceptera anrop.
  - **OPENAI_API_BASE** = din LiteLLM-URL, t.ex. `https://litellm.theunnamedroads.com/v1` (eller den URL du använder för LiteLLM).
- Om **OPENAI_API_KEY** saknas eller är fel (t.ex. gammal eller av misstag ändrad) blir anropen ogiltiga och memory search (och ibland andra verktyg) faller.

**Steg 3 – Rätt värden**

- **OPENAI_API_KEY:** Öppna LiteLLM (eller var du hanterar den) och kolla **master key** / API-nyckel. Kopiera samma värde till Coolify → OpenClaw → **OPENAI_API_KEY**. Inga mellanslag i början eller slutet.
- **OPENAI_API_BASE:** Ska peka på LiteLLM, t.ex. `https://<din-litellm-domän>/v1`.

**Steg 4 – Spara och starta om**

- Spara variablerna i Coolify. Starta sedan om OpenClaw-containern (Restart / Redeploy) så att den läser in de nya värdena.

Därefter ska agenten kunna använda memory search igen (och sluta rapportera "Invalid OpenAI API key" pga den nyckeln).

---

## Sammanfattning

- **Automatiskt:** Daglig påminnelse (tha 09:00). Eventuella OpenClaw-cron (planering, keyword, artikel-förslag, lägesrapport) om du lagt in dem.
- **On-demand:** Allt artikelflöde via Slack (artikel-förslag → siffra → Godkänn → publicera slug).
- **Säkert:** Token och webhook-URL:er finns inte i repot; de sätts i Coolify/env eller filer på servern.
- **Nästa sajt:** Ny rad i site-repos.json + ny planfil i plans/, kör install, lägg ev. till repot i GitHub PAT.
