# Godkänn & publicera från Slack (enkelt flöde)

**Mål:** Få förslag på artiklar i Slack → godkänn → publicera på sajten. Inte godkänn → inget händer. Inget n8n eller Google Sheet krävs.

**Du behöver bara komma ihåg hur du startar** (t.ex. *"artikel-förslag för emilingemarkarlsson"*). Varje meddelande från agenten avslutas med **"Nästa steg:"** – då står det exakt vad du ska skriva härnäst (ofta en rad att kopiera). Du behöver inte memorera kommandon.

---

## Så fungerar kedjan (artikel → GitHub → Netlify → verifiering)

| Steg | Vad som händer |
|------|----------------|
| 1 | Du skriver **publicera {slug}** i Slack. |
| 2 | Agenten kör script som skriver draften till **ny fil** i rätt repo, t.ex. `src/content/blog/{slug}.md`, och gör **commit + push** till GitHub. |
| 3 | **Netlify** (om sajten är kopplad till det repot) ser push och **startar en ny deploy** automatiskt. Inget extra steg behövs – Netlify är vanligtvis kopplat till GitHub-repot så att varje push till main triggar build. |
| 4 | Agenten svarar i Slack med **en länk** till den publicerade artikeln (t.ex. `https://emilingemarkarlsson.com/blog/{slug}`). **Klicka på länken** för att verifiera att artikeln är live (Netlify kan ta 1–2 minuter). |

**Kontroll:** Så att Netlify verkligen bygger vid push: i Netlify → Site → Build & deploy → Build settings ska "Branch to deploy" vara samma som du pushar till (vanligtvis `main`). Då är allt uppsatt.

---

## Flöde

1. **Förslag:** Du skriver i Slack t.ex. *"artikel-förslag för emilingemarkarlsson"*. Agenten skickar 1–5 förslag (sajt, keyword, titel, prioritet).

2. **Skriv artikel:** Du skriver *"producera artikel för emilingemarkarlsson om [keyword]"*. Agenten gör brief → du godkänner → agenten skriver draft.

3. **Draft till Slack:** Agenten sparar draften i containern (`/data/.openclaw/drafts/{slug}.md`) och skickar den (eller en sammanfattning) till Slack med texten:
   - *"För att publicera: skriv *publicera {slug}* (eller *publish {slug}*). För att kassera: skriv *kassera {slug}*."*

4. **Godkänn → publicera:** Du svarar i Slack med **publicera data-pipeline-guide** (eller vilket slug som stod). Agenten läser draften, pushar till rätt GitHub-repo (enligt site-repos.json), sajten bygger (Vercel/Netlify). Bekräftelse skickas till Slack.

5. **Inte godkänn:** Du svarar **kassera data-pipeline-guide** – då tas draften bort och inget publiceras. Eller du svarar inte alls – då händer inget.

---

## Krav

- **Git i OpenClaw:** Containern måste kunna pusha till GitHub (SSH-nyckel eller PAT). Annars kan agenten inte publicera; du får då draft i Slack och pushar manuellt.
- **Inget n8n:** Flödet använder bara OpenClaw + filer i containern + Slack. Vill du använda n8n (t.ex. ditt befintliga Eik SEO Publisher-flöde) är det ett **valfritt** tillägg – se openclaw/SEO-N8N-APPROVE-INTEGRATION.md.

---

## Säkerhet

- Endast du (och de som kan skriva i samma Slack-kanal) kan trigga "publicera" eller "kassera".
- Draften ligger i containern tills den publiceras eller kasseras; den syns inte utåt förrän den pushas till repo.
