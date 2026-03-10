# Nästa steg: Artikel-förslag + publicera från Slack

För att **få förslag på artiklar för en sajt** (t.ex. emilingemarkarlsson) och sedan **publicera efter review direkt från Slack**.

---

## Steg 1: Säkerställ att allt är installerat

Kör (en gång) från repots rot:

```bash
./scripts/openclaw-install-seo-agent.sh
```

Då har agenten senaste filerna (inkl. SEO-ARTICLE-SUGGESTIONS.md och planer). Om du vill att förslagen för **emilingemarkarlsson** ska vara mer träffsäkra: fyll i **openclaw/agents/plans/emilingemarkarlsson.md** med pillars och gaps, kör sedan install igen.

---

## Steg 2: Få artikel-förslag för emilingemarkarlsson

**I Slack (#all-tur-ab)** – skriv till OpenClaw-boten:

```
artikel-förslag för emilingemarkarlsson
```

Du kan **lägga till kontext** i samma meddelande, t.ex.:
- *"Jag vill att du producerar ett förslag baserat på detta"* + klistrad text
- En **länk till en liknande artikel** – *"ge mig förslag i denna stil"* eller *"sånt innehåll vill jag ha"*
- Krav på ton, målgrupp eller ämnesinriktning

Agenten använder då planen, site-repos och din kontext (och om möjligt innehållet bakom länken) och skickar 1–5 konkreta artikel-förslag till kanalen.

---

## Steg 3: Review och publicera från Slack

När du ser ett förslag du vill använda:

1. **Starta** – skriv i Slack: *producera artikel för emilingemarkarlsson om [keyword]* (ersätt med keyword från förslaget).

2. **Godkänn brief** – agenten skickar en content brief. Svara t.ex. "Godkänn" eller "OK, skriv".

3. **Draft** – agenten skickar utkast till Slack och skriver: *"För att publicera: skriv *publicera {slug}* … För att kassera: skriv *kassera {slug}*."*

4. **Publicera eller kassera**  
   - **Publicera:** skriv i Slack **publicera {slug}** (eller **publish {slug}**). Agenten pushar då till rätt repo; sajten bygger (Vercel/Netlify). Inget n8n behövs.  
   - **Kassera:** skriv **kassera {slug}** – då tas draften bort och inget publiceras.  
   - **Gör inget:** då händer inget; draften ligger kvar.

**Krav:** OpenClaw-containern behöver Git-åtkomst (SSH eller PAT) till repona. Annars får du draft i Slack och pushar manuellt.

---

## Kort checklista

- [ ] `./scripts/openclaw-install-seo-agent.sh` kört
- [ ] (Valfritt) Fyll i **openclaw/agents/plans/emilingemarkarlsson.md** med pillars/gaps
- [ ] I Slack: skriv *"artikel-förslag för emilingemarkarlsson"* → vänta på förslag
- [ ] Välj ett förslag → skriv *"producera artikel för emilingemarkarlsson om [keyword]"*
- [ ] Godkänn brief i Slack → godkänn draft i Slack → artikel publiceras (eller pusha manuellt om Git saknas)

---

## Om du vill ha en "Publicera"-knapp

Idag: du skriver *"producera artikel för emilingemarkarlsson om [keyword]"* i Slack.  
För en **knapp** som triggar samma sak krävs en webhook (Request URL) som tar emot Slack-klick och anropar OpenClaw – se **SLACK-PUBLISH-SETUP.md**.
