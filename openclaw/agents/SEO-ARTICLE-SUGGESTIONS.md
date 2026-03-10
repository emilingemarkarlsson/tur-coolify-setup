# Artikel-förslag till Slack + Publicera-flöde

Varje sajt och GitHub-uppsättning analyseras (Fas 1+2). Utifrån det skickas **artikel-förslag** till Slack. Där ska användaren kunna trycka **Publicera** så att artikeln skrivs och publiceras på den sajten.

---

## 1. Analys per sajt

- **Fas 1:** Planering (pillars, gaps, prioriterad sajtlista) – använder Umami topp-sidor, GitHub contentPath och användarplaner i `/data/workspace/seo-plan-{umamiName}.md`. Sajter med **"SEO-prioritering: Nej"** eller **rapport-only** i planen ska inte vara med i prioriterad sajtlista.
- **Fas 2:** Keyword-strategi för prioriterade sajter – keyword-backlog med prioritet (hög/medium/låg).

Utifrån detta producerar agenten **artikel-förslag** (endast för sajter som inte är rapport-only): konkreta förslag på en artikel per sajt (eller per prioriterad sajt), med keyword, förslag på titel och kort motivering. **Språk och stil:** Förslag ska vara på sajtens språk (t.ex. engelska för emilingemarkarlsson.com) och, om planen anger en författarstil (t.ex. "Emil's style"), formulera titlar och motiveringar i samma ton. Nämn gärna om artikeln kan förstärkas med flödesschema eller diagram (enligt SEO-PLAYBOOK §7).

---

## 2. Format för artikel-förslag i Slack (måste alltid synas, inget \"gömmer sig\")

