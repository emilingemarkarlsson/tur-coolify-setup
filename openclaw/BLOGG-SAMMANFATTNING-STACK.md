# Sammanfattning: Min self-hosted AI- och automationsstack (Coolify, LiteLLM, OpenClaw, n8n)

**Syfte:** Underlag för ett blogginlägg på din personliga sajt (t.ex. emilingemarkarlsson.com). Redigera fritt och anpassa ton/längd.

---

## Vad är det här?

En helt self-hostad stack för AI-chat, agenter och automation – utan att lägga allt hos OpenAI eller andra SaaS. Allt körs på egen infrastruktur (Hetzner + Coolify), med öppen källkod och full kontroll över data och kostnader.

---

## Delar i stacken

### Coolify (grunden)
- **Vad:** Self-hosted PaaS (alternativ till Heroku/Vercel). Hanterar Docker-containers, domäner, SSL, miljövariabler och deploy.
- **Roll:** Alla tjänster nedan körs som Coolify-"resources" på samma server. Enkel att lägga till nya tjänster, backa upp och uppdatera.

### LiteLLM (AI-proxy)
- **Vad:** En proxy som pratar OpenAI-kompatibel API (`/v1/chat/completions`) men routar anrop till olika modeller (OpenAI, Anthropic, Google Gemini, DeepSeek m.fl.).
- **Roll:** En enda "API-nyckel" (master key) och en enda URL. Alla tjänster som behöver LLM (OpenClaw, Open WebUI, n8n, Langflow) pekar hit i stället för till varje leverantör. Du byter modell eller lägger till ny provider i LiteLLM – inget behöver ändras i OpenClaw eller n8n.
- **Bonus:** Du kan sätta spending limits, logga användning och se kostnad per request i LiteLLM UI.

### OpenClaw (AI-agent)
- **Vad:** En AI-agent som kan köra verktyg (läsa filer, köra script, söka i minne) och prata med användaren via Slack (eller annat gränssnitt).
- **Roll:** I min setup används OpenClaw som **SEO- och sajtagent**: den planerar innehåll, föreslår artiklar utifrån trafik (Umami) och innehållsplaner, skriver utkast och – efter godkänn i Slack – publicerar till GitHub så att Netlify bygger sajten. Allt styrs från Slack med korta kommandon ("artikel-förslag för emilingemarkarlsson", "publicera slug").
- **Teknisk koppling:** OpenClaw får `OPENAI_API_BASE` = LiteLLM-URL och `OPENAI_API_KEY` = LiteLLM master key. Då använder både chatt och verktyg (t.ex. memory search) samma API.

### n8n (workflow-automation)
- **Vad:** Visuell workflow-motor (nod-baserad), typ Zapier/Make men self-hosted.
- **Roll:** Schemalagda eller triggade flöden: t.ex. hämta data från Umami → formatera → (valfritt) skicka till LiteLLM för sammanfattning → posta till Slack. Du kan också köra n8n → OpenClaw (n8n hämtar data, OpenClaw skriver rapporten). I SEO-flödet valde jag att hålla huvudlogiken i OpenClaw (en agent, tydliga "Nästa steg" i Slack) och använda n8n mer som komplement där det passar (t.ex. daglig Umami-sammanfattning om man vill ha det via n8n i stället för OpenClaw-cron).

### Övriga tjänster i samma Coolify-projekt
- **Umami** – analytics (besök, topp-sidor). Används av OpenClaw för att prioritera sajter och artikelförslag.
- **MinIO** – S3-kompatibel lagring (filer, backup).
- **Langflow** – visuell byggare av AI-flöden (kan också använda LiteLLM).
- **Open WebUI** – chat-gränssnitt mot LiteLLM (för manuell chat utanför Slack).

---

## Vad vi implementerat (SEO + content)

1. **En agent, flera sajter**  
   OpenClaw har en instruktionsuppsättning (SEO-SITE-AGENT) som gäller alla sajter. Sajt väljs via kommandot (t.ex. "artikel-förslag för emilingemarkarlsson"). Varje sajt har en egen planfil (språk, pillars, content gaps).

