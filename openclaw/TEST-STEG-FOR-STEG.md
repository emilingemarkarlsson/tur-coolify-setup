# Testa SEO-artikelflödet steg för steg

Använd denna checklista för att testa hela kedjan: **artikel-förslag → producera artikel → godkänn brief → godkänn draft → publicera → verifiera i Slack**.

---

## Före du börjar (en gång)

- [ ] **Git-token:** `GITHUB_TOKEN` är satt i Coolify (Environment Variables för OpenClaw) och containern har startats om. Se **openclaw/GIT-SETUP.md**.
- [ ] **Slack:** OpenClaw svarar i kanalen **#all-tur-ab** (eller den kanal du använder). Om du triggar via cron ska cron-jobbet peka på samma kanal.
- [ ] **Netlify:** Sajten emilingemarkarlsson.com är kopplad till repot `emilingemarkarlsson/emilingemarkarlsson-astro-theme` och bygger vid push till `main`.

---

## Steg 1: Be om artikel-förslag

1. Öppna **Slack** och gå till kanalen **#all-tur-ab** (eller där OpenClaw svarar).
2. Skriv exakt:
   ```text
   artikel-förslag för emilingemarkarlsson
   ```
3. **Förväntat:** Agenten skickar 1–5 förslag med sajt, keyword, förslag på titel, prioritet och motivering. Varje förslag avslutas med **"Nästa steg:"** och en färdig rad att kopiera.

---

## Steg 2: Välj ett förslag och be om artikel

**Enklast:** skriv bara en **siffra** – t.ex. `2` för förslag #2. Agenten tolkar det som "skriv artikel för det förslaget" och skickar content brief.

Eller kopiera raden under **"Nästa steg:"** (t.ex. `producera artikel för emilingemarkarlsson om data-pipeline-guide`).

**Förväntat:** Agenten skickar en **content brief** och ber dig godkänna.

---

## Steg 3: Godkänn brief

1. Skriv i Slack:
   ```text
   Godkänn
   ```
   eller t.ex. **OK** / **OK, skriv**.
2. **Förväntat:** Agenten skriver artikeln och skickar sedan **draften** (eller sammanfattning + första stycken) till Slack. Meddelandet avslutas med **"Nästa steg:"** och t.ex. *"För att publicera: skriv *publicera min-artikel-slug*. För att kassera: skriv *kassera min-artikel-slug*."*

---

## Steg 4: Publicera draften

1. Notera **slugget** som agenten nämnde (t.ex. `data-pipeline-guide` eller `seo-for-bloggare`).
2. Skriv i Slack (ersätt `{slug}` med det faktiska slugget):
   ```text
   publicera {slug}
   ```
   T.ex. `publicera data-pipeline-guide`.
3. **Förväntat:** Agenten kör publish-scriptet. Om det lyckas får du ett svar i stil med:
   - *"✅ Publicerat. Ny fil i GitHub (src/content/blog/{slug}.md) och push skickad. Netlify bygger automatiskt – verifiera att artikeln är live här (kan ta 1–2 min): https://emilingemarkarlsson.com/blog/{slug}"*
4. Om du får fel (t.ex. Git-token saknas): följ **openclaw/GIT-SETUP.md** och testa igen.

---

## Steg 5: Verifiera

1. **I Slack:** Klicka på länken som agenten skickade (t.ex. `https://emilingemarkarlsson.com/blog/data-pipeline-guide`).
2. **I webbläsaren:** Vänta 1–2 minuter om Netlify fortfarande bygger. Ladda sedan om sidan – din nya artikel ska vara live.
3. **I GitHub (valfritt):** Öppna repot `emilingemarkarlsson/emilingemarkarlsson-astro-theme` → `src/content/blog/` – du ska se en ny fil `{slug}.md` med senaste commit från OpenClaw.

---

## Snabbreferens – vad ska jag skriva i Slack?

| Vad du vill göra | Skriv i Slack |
|------------------|----------------|
| Få artikel-förslag | `artikel-förslag för emilingemarkarlsson` |
| Skriva en artikel | `producera artikel för emilingemarkarlsson om [keyword]` |
| Godkänn brief | `Godkänn` eller `OK, skriv` |
| Publicera draft | `publicera [slug]` (slug står i agentens meddelande) |
| Kassera draft | `kassera [slug]` |

---

## Felsökning

| Problem | Åtgärd |
|--------|--------|
| **Inget svar i Slack** | 1) **@-nämn boten** – skriv t.ex. `@OpenClaw artikel-förslag för emilingemarkarlsson` (byt @OpenClaw mot din bots namn under Apps). 2) Kontrollera att boten är inbjuden i kanalen: `/invite @OpenClaw` i #all-tur-ab. 3) Om loggen visar "channel not allowed": se **openclaw/SLACK-CHANNEL-ALLOW.md** och sätt `groupPolicy: "open"` för Slack. |
| "Git-token saknas" / push misslyckas | Sätt `GITHUB_TOKEN` i Coolify enligt **GIT-SETUP.md**, starta om containern. |
| Länken ger 404 | Netlify kan ta 1–2 min att bygga. Kontrollera i Netlify att senaste deploy lyckades. För Astro är URL oftast `/blog/{slug}`. |
| Vill bara testa utan att publicera | Efter steg 3 skriv `kassera [slug]` i stället för `publicera [slug]` – då tas bara draften bort, inget pushas. |
