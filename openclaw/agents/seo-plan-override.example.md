# SEO-plan – användarjustering (override)

Kopiera denna fil till **`seo-plan-override.md`** (samma mapp) och fyll i. Agenten läser `/data/.openclaw/agents/seo-plan-override.md` vid Fas 1 och använder detta som källa till sanning eller slår ihop med sin egen analys. Du kan alltså **rätta pillars, fokusordning eller gaps** per sajt så att planen blir korrekt.

Efter att du skapat `seo-plan-override.md`: kopiera filen till OpenClaw-containern (samma sätt som andra agent-filer, t.ex. `openclaw-install-seo-agent.sh` om du lägger till den där) eller skapa filen direkt i containern under `/data/.openclaw/agents/`.

---

## Format (valfritt – använd de sektioner du behöver)

### Prioriterad sajtlista (veckan)

Om du vill låsa vilka sajter som ska prioriteras, skriv t.ex.:

```markdown
## Fokus denna vecka (prioriterad ordning)
1. theunnamedroads.com – mer innehåll för resenärer
2. thehockeyanalytics.com – fördjupa statistikämnen
3. finnbodahamnplan.se – boendeinformation
```

Agenten använder denna ordning istället för att endast räkna trafik.

---

### Per-sajt: pillars och gaps (rättningar)

För varje sajt där du vill **överskriva eller förtydliga** agentens pillars/gaps:

```markdown
## finnbodahamnplan.se
- **Pillars:** (1) Styrelse och förening, (2) Boende och service (tvättstuga, felanmälan), (3) Finnboda och närhet, (4) Ekonomi och avgifter.
- **Gaps (hög):** Guider för boende (hur man bokar tvättstugan, felanmälan), FAQ.
- **Gaps (medium):** Lokal historia, evenemang.

## theunnamedroads.com
- **Pillars:** (1) Reseberättelser, (2) Outdoor och vandring, (3) Planering och packning, (4) Hållbart resande.
- **Gaps (hög):** Packlistor, mindre kända destinationer, soloresor.
```

Sajtnyckel kan vara **domain** eller **umamiName** (enligt site-repos.json). Agenten matchar och använder dina rader.

---

### Endast använd min plan (hoppa över automatisk analys)

Om du vill att agenten **enbart** ska använda denna fil och inte bygga pillars/gaps från Umami/GitHub, skriv överst:

```markdown
# SEO-plan – användarjustering
Använd endast denna plan. Hoppa över automatisk pillar/gap-analys; rapportera denna plan till Slack.
```

Då blir rapporten i Slack en ren spegling av det du skrivit här.

---

## Exempel på minimal override (bara fokusordning)

```markdown
# SEO-plan override
## Fokus denna vecka
1. theunnamedroads.com
2. thehockeyanalytics.com
3. finnbodahamnplan.se
```

Sparar du bara detta behåller agenten sin egen pillar/gap-analys men använder din fokusordning.
