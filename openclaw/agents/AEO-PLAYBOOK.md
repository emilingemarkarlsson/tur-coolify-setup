# AEO-PLAYBOOK – AI Engine Optimization

Riktlinjer för att optimera innehåll för AI-drivna sökmotorer: ChatGPT, Perplexity, Google AI Overviews, Claude, Gemini och liknande. Komplement till SEO-PLAYBOOK.md – klassisk SEO gäller fortfarande, AEO är ett lager ovanpå.

Referensdokument:
- **SEO-PLAYBOOK.md** – EEAT, struktur, tekniska krav
- **SEO-ROLLING-AUTOMATION-PROMPT.md** – cron-schema och automation

---

## Varför AEO skiljer sig från SEO

Klassisk SEO: rankas i en lista, användaren klickar.
AEO: AI-motorn läser din sida, extraherar ett svar och presenterar det – med eller utan länk. Du vill bli **den källa som citeras**, inte bara finnas i listan.

Vad AI-motorer värderar:
- Tydliga, direkta svar på specifika frågor (citerbara snippets)
- Strukturerad information med schema-markup
- Bred topical coverage inom ett ämne (authority)
- Trovärdighetsignaler: author, datum, externa källor
- Freshness: uppdaterat och datumsatt innehåll

---

## 1. Citerbar innehållsstruktur

### Svara direkt i första stycket
AI-motorer plockar svar från de första 100–150 orden. Artikeln ska inledas med en tydlig definition eller svar på den primära frågan.

Mönster:
```
[Target keyword] är [kortfattad definition/svar]. [En mening med context].
[Varför det är viktigt/relevant för läsaren.]
```

### FAQ-block
Inkludera ett FAQ-block i slutet av varje artikel (minst 3–5 frågor). AI-sökmotorer plockar fråga–svar-par aktivt.

Format:
```markdown
## Vanliga frågor

### Vad är [target keyword]?
[Direkt, koncist svar på 2–4 meningar.]

### Hur fungerar [relaterat begrepp]?
[Steg-för-steg eller kort förklaring.]

### [Ytterligare relevant fråga]?
[Svar.]
```

Frågorna ska matcha naturliga sökfraser (long-tail). Använd web_search för att identifiera "People Also Ask"-frågor för keywordet.

### Faktablock och statistikmeningar
AI-motorer gillar korta, faktadichtade meningar som är lätta att citera:
- Använd specifika siffror och datum: "Enligt [källa] 2024 ökade X med Y %."
- Undvik fluff: "Det är välkänt att..." → ersätt med faktapåstående + källa.
- En mening per nyckelfakta – inte inbäddad i långa stycken.

---

## 2. Schema.org markup

Schema-markup hjälper AI-crawlers förstå vad en sida innehåller. Prioritet per sidtyp:

### Article (alla blogginlägg)
Astro genererar ofta inte schema automatiskt. Kontrollera om sajten har `<script type="application/ld+json">` i `<head>`. Om inte – notera i AEO-audit.

Minsta Article-schema:
```json
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "Artikelns titel",
  "datePublished": "2025-01-20",
  "dateModified": "2025-06-01",
  "author": {
    "@type": "Person",
    "name": "Emil Ingemar Karlsson",
    "url": "https://emilingemarkarlsson.com"
  },
  "publisher": {
    "@type": "Organization",
    "name": "The Unnamed Roads"
  }
}
```

### FAQPage (artiklar med FAQ-block)
```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "Vad är X?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "X är..."
      }
    }
  ]
}
```

### HowTo (steg-för-steg-guider)
```json
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Hur du gör X",
  "step": [
    { "@type": "HowToStep", "name": "Steg 1", "text": "Gör detta." },
    { "@type": "HowToStep", "name": "Steg 2", "text": "Gör sedan detta." }
  ]
}
```

**Praktisk notering:** De flesta Astro-sajter i detta projekt saknar schema-markup. Närmaste lösning: lägg till JSON-LD i `src/layouts/BlogPost.astro` eller motsvarande layout-komponent. Flagga i AEO-audit vilka sajter som saknar det.

---

## 3. Topical Authority

AI-motorer bedömer om en sajt är en auktoritär källa på ett ämne genom att se bredden och djupet av relaterade artiklar – inte bara en enskild sida.

### Klusters strategi
Varje content pillar (från planfilen) ska ha:
- 1 cornerstone-artikel (djupgående, 2 000+ ord, länkad från allt annat)
- 3–5 satellitartiklar som täcker specifika underfrågor
- Tydliga interna länkar: satelliter → cornerstone, cornerstone → satelliter

### Lucköversikt (gap analysis)
Vid AEO-audit: identifiera frågor inom pillar som sajten inte svarar på men som konkurrenter eller AI-motorer tar upp. Dessa blir prioriterade kommande artiklar.

Sök: `site:[domain] [pillar-term]` via web_search för att se vad som finns.