2. **Slack som kontrollpanel**  
   Användaren behöver inte memorera kommandon. Varje svar från agenten avslutas med "Nästa steg:" och exakt vad man ska skriva (t.ex. "Skriv: publicera min-artikel-slug"). Godkänn/kassera med siffra (1–5) eller "Godkänn" / "kassera slug".

3. **Draft → GitHub → Netlify**  
   Utkast sparas i containern; vid "publicera slug" kör agenten ett script som läser draft + metadata, hittar rätt repo (site-repos.json), committar och pushar. Netlify bygger sajten automatiskt. Ingen manuell copy-paste till repo.

4. **Påminnelse utan AI-kostnad**  
   En enkel cron på servern (t.ex. 09:00) anropar Slack Incoming Webhook med en påminnelse ("Dags att tänka på ny artikel"). Inga API-anrop, inga krediter – bara så man inte glömmer bort flödet.

5. **Säkerhet**  
   API-nycklar, GitHub-token och webhook-URL:er ligger i Coolify Environment Variables eller i filer på servern – inte i repot. Install-script synkar bara agentfiler, planer och script till OpenClaw-containern.

---

## Varför den här kombinationen?

- **LiteLLM i mitten:** En plats för alla LLM-anrop. Byta modell eller lägga till DeepSeek/Gemini kräver bara konfiguration i LiteLLM, inte i varje tjänst.
- **OpenClaw för "agent-jobb":** SEO-planering, keyword-strategi, brief, skrivning och publicering kräver steg, verktyg (script, läsning av filer) och konsekvent "Nästa steg" – det passar en agent bättre än att bygga många små n8n-flöden.
- **n8n kvar:** Användbart för tidsstyrda eller event-drivna flöden (t.ex. "varje morgon hämta X och skicka till Slack/OpenClaw") och för att koppla in tjänster som inte OpenClaw pratar med direkt.
- **Coolify:** Ett ställe att deploya, se loggar, sätta env-vars och uppdatera – utan att manuellt hantera docker-compose på servern varje gång.

---

## Kort flöde (SEO-artikel)

1. **Påminnelse** (cron) → Slack: "Vill du ha artikel-förslag?"
2. **Användaren** skriver: "artikel-förslag för emilingemarkarlsson".
3. **OpenClaw** (via LiteLLM) analyserar plan + Umami, skickar 3–5 förslag till Slack med "Nästa steg: Skriv 1–5 eller producera artikel för … om …".
4. **Användaren** svarar t.ex. "2" eller "Godkänn" → agenten skriver brief, sedan draft.
5. **Användaren** skriver "publicera slug" → agenten kör publish-script → push till GitHub → Netlify deployar.
6. **Agenten** bekräftar i Slack med länk till den publicerade artikeln.

---

## Tekniska noter (för den som vill reproducera)

- **OpenClaw ↔ LiteLLM:** Sätt i Coolify (OpenClaw): `OPENAI_API_BASE` = LiteLLM-URL (t.ex. `https://litellm.…/v1`), `OPENAI_API_KEY` = LiteLLM master key. Då fungerar både chat och verktyg (memory search m.m.). Vid "Invalid OpenAI API key" – kontrollera att nyckeln är samma som i LiteLLM och att ingen budget/spend-limit i LiteLLM har trätt i kraft så att anrop nekas.
- **Ny sajt:** Lägg till i `site-repos.json` (repo, contentPath, domain), skapa en planfil under `openclaw/agents/plans/`, kör install-script, testa med "artikel-förslag för [sajt]" i Slack.
- **Docs i repot:** OPENCLAW-OVERBLICK.md (översikt + felsökning), GIT-SETUP.md (token, publish), SNABBKOMMANDON.md (Slack), SETUP-SEO-OPENCLAW.md (full setup).

---

## Slutsats (för blogginlägget)

Du kan formulera det ungefär så här: *"Jag kör en self-hosted stack med Coolify som bas, LiteLLM som enda AI-gateway, OpenClaw som agent för SEO och content, och n8n för workflow-automation. Allt styrs från Slack – artikel-förslag, godkänn, publicera – och Netlify bygger sajten vid push. Det ger kontroll över data och kostnad, och en tydlig väg från idé till publicerad artikel."*

Redigera och ta bort det som inte passar din sajt eller din ton.
