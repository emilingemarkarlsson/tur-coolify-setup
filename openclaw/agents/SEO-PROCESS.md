# Best-in-class SEO-process (OpenClaw)

Denna process körs i OpenClaw med Umami + site-repos + Slack. Den täcker **planering → keyword-strategi → content brief → skrivning → publicering → uppföljning** så att varje artikel är strategisk och mätbar.

---

## Översikt – fyra faser

| Fas | Syfte | Cadens / trigger |
|-----|--------|-------------------|
| **1. SEO-planering** | Content pillars, content gaps, prioriterad sajtlista | Veckovis (cron eller manuellt) |
| **2. Keyword-strategi** | Research, prioritering, mappning mot sidor | Per sajt innan nytt innehåll; veckovis batch |
| **3. Content brief** | Search intent, outline, interna länkar, konkurrentsnapshot | Före varje artikel |
| **4. Skrivning & publicering** | Artikel → Slack → godkänn → push | Per artikel (cron eller Slack) |

Uppföljning: Umami (trafik, topp-sidor) + månatlig genomgång av vad som presterar och vad som behöver uppdateras.

---

## Fas 1: SEO-planering (grundlig analys)

**Mål:** Ha en tydlig prioritering per sajt och veta *var* vi satsar nästa vecka/månad. Analysen ska bygga på **faktisk sajtdata**, inte enbart domännamn.

### 1.0 Användarjusterad plan (valfritt)

- Om **`/data/.openclaw/agents/seo-plan-override.md`** finns: läs den först. Användaren kan där rätta pillars, fokusordning eller gaps per sajt. Använd som källa till sanning eller slå ihop med automatisk analys. Se `seo-plan-override.example.md` för format.

### 1.1 Datainsamling (krävs för grundlig analys)

- **Umami topp-sidor:** För varje sajt (websiteId från site-repos): `GET /api/websites/{websiteId}/metrics?startAt=&endAt=&type=path&limit=20` (senaste 30 dagar). Det ger faktiska URL:er och visningar – använd för att härleda vilka teman som presterar.
- **Befintligt innehåll:** Om GitHub/repo är tillgängligt: lista filer i contentPath (t.ex. `src/content/blog/*.md`), läs titlar från frontmatter. Då bygger pillars och gaps på **verklig** innehållsstruktur.

### 1.2 Content pillars (per sajt)

- Definiera **3–5 content pillars** utifrån **topp-URL:er och befintliga sidtitlar** (teman som redan presterar eller som saknas men hör till sajtens mål). Undvik att gissa enbart från domännamn.
- Dokumentera i analysrapport till Slack eller i `docs/seo-pillars.md` per repo.

### 1.3 Content gap-analys

- Jämför befintliga sidor (från Umami metrics + GitHub) med vad målgruppen söker (web_search). Lista gaps: hög/medium/låg prioritet.
- Leverera som gap-lista i Slack eller i `docs/seo-gaps.md`.

### 1.4 Prioriterad sajtlista

- Utifrån trafik, topp-sidor och gap-analys (eller enligt seo-plan-override): vilka **1–3 sajter** ska få nytt innehåll nästa vecka? Motivera.
- Rapportera i Slack: *"Rekommenderad fokus denna vecka: [sajt 1], [sajt 2]. Motivering: [kort]."*

**Output:** Slack-post med pillars, gap-lista, prioriterad sajtlista. Vid behov: filer i repo under `docs/`.

---

## Fas 2: Keyword-strategi

**Mål:** Veta *vilka* keywords vi jagar och vilken sida (ny eller befintlig) som ska ranka.

### 2.1 Keyword-research

- Per prioriterad sajt (och ev. per pillar):
  - Använd **web_search** / tillgängliga verktyg för att hitta keywords:
    - Sökvolym (uppskattning, t.ex. "hög / medium / låg" eller siffra om källa finns).
    - Svårighetsgrad (uppskattad KD &lt; 35 för nya sidor om möjligt; högre OK för att förbättra befintliga).
    - **Search intent:** informativ, transaktionell, navigational.
  - Filtrera på **språk** (svenska där sajten är svensk) och **relevans** till pillar/domain.

### 2.2 Keyword-mappning

- **Ny sida:** keyword → ny artikel (slug, pillar).
- **Befintlig sida:** keyword → vilken URL ska optimeras (från Umami/GitHub).
- Håll en **keyword-backlog** per sajt (i Slack eller i `docs/keyword-backlog.md` / strukturerad fil):
  - Keyword, intent, volym, KD, mål-URL (ny eller befintlig), prioritet.

### 2.3 Prioriteringsmatris

- **Hög prioritet:** tillräcklig volym + rimlig KD + tydlig intent + passar pillar.
- **Medium:** bra volym men högre KD, eller sidospår från pillar.
- **Låg:** låg volym eller mycket hög konkurrens; köas.