### Uppdatering av befintliga artiklar (freshness)
AI-motorer ger bonus för nyligen uppdaterat innehåll med explicit `dateModified`. Vid refresh:
1. Lägg till/uppdatera FAQ-block
2. Uppdatera statistik och externa källhänvisningar
3. Lägg till interna länkar till nyare artiklar
4. Uppdatera `dateModified` i frontmatter

---

## 4. E-E-A-T för AI-sökmotorer

AI-motorer värderar trovärdighet ännu hårdare än klassisk SEO. Signalerna de letar efter:

### Author-markup
Varje artikel ska ha tydlig author med:
- Fullständigt namn i frontmatter (`author: "Emil Ingemar Karlsson"`)
- Länk till author-sida (om sajten har en)
- Schema `"author": { "@type": "Person", "name": "...", "url": "..." }`

### Externa källhänvisningar
Länka till primärkällor (research papers, officiell dokumentation, välkända publikationer). AI-motorer ser outbound-länkar till auktoritativa domäner som positiv signal.

Minst 2–3 externa källhänvisningar per artikel inom tech/analys-ämnen.

### Transparens om AI-genererat innehåll
För sajter som explicit märker AI-genererat innehåll (t.ex. `authorAgent: aion` på theunnamedroads):
- Var transparent – AI-motorer och användare värderar ärlighet
- Kombinera AI-skrivning med mänsklig granskning och faktakontroll
- Lägg till en kort "Om den här artikeln"-not om det passar sajten

---

## 5. AEO per sajt-typ

### Tech/AI-sajter (theunnamedroads, theagentfabric, theatomicnetwork)
- **Hög AEO-potential:** dessa ämnen söks aktivt i AI-motorer av developers och builders
- Prioritera: HowTo-schema, kodexempel med korrekt syntax, Mermaid-diagram för arkitektur
- FAQ-frågor: "Hur konfigurerar man X?", "Vad är skillnaden mellan X och Y?", "Vilket verktyg är bäst för Z?"
- Cornerstone: systemarkitektur-guides som AI kan citera när användare frågar om specifika stacks

### Hockey-sajter (thehockeybrain, thehockeyanalytics)
- Statistik och datavisualisering är stark AEO-signal (AI citerar siffror)
- Faktameningar med explicita siffror: "I NHL-säsongen 2023–24 hade lag X ett expected goals-värde på..."
- FAQ: "Vad är expected goals (xG) i hockey?", "Hur beräknas Corsi?"
- Schema: Article + eventuellt SportsEvent/Dataset för statistikartiklar

### Personlig sajt (emilingemarkarlsson)
- Thought leadership – AI citerar perspektiv från namngivna individer
- Tydlig author-markup och konsekvent förstanamn-signalering
- FAQ: mer konversationella frågor om karriär, synsätt, metodik

### Övriga (finnbodahamnplan – rapport-only, theprintroute)
- Lägre AEO-prioritet; följ grundkraven men djupdyk inte

---

## 6. Löpande AEO-automation

### Månadsvis AEO-audit (1:a måndagen varje månad, 07:30)
Per aktiv sajt:
1. Kontrollera om befintliga artiklar har FAQ-block – lista de utan
2. Sök `site:[domain]` via web_search och identifiera topical gaps
3. Kontrollera om sajten har schema-markup (Article/FAQPage) – notera saknade
4. Identifiera "stale" artiklar (publicerade >6 månader sedan, ej uppdaterade) – föreslå refresh
5. Leverera AEO-audit till Slack (#all-tur-ab): en lista med konkreta åtgärder per sajt

### Varannan vecka: artikel-refresh (varannan onsdag 09:00)
Välj en befintlig artikel per refresh-cykel:
1. Välj artikel som är >3 månader gammal och saknar FAQ-block
2. Lägg till FAQ-block (3–5 frågor baserade på "People Also Ask" via web_search)
3. Uppdatera eventuell statistik och datum i stycken
4. Uppdatera `dateModified` i frontmatter
5. Spara som draft och rapportera till Slack för godkännande

### Vid publicering av ny artikel (alltid)
Innan draft sparas: kontrollera att artikeln har:
- [ ] Direktsvar i första stycket (inom 150 ord)
- [ ] Minst ett FAQ-block (3+ frågor)
- [ ] Author i frontmatter
- [ ] Minst 2 externa källhänvisningar
- [ ] Minst 3 interna länkar
- [ ] `dateModified` = `publishedDate` (sätts automatiskt vid publicering)

---

## 7. Snabbkommandon (Slack)

| Kommando | Vad som händer |
|----------|----------------|
| `aeo-audit [sajt]` | Kör AEO-audit för specifik sajt |
| `refresha artikel [slug]` | Lägg till FAQ, uppdatera datum, spara draft |
| `aeo-rapport` | Sammanfattning av AEO-status för alla sajter |
| `schema-check [sajt]` | Kontrollera om sajten har schema-markup |
