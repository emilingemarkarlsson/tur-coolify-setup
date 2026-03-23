# NHL Data Auto – Agent Instructions

Datadrivna hockey-artiklar baserade på NHL:s öppna API.
Triggas av cron-meddelanden som börjar med **"NHL-DATA-AUTO:"**.

Referensdokument (läs vid behov):
- **SEO-ROLLING-AUTOMATION-PROMPT.md** – AEO-checklist, publiceringsflöde, human-voice regler
- **SEO-PLAYBOOK.md** – frontmatter-schema, EEAT, interna länkar
- `/data/.openclaw/scripts/nhl-data-fetch.sh` – dataskriptet
- `/data/.openclaw/nhl-data/latest.json` – senaste fetched data

---

## Trigger-format

```
NHL-DATA-AUTO: {umamiName}
```

Giltiga värden: `thehockeybrain` eller `thehockeyanalytics`

---

## Steg 1 – Hämta data

Kör fetch-scriptet och spara output:

```bash
/data/.openclaw/scripts/nhl-data-fetch.sh > /data/.openclaw/nhl-data/latest.json
```

Läs sedan `/data/.openclaw/nhl-data/latest.json`.

Om scriptet misslyckas (nätverksfel, API nere): rapportera felet till Slack och avbryt.
Skriv: "NHL API unreachable – skipping today's data article. Will retry at next cron."

---

## Steg 2 – Välj finding

Läs `findings[]` i JSON. Välj `findings[0]` (prioritet 1) såvida inte samma finding
publicerades senast – i så fall välj `findings[1]`.

**Kontrollera senast publicerad finding:**
Om filen `/data/.openclaw/nhl-data/last-finding.txt` finns: läs den (innehåller finding-type
från senaste körningen). Välj ett finding av annan type om möjligt.

Spara vald finding-type till `/data/.openclaw/nhl-data/last-finding.txt` **efter** publicering.

---

## Steg 3 – Bestäm sajt och vinkel

Sajten bestäms av cron-meddelandet (se trigger-format ovan).

**thehockeybrain** – analytiskt djup, datanörd, opinionerat:
- Läs `finding.article_angle_thb` för artikelvinkel
- Ton: analytisk, respekterar traditionell hockey men utmanar den, 1400–1800 ord
- Inkludera specifika beräkningar och siffror från `finding.data`
- Minst ett stycke som visar hur beräkningen görs ("Here's how to calculate GF%…")
- Minst en opinionerad mening ("The popular narrative about X is wrong")

**thehockeyanalytics** – tillgänglig, coachfokus, praktisk:
- Läs `finding.article_angle_tha` för artikelvinkel
- Ton: mer tillgänglig än thehockeybrain, riktar sig till coacher och scouts, 1100–1400 ord
- Undvik tung matematik – förklara koncepten med analogier och praktiska exempel
- Avsluta alltid med ett "What coaches can do with this" eller "The practical takeaway"-stycke

---

## Steg 4 – Artikel-typer per finding

### `regression_candidate_up` – "Lag X är på väg upp"

Struktur:
1. **Hook** – öppna med den exakta GF%- och pts%-siffran (INTE med "In today's world")
   Exempel: "57.3%. That's how much of the goal-scoring in [Team]'s games comes in their favor. Yet they sit 12th in the conference."
2. **The gap explained** – vad GF% mäter, varför det förutsäger framtida pts%
3. **The numbers** – tabell/lista med data.gf_pct, data.pts_pct, data.pts_pct_diff, data.gf_per_game, data.ga_per_game
4. **Historical context** – teams with this gap historically: how long before convergence? (use web_search: "GF% pts% regression NHL history")
5. **What most analysts miss** – varför folk stirrar på standings istället för process
6. **FAQ block** – 3–5 frågor (sök PAA: "[team name] NHL analytics" via web_search)
7. **CTA** – consulting/newsletter CTA från planfilen

### `regression_candidate_down` – "Varningssignaler bakom Lag X:s rekord"

Struktur:
1. **Hook** – öppna med pts_pct vs gf_pct-gapet: "They're 4th in the East. The analytics say they shouldn't be."
2. **What the standings show vs what the data shows**
3. **OT dependency breakdown** – data.ot_dependency_pct, data.row vs data.wins
4. **The historical pattern** – teams that overperformed this much: what happened in the second half?
5. **Specific risk factors** – vilka matchups eller situationer exponerar dem mest?
6. **FAQ block** – 3–5 frågor via web_search
7. **CTA**

### `best_underlying` – "Ligans bästa underliggande siffror"

Struktur:
1. **Hook** – öppna med GF%-siffran som det starkaste argumentet för en contender-thesis
2. **Why GF% beats Corsi for in-season prediction** – (thehockeybrain: forklara matematiken; thehockeyanalytics: förklara intuitivt)
3. **The team's numbers** – gf_per_game, ga_per_game, goal_diff, pts_pct, gf_pct
4. **Comparison** – kontrastera med ligans genomsnitt (50% GF%) och lagens med bäst pts%
5. **What it means for the playoffs**
6. **FAQ block**
7. **CTA**

### `ot_dependent` – "Ligans mest OT-beroende lag"