**Output:** Keyword-lista (ev. keyword-backlog) med 1–5 valda keywords för nästa artiklar, postad till Slack eller sparad enligt rutin.

### 2.4 Artikel-förslag till Slack

- Utifrån keyword-backlog: formulera **artikel-förslag** (1–5 st) med sajt, keyword, förslag på titel, prioritet och kort motivering.
- Skicka till Slack enligt format i **SEO-ARTICLE-SUGGESTIONS.md**. Varje förslag ska vara tydligt så att användaren kan säga "publicera denna" eller senare använda en Publicera-knapp (webhook med `umamiName|keyword`).

---

## Fas 3: Content brief

**Mål:** Innan agenten skriver: tydlig brief så att artikeln blir SEO- och användaroptimerad.

### 3.1 För varje valt keyword

- **Target keyword** + 2–3 sekundära/semantiska keywords.
- **Search intent:** (informativ / transaktionell / navigational) och en mening om vad användaren vill få ut.
- **SERP-snapshot (kort):** vad rankar idag (titeltyper, format: lista, guide, FAQ)? Använd web_search om tillgängligt.
- **Outline:** H1, H2, H2, … med 1–2 meningar per sektion.
- **Interna länkar:** 3–5 befintliga sidor (URL eller titel) från samma sajt som ska länkas in (från Umami topp-sidor / GitHub).
- **Längd:** 1200–2500 ord (informativ) eller enligt intent.
- **CTA:** vad ska användaren göra på slutet (prenumerera, läsa mer, kontakta)?

### 3.2 Godkänn brief i Slack

- Skicka **content brief** till Slack.
- Vänta på *"OK"* eller justeringar innan Fas 4.

**Output:** Godkänd content brief (kan sparas som fil i repo, t.ex. `docs/briefs/YYYY-MM-DD-keyword-slug.md` om du vill historik).

---

## Fas 4: Skrivning & publicering

**Mål:** Artikel som följer briefen, frontmatter och playbook → Slack → godkänn → push.

### 4.1 Skrivning

- Följ **SEO-playbook** (se SEO-PLAYBOOK.md): språk, EEAT, strukturerad data, interna länkar, ingen keyword-stuffing.
- **Frontmatter** exakt enligt sajtens schema (från `site-repos` + GitHub content config).
- Fil i rätt content-mapp: `src/content/blog/{kebab-slug}.md` (eller `src/content/posts/` enligt sajt).

### 4.2 Draft → Slack → godkännande

- Skicka utkast (eller sammanfattning + första stycken + filnamn) till Slack.
- Vid godkännande: commit & push (eller leverera fil så att du pushar manuellt).

### 4.3 Efter publicering

- Notera i Slack: *"Publicerat: [sajt] – [URL/slug]. Keyword: [keyword]. Nästa: [nästa brief eller sajt]."*
- Uppdatera keyword-backlog / plan så att samma keyword inte skrivs igen; ev. påminnelse om uppföljning om 4–8 veckor (trafik i Umami).

---

## Cadens (rekommenderad)

| Aktivitet | Frekvens | Trigger |
|-----------|----------|--------|
| **SEO-planering** (pillars, gaps, prioriterad sajt) | Veckovis | Cron måndag eller manuellt |
| **Keyword-strategi** (research + mappning för prioriterade sajter) | Veckovis eller före varje batch | Efter planering |
| **Content brief** | Före varje ny artikel | Manuellt eller efter keyword-val |
| **Skrivning + publicering** | 1–3 artiklar/vecka (eller enligt kapacitet) | Slack eller cron |
| **Analysrapport (Umami + topp-sidor)** | Daglig (befintlig) | Cron 08:00 |
| **Månatlig genomgång** | Månadsvis | Cron eller manuellt: vilka sidor presterar, vad ska uppdateras |

---

## Var data och artefakter finns

| Vad | Var |
|----|-----|
| Trafik, topp-sidor | Umami API + `/data/.openclaw/scripts/umami-daily-stats.sh` |
| Repos, content path, stack | `site-repos.json` (eller example) |
| SEO-plan, pillars, gaps, keyword-backlog | Slack (alltid) + valfritt `docs/` i varje sajt-repo |
| Content briefs | Slack; valfritt `docs/briefs/` i repo |
| Slutartiklar | `src/content/blog/` eller `src/content/posts/` i respektive repo |

Agenten behöver **ingen egen databas** – allt kan leva i Slack + filer i repon om du vill ha historik.

---

## Nästa steg

- **SEO-SITE-AGENT.md** – utökad med dessa faser så att agenten vet exakt vad som ska göras i planering, keyword, brief och skrivning.
- **SEO-PLAYBOOK.md** – krav på kvalitet (språk, EEAT, länkar, frontmatter, längd).
- **NASTA-STEG.md** – uppdaterad med denna process och cadens.
