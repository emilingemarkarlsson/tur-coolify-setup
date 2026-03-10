# SEO-playbook – kvalitetskrav för content

All content som produceras av SEO & Site Intelligence Agent ska följa denna playbook. Den speglar best practice 2025–2026: EEAT, användarintent, tekniska krav och språk.

---

## 1. Sökintention (search intent)

- **Informativ:** tillfredsställ användarens fråga med tydlig, strukturerad information; inkludera svar högst upp (featured snippet-vänligt).
- **Transaktionell:** tydlig CTA, steg-för-steg eller jämförelse där det passar.
- **Navigational:** snabb identifiering av det användaren letar efter (t.ex. produkt, tjänst, sida).

Artikeln ska **matcha** det keyword som briefen anger; ingen intent-blandning utan motivering.

---

## 2. EEAT (Experience, Expertise, Authoritativeness, Trustworthiness)

- **Experience:** där det är relevant, använd konkreta exempel, fall eller egna erfarenheter (utan att hitta på).
- **Expertise:** terminologi och djup som passar ämnet; citera källor där det stärker trovärdigheten.
- **Authoritativeness:** interna länkar till andra starka sidor på sajten; ev. externa länkar till auktoritativa källor.
- **Trustworthiness:** källhänvisningar (länk eller tydlig referens); inga påståenden utan stöd.

Källor ska vara **namngivna** (organisation eller titel); undvik "källor säger" utan att ange vilka.

---

## 3. Struktur och läsbarhet

- **H1:** en per sida; innehåller target keyword (naturligt).
- **H2/H3:** logisk hierarki; varje rubrik ska kunna förstås utan kontext.
- **Korta stycken:** 2–4 meningar; punktlistor och numrerade listor där det underlättar.
- **Första stycket:** innehåller huvudfrågan/svaret inom ~100 ord (snippet-vänligt).
- **Längd:** enligt content brief (vanligtvis 1200–2500 ord för informativ content).

---

## 4. Interna länkar

- **Minst 3–5 interna länkar** till befintliga sidor på samma sajt (från briefen eller Umami topp-sidor).
- Ankartext ska vara **beskrivande** (inte "klicka här" eller generisk "läs mer"); gärna semantisk koppling till target keyword eller relaterat begrepp.
- Länka till sidor som **logiskt tillhör** ämnet (samma pillar eller närliggande).

---

## 5. Tekniska krav (frontmatter och meta)

- **Frontmatter** exakt enligt sajtens schema (t.ex. från `src/content/config.ts` eller README):
  - `title` (ofta = H1 eller SEO-titel)
  - `description` (meta description, 150–160 tecken, inkl. target keyword)
  - **Datum:** Astrosajter kan använda antingen `publishDate` eller `publishedDate` beroende på implementation. Använd ett giltigt ISO 8601-datum som sträng, t.ex. `2026-02-23` eller `2026-02-23T12:00:00.000Z`. Fel fältnamn eller ogiltigt datum ger build-fel. **Kolla alltid per sajt:** t.ex. *emilingemarkarlsson.com* kräver `publishDate`, medan *theunnamedroads.com* kräver `publishedDate` (definierat i respektive planfil).
  - `tags` (relevanta, konsekventa med sajten)
  - `heroImage` / `image` om sajten kräver det
- **Ingen keyword-stuffing:** keyword ska förekomma naturligt i titel, beskrivning och body; inte upprepas onödigt.
- **Slug/filnamn:** kebab-case, läsbart, reflekterar innehållet (t.ex. `hur-du-valjer-tema-astro.md`).

---

## 6. Språk och målgrupp

- **Språk:** Skriv **alltid i sajtens språk**. Om sajten är på engelska (t.ex. emilingemarkarlsson.com) → hela artikeln på **engelska**. Om sajten är på svenska → svenska. Kontrollera planfilen (`seo-plan-{umamiName}.md`) eller domain; många sajter anger "Site language: English" i planen.
- **Författarstil (author voice):** Om planen eller användaren beskriver en distinkt stil (t.ex. "Emil's style", "så här skriver jag") – följ den: samma ton, person (jag/vi), längd på meningar och typ av exempel. Det gör att artiklarna känns konsekventa med resten av sajten och sticker ut som äkta, inte generiska.
- **Ton:** Professionell men tillgänglig; undvik jargong om målgruppen är bred. Tekniska sajter kan vara mer djupgående och terminologirika.
- **Aktualitet:** Skriv för 2025–2026 (datum, referenser); undvik föråldrade påståenden.

---

## 7. Visuella element (flödesscheman, diagram, grafik)

- **Låt artiklarna sticka ut:** Där det förklarar eller förstärker innehållet, inkludera **enkla visuella element** – flödesscheman, processdiagram, systemarkitektur eller konceptbilder. Det ökar läsbarhet, delning och tid på sidan (bra för SEO) och skiljer artikeln från ren löpande text.
- **Vad du kan använda:**
  - **Mermaid** (om sajten/sidan renderar det): flöden (`flowchart`), sekvenser (`sequenceDiagram`), enkla diagram. Använd i markdown med ` ```mermaid ` … ` ``` `.
  - **ASCII-art eller enkla textdiagram** för processer/steg – fungerar överallt.
  - **Beskrivning för bild:** Om du inte kan generera bilder, skriv en tydlig **alt-beskrivning** och en kort "Image suggestion: [beskrivning]" så att användaren eller ett verktyg kan skapa en enkel grafik senare (t.ex. flowchart, pipeline, arkitekturschema).
- **Placering:** Efter introduktion av ett koncept, före eller efter en steg-för-steg, eller vid jämförelser (t.ex. "före/efter", "steg 1–4"). Max några per artikel så det inte blir rörigt; prioritera det som ger mest nytta.

---

## 8. Vad vi undviker

- Inga fabricerade fakta eller källor.
- Ingen copy-paste från konkurrenter utan eget värde.
- Ingen dold text eller keyword-stuffing.
- Ingen överdriven intern länkning (max några relevanta per sektion).

---

## Referens i agent-instructions

Agenten ska alltid:

1. Läsa **SEO-PROCESS.md** för fasindelning (planering → keyword → brief → skrivning).
2. Följa **SEO-PLAYBOOK.md** (detta dokument) vid keyword-research, content brief och skrivning – inkl. **sajtens språk** (engelska/svenska enligt plan eller domain), **författarstil** om angiven, och **visuella element** (Mermaid/ASCII/bildbeskrivning) där det förbättrar artikeln.
3. Använda **SEO-SITE-AGENT.md** för tekniska detaljer (Umami, GitHub, Slack, repo-struktur).