När du skickar artikel-förslag till Slack (#all-tur-ab), skicka **alltid 3–5 förslag** (om planen/keyword-backlog tillåter).

**Formatkrav (för att undvika att Slack klipper bort innehåll):**

- **Ett enda, kort textmeddelande** (ingen Block Kit, inga kodblock, inga långa citat).
- Varje förslag på **en rad** med enkel text, t.ex.:  
  `1) Title — keyword: [keyword] — reason: [kort motivering]`
- Max totalt **ca 10–12 rader** (rubrik + 3–5 förslag + en kort \"Nästa steg\"-rad).
- Inga stora markdown-block eller extra rubriker som riskerar att Slack bara visar första raden.

**Exakt format (följ detta):**

```
Here are article suggestions for theunnamedroads.com:
1) [Titel 1] — keyword: [keyword 1] — reason: [kort mening]
2) [Titel 2] — keyword: [keyword 2] — reason: [kort mening]
3) [Titel 3] — keyword: [keyword 3] — reason: [kort mening]

Nästa steg: Svara med en siffra (1–3) för att välja förslag, eller skriv: producera artikel för theunnamedroads om [keyword].
```

⚠️ **Mycket viktigt:** Skriv **aldrig bara en inledning** som *\"Here are a few article suggestions…\"* utan att faktiskt lista förslagen. Om något verktyg (t.ex. Umami-API eller web_search) inte fungerar:

- **Hoppa över verktyget** och generera **minst 3 konkreta, numrerade förslag** ändå, baserat på:
  - planfilen för sajten (`seo-plan-{umamiName}.md`)
  - domännamnet
  - din generella SEO-kunskap

Fel i verktyg är **inte** en anledning att svara utan faktiska förslag – använd fallback och leverera ändå **i textformatet ovan**.

**Varje förslag ska innehålla (textformat som vi sen kan mappa till Block Kit):**

- **Sajt (umamiName):** t.ex. `theunnamedroads`
- **Domain:** t.ex. `theunnamedroads.com`
- **Keyword (target):** t.ex. `packlista vandring`
- **Förslag på titel:** t.ex. `Packlista vandring – komplett guide 2025`
- **Prioritet:** hög / medium / låg
- **Kort motivering:** en mening (varför denna artikel, gap eller pillar)

**Gör så att alla förslag syns:** Antingen skickar du **ett Slack-meddelande per förslag** (4–5 meddelanden, då klipps inget bort) eller ett samlat meddelande med tydlig numrering #1–#5. Avsluta med **ett** Nästa steg på svenska (om du skickat flera meddelanden: bara i sista meddelandet).

**Exempel på hur du kan formulera ett förslag i Slack (alltid med Nästa steg på svenska i sista meddelandet):**

```
📄 Artikel-förslag #1
Sajt: theunnamedroads.com (theunnamedroads)
Keyword: packlista vandring
Förslag på titel: Packlista vandring – komplett guide 2025
Prioritet: hög
Motivering: Stark gap enligt plan; sökningsvolym bra, KD rimlig för ny sida.

Nästa steg: Vill du skriva denna artikel? Kopiera och skicka: producera artikel för theunnamedroads om packlista vandring
```

Om du skickar flera förslag i samma meddelande, avsluta med **Nästa steg** på **svenska**: *"Svara med en siffra (1–5) för att välja det förslaget, t.ex. *2* för förslag #2. Eller kopiera: producera artikel för [sajt] om [keyword] – t.ex. producera artikel för emilingemarkarlsson om Modern Data Stack Consulting"*

**Språk för "Nästa steg":** Användarens kommandon är på svenska (artikel-förslag, producera artikel, publicera, kassera). Avsluta alltid med **"Nästa steg:" på svenska** och en färdig rad att kopiera, t.ex. *"Nästa steg: Vill du skriva en av dessa? Kopiera och skicka: producera artikel för emilingemarkarlsson om [keyword] – t.ex. producera artikel för emilingemarkarlsson om Modern Data Stack Consulting"*.

**För framtida Publicera-knapp:** När vi lägger till Block Kit-knappar skickar vi i knappens `value` en sträng med `umamiName|keyword` (t.ex. `theunnamedroads|packlista vandring`) så att webhooken vet vilken sajt och vilket keyword som ska publiceras.

---

## 3. Triggers för artikel-förslag

- **Cron (veckovis):** Efter Fas 2 (keyword-strategi) – skicka 1–5 artikel-förslag till Slack (en per prioriterad sajt eller enligt keyword-backlog).
- **Slack (på begäran):** *"Ge mig artikel-förslag för [sajt]"* eller *"Artikel-förslag för alla prioriterade sajter"*.

Agenten kör då Fas 1 (om behov) + Fas 2, och formaterar utdata enligt format ovan till Slack.

### 3.1 Användarcontext: länkar och "baserat på detta"

Användaren kan **skriva fritt** och lägga till kontext i samma meddelande, t.ex.:
- *"Jag vill att du producerar ett förslag baserat på detta"* + klistrad text eller beskrivning
- En **länk till en liknande artikel** (t.ex. konkurrent eller inspiration) – *"ge mig artikel-förslag i denna stil"* eller *"sånt här innehåll vill jag ha för [sajt]"*
- Flera länkar, krav på ton (mer teknisk, mer affärsdriven), eller målgrupp

**Du ska:** Läsa hela användarens meddelande. Om det finns URL:er – försök att använda dem (om du har tillgång till webbläsare/read URL) för att förstå stil, ämne eller struktur och anpassa förslagen därefter. Om du inte kan öppna länken, använd ändå användarens beskrivning (t.ex. "liknande denna artikel", "i den stilen") och formulera förslag som matchar. Svara alltid med tydliga artikel-förslag enligt format i §2.

---

## 4. Publicera-flödet (när användaren trycker Publicera)

1. **Användaren** trycker **Publicera** på ett förslag i Slack (eller skriver *"producera artikel för [sajt] om [keyword]"*).
2. **Om knapp:** Slack skickar en Interactivity-payload till en **Request URL** (webhook). Payload innehåller t.ex. `value` = `theunnamedroads|packlista vandring`. En liten tjänst (se nedan) tar emot anropet.
3. **Webhook-tjänsten** anropar OpenClaw (t.ex. skapar en session eller triggar cron) med meddelande: *"Du är SEO-agenten. Publicera artikel: sajt=theunnamedroads, keyword=packlista vandring. Kör Fas 3 (content brief) och Fas 4 (skrivning). Skicka brief till Slack för godkännande, sedan skriv artikeln och pusha till rätt repo enligt site-repos.json."*
4. **Agenten** kör Fas 3 → brief till Slack → väntar på godkännande → Fas 4 → skriver artikel → draft till Slack → godkännande → commit & push till GitHub. Sajten (Vercel/Netlify) bygger och publicerar automatiskt.

**Krav för knappen:** Slack-appen måste ha **Interactivity** aktiverat med en **Request URL** (HTTPS). OpenClaw använder Socket Mode och exponerar inte nödvändigtvis denna URL – då behövs en **liten egen tjänst** (t.ex. på Coolify) som:
- Tar emot POST från Slack (interaction payload).
- Parsar `value` (umamiName|keyword).
- Anropar OpenClaw Gateway API (session create eller liknande) med instruktion att publicera den artikeln.
- Svarar till Slack med 200 OK (och ev. uppdaterar meddelandet med "Publiceras …").

Se **openclaw/SLACK-PUBLISH-SETUP.md** för steg-för-steg koppling av Request URL och exempel på webhook.