Struktur:
1. **Hook** – öppna med ot_dependency_pct: "X% of their wins have required overtime. That's not a strategy. That's survival."
2. **What OT dependency actually measures** – ROW vs W, varför poäng i förlängning inte reflekterar lagkvalitet lika bra
3. **The specific numbers** – data.ot_wins, data.row, data.wins, data.gp
4. **What usually happens to these teams** – historical pattern (web_search: "NHL overtime dependent teams second half performance")
5. **How to fix it** – vad coacher kan göra strukturellt (thehockeyanalytics-vinkel)
6. **FAQ block**
7. **CTA**

### `home_road_split` – "Hemma vs borta: ett av ligas mest extrema klyvningar"

Struktur:
1. **Hook** – öppna med hemma-% vs borta-% direkt: "At home: X%. On the road: Y%. Same team."
2. **Why splits this large are rare and significant**
3. **The numbers** – data.home_wpct, data.road_wpct, data.split, data.home_wins, data.road_wins
4. **Possible causes** – zone start exposure, line matching, travel schedule, goalie performance (sök web_search: "[team] road record 2025 analysis")
5. **What to watch for** (thehockeybrain: regression model; thehockeyanalytics: scouting checklist)
6. **FAQ block**
7. **CTA**

---

## Steg 5 – Frontmatter

**thehockeybrain:**
```yaml
---
title: "[Artikel-titel – max 65 tecken, inkludera teamnamnet]"
description: "[1–2 meningar med target keyword, max 160 tecken]"
pubDate: "[YYYY-MM-DD]"
updatedDate: "[YYYY-MM-DD]"
tags: ["nhl analytics", "hockey statistics", "[team name]", "[finding type]"]
author: "The Hockey Brain Analytics Team"
heroImage: "/images/blog/placeholder.jpg"
---
```

**thehockeyanalytics:**
```yaml
---
title: "[Artikel-titel – mer tillgänglig, inga jargon-ord i titeln]"
description: "[1–2 meningar, riktar sig till coaches och scouts]"
pubDate: "[YYYY-MM-DD]"
updatedDate: "[YYYY-MM-DD]"
tags: ["hockey analytics", "nhl", "[team name]", "coaching"]
author: "The Hockey Analytics Team"
heroImage: "/images/blog/placeholder.jpg"
---
```

---

## Steg 6 – Obligatoriska element (kör AEO-checklist alltid)

Kontrollera innan draft sparas:

- [ ] Direktsvar på artikelns fråga inom de första 150 orden
- [ ] Minst ett FAQ-block (3–5 frågor från PAA via web_search)
- [ ] `author` i frontmatter
- [ ] Minst 2 externa källhänvisningar (länkade) – t.ex. Natural Stat Trick, Hockey Reference, NHL officiell data
- [ ] Minst 3 interna länkplaceholders `[länk: relevant-slug]` (agent fyller i, publicering-scriptet ersätter inte – de är manuella placeholders som visar var interna länkar ska)
- [ ] `updatedDate` = `pubDate` (ny artikel)
- [ ] CTA i slutet (consulting för thehockeybrain, newsletter för thehockeyanalytics)

**Human-voice regler (anti-AI-signal – obligatoriska):**
- Öppna med konkret datapunkt – ALDRIG "In today's world" / "In recent years" / "Hockey is a complex sport"
- Minst ett stycke med förstahandsperspektiv ("The pattern I keep seeing", "When you look at this data closely", "What surprised me here")
- Minst en opinionerad mening ("X is overrated", "Most analysts are looking at the wrong metric", "The real bottleneck isn't Y, it's Z")
- En sektion som heter "What Most People Get Wrong" eller "The Common Mistake" eller liknande
- Avsluta med ett konkret next-step – inte en generisk sammanfattning

---

## Steg 7 – Publicering (automatisk – ingen godkännande behövs)

```
1. Kör AEO-checklist (ovan)
2. Spara: /data/.openclaw/drafts/{slug}.md
3. Spara: /data/.openclaw/drafts/{slug}.meta  (en rad: umamiName={umamiName})
4. Kör: /data/.openclaw/scripts/publish-draft.sh {slug}
5. Spara finding-type till: /data/.openclaw/nhl-data/last-finding.txt
6. Rapportera till Slack (#all-tur-ab):
   "✅ NHL Data Article published
    Title: [titel]
    Site: {domain}
    URL: {url}
    Finding: {finding.headline}
    Data: GF% {x}% / Pts% {y}% / {gp} games analyzed"
```

Om publish-draft.sh misslyckas: spara draften, rapportera felet i Slack med slug och felmeddelande.

---

## Slug-konvention

```
nhl-{finding-type-short}-{team-abbrev}-{YYYY-MM-DD}
```

Exempel:
- `nhl-regression-up-buf-2025-03-15`
- `nhl-ot-dependent-col-2025-03-18`
- `nhl-best-underlying-fla-2025-03-20`

Finding-type-short-mappning:
- `regression_candidate_up`   → `regression-up`
- `regression_candidate_down` → `regression-down`
- `best_underlying`           → `best-underlying`
- `ot_dependent`              → `ot-dependent`
- `home_road_split`           → `home-road`

---

## Regler

- Max 1 artikel per cron-körning
- Kör alltid nhl-data-fetch.sh först – skriv aldrig utan färsk data
- Välj aldrig samma finding-type som senaste körningen om alternativ finns
- Skriv aldrig om ett lag som publicerades de senaste 7 dagarna
- Rapportera alla fel tydligt i Slack – avbryt aldrig tyst
- Kör alltid AEO-checklist innan draft sparas
