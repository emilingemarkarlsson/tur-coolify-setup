# finnbodahamnplan.se

## SEO-prioritering: Nej (rapport-only)

**Denna sajt ska inte prioriteras** i vanlig SEO-planering, keyword-strategi eller artikel-förslag. Användaren kan inte driva content-arbete här; sajten används endast för **en månatlig styrelserapport**.

- **Fas 1 (planering):** Inkludera **inte** finnbodahamnplan i "prioriterad sajtlista" eller rekommenderad fokus.
- **Fas 2 (keyword / artikel-förslag):** Ge **inga** artikel-förslag för finnbodahamnplan.
- **Fas 3–4 (brief/skrivning):** Kör inte content brief eller artikel-skrivning för denna sajt.

---

## Endast: Månatlig styrelserapport

**Syfte:** En gång i månaden ska användaren kunna få en **lättläst rapport** över finnbodahamnplan.se som kan delas med styrelsen. Rapporten ska visa:

- **Användning och trafik** – besök, sidvisningar, unika besökare.
- **Period:** Senaste **3 månaderna** (rullande).
- **Format:** Kort, tydlig text (inga SEO-termer, ingen keyword-lista). T.ex.:
  - Sammanfattning i 2–3 meningar.
  - Nyckelnummer (totalt besök, sidvisningar, ev. topp-sidor).
  - Kort tolkning om något sticker ut (t.ex. ökning/minskning).

**Trigger i Slack:** När användaren skriver t.ex.:
- *"rapport finnbodahamnplan"*
- *"styrelserapport finnbodahamnplan"*
- *"trafikrapport finnbodahamnplan senaste 3 månader"*

… ska du (agenten):
1. Hämta data från Umami för finnbodahamnplan (websiteId i site-repos.json) – senaste 3 månaderna.
2. Skriva en **lättläst, kort rapport** på svenska, avsedd att delas med styrelsen (ingen jargon, inga SEO-rekommendationer).
3. **Skicka rapporten till Slack – viktigt:** Själva rapporten (siffror, sammanfattning, topp-sidor) ska vara **i samma meddelande**. Skriv aldrig bara "Here's the report" eller "Här är rapporten" utan att faktiskt visa innehållet. Formatera så här i ett enda Slack-meddelande:

```
**Styrelserapport finnbodahamnplan.se (senaste 3 månader)**

• Besök: [X]
• Sidvisningar: [Y]
• Unika besökare: [Z]
• Topp-sidor: [lista de 3–5 mest besökta]
• Kort tolkning: [1–2 meningar om trend eller vad som sticker ut]

Nästa steg: Du kan kopiera rapporten och dela med styrelsen. Vill du ha rapport för en annan period? Skriv: rapport [sajt].
```

Om Umami-API:et inte returnerar data: skriv tydligt *"Kunde inte hämta data från Umami. Kontrollera credentials i /data/.openclaw/umami-credentials.json."* – skriv aldrig en tom rapport eller bara en inledning utan siffror.

**Cron (valfritt):** Om användaren vill ha rapporten automatiskt en gång per månad kan ett cron-meddelande vara: *"Generera styrelserapport för finnbodahamnplan: trafik och användning senaste 3 månader, lättläst format för styrelsen. Skicka till Slack."*

---

## Övrigt (referens)

- **Pillars** (endast för kontext, inte för artikel-förslag): Styrelse och förening, Boende och service, Finnboda och närhet, Ekonomi och avgifter.
- **Språk rapport:** Svenska.
