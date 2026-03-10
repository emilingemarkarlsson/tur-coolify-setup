# (Valfritt) Koppla Slack till n8n för Approve → deploy

**Standardflödet kräver inte n8n.** Du kan bara skriva *"publicera {slug}"* i Slack så pushar agenten från containern till GitHub. Se **openclaw/SLACK-APPROVE-PUBLISH.md**.

Denna guide är för dig som **redan har** ett n8n-flöde (t.ex. Eik SEO Publisher med Google Sheet och Netlify) och vill använda det istället för eller utöver det enkla flödet.

---

## 1. Så fungerar ditt n8n-flöde idag (Eik SEO Publisher)

| Steg | Nod | Vad som händer |
|------|-----|----------------|
| 1 | **Webhook** `seo-approve` | GET med query: `action=approve`, `slug`, `keyword` |
| 2 | **Check If Approved** | Om `action=approve` → fortsätt; annars → rejection |
| 3 | **Extract Slug** | Läser slug, keyword från query |
| 4 | **Acknowledge in Slack** | Skickar "⏳ Publishing article: {slug}..." |
| 5 | **Find Article Metadata** | Läser från **Google Sheet** (document + Sheet1) |
| 6 | **Get Draft Content** | Hittar rad där `slug` matchar, plockar `draft_content` och `keyword` |
| 7 | **Encode → Publish to GitHub** | Base64, PUT till `emilingemarkarlsson/emilingemarkarlsson-astro-theme` → `src/content/blog/{slug}.md` |
| 8 | **Update Sheet Status** | Sätter status Published, published_date, url, commit (match på keyword) |
| 9 | **Trigger Netlify Deploy** | Build hook |
| 10 | **Notify Success** | Slack med länk till artikeln |
| 11 | **Respond to Webhook** | HTML-sida "Article Approved!" |

**Viktigt:** Draften förväntas redan finnas i **Google Sheet** med kolumner som innehåller `slug`, `keyword`, `draft_content`. Approve-länken triggar bara flödet med slug + keyword; innehållet hämtas från Sheet.

---

## 2. Gap: var kommer draften ifrån när OpenClaw skickar till Slack?

- **OpenClaw:** Agenten skriver artikeln och skickar **draft till Slack** (text i meddelande eller fil).
- **n8n:** Förväntar sig draft i **Google Sheet** och en **länk** med `?action=approve&slug=...&keyword=...`.

För att det ska fungera behöver draften **hamna i Sheet** (eller n8n måste hämta den från Slack – se alternativ nedan) innan du klickar Approve.

---

## 3. Lösning A: "Store draft" webhook + script (rekommenderat)

När agenten har draften klar: först **skicka den till n8n** så att den skrivs till Sheet, sedan **posta till Slack** med en **Approve-länk** som pekar på ditt befintliga n8n-flöde.

### 3.1 Nytt n8n-flöde: "Store SEO draft"

Ett enkelt flöde som tar emot draft och skriver till samma Google Sheet:

1. **Webhook** – POST, path t.ex. `seo-store-draft`. Body: JSON `{ "slug": "...", "keyword": "...", "content": "..." }` (content = hela markdown-draften inkl. frontmatter).
2. **Code** (valfritt) – validera slug/keyword/content.
3. **Google Sheets** – **append** en rad till samma sheet med kolumner: `slug`, `keyword`, `draft_content` (och ev. `status: Draft` om du har den kolumnen). Eller **update** om rad med samma slug redan finns (så du inte får dubbletter).

Sheet-struktur som ditt befintliga flöde förväntar sig (från Get Draft Content): rader med `slug`, `keyword`, `draft_content`. "Find Article Metadata" hämtar alla rader; "Get Draft Content" matchar på `slug`. Så Store-flödet ska antingen:
- **Lägga till** en ny rad med slug, keyword, draft_content, eller
- **Uppdatera** befintlig rad med samma slug (om du vill att samma slug alltid ska uppdateras).

Ett minimalt flöde (för import i n8n):

- Webhook (POST, path `seo-store-draft`, body JSON).
- Code: `const body = $input.item.json.body || $input.item.json; return { slug: body.slug, keyword: body.keyword || '', draft_content: body.content || body.draft_content };`
- Google Sheets: Append row till samma document/sheet med columns slug, keyword, draft_content.
- Respond to Webhook: 200 OK.

Du behöver skapa detta flöde i n8n (eller importera om vi lägger till en JSON-fil).

### 3.2 Script i OpenClaw som anropar "Store draft"

Scriptet **openclaw/scripts/store-seo-draft.sh** kopieras till containern när du kör `./scripts/openclaw-install-seo-agent.sh`. Det läser draft från en fil och POST:ar till n8n.

- **Anrop:** `store-seo-draft.sh <slug> "<keyword>" <path-to-draft.md>`
- **Krav:** `jq` i containern (samma som för umami-script; kör ev. `openclaw-install-umami-script.sh` först så att jq finns).

**Webhook-URL** för Store draft – sätt **en** av:

- **Miljö i Coolify:** `N8N_STORE_DRAFT_WEBHOOK_URL=https://din-n8n.example.com/webhook/seo-store-draft`
- **Fil i containern:** skapa `/data/.openclaw/n8n-store-draft-url` med raden `https://din-n8n.example.com/webhook/seo-store-draft`

**Approve-länk (i Slack-meddelandet):** Agenten behöver bas-URL för n8n så att den kan bygga länken. Sätt **en** av:

- **Miljö:** `N8N_WEBHOOK_BASE_URL=https://din-n8n.example.com` (utan /webhook/...)
- **Fil:** `/data/.openclaw/n8n-approve-base-url` med raden `https://din-n8n.example.com`

Då blir Approve-länken: `{N8N_WEBHOOK_BASE_URL}/webhook/seo-approve?action=approve&slug={slug}&keyword={url-encoded-keyword}`

### 3.3 Instruktion till agenten (Fas 4)

I **SEO-SITE-AGENT.md** (eller SEO-PROCESS) lägger du till:

När du ska skicka draft till Slack för **emilingemarkarlsson** (eller annan sajt som har n8n Approve-koppling):

1. Spara den färdiga draften (hela markdown inkl. frontmatter) till en fil, t.ex. `/tmp/seo-draft-{slug}.md`.
2. Anropa store-draft så draften hamnar i Google Sheet: kör scriptet `/data/.openclaw/scripts/store-seo-draft.sh` med argumenten slug, keyword och sökväg till draft-filen. (Om scriptet eller webhook-URL saknas, skippa steg 2 och skriv i Slack att användaren kan kopiera draften manuellt till Sheet eller använda vanlig Git-push.)
3. Posta till Slack: kort sammanfattning + första stycken (eller hela draften om kort), och **inkludera Approve-länken** så att användaren kan klicka och publicera:
   `Approve & publish: https://din-n8n.example.com/webhook/seo-approve?action=approve&slug={slug}&keyword={keyword}`
   (Ersätt {slug} och {keyword} med faktiska värden; keyword URL-encoda om det innehåller mellanslag.)

Då kan användaren i Slack klicka på länken → n8n kör ditt befintliga flöde → draft hämtas från Sheet → GitHub → Netlify → Slack-notis.

---

## 4. Lösning B: n8n hämtar draft från Slack-meddelandet

I stället för att skriva till Sheet kan n8n **läsa draften från det Slack-meddelande där användaren klickar**.

- **Approve-länk:** inkludera inte bara slug och keyword utan också **channel** och **message ts** (t.ex. `channel=C07TJRLTM9C&ts=1234567890.123456`). När agenten postar draft till Slack får den (om Slack API används) tillbaka `channel` och `ts` – dessa kan sättas in i länken.
- **n8n:** Efter "Extract Slug" – anropa **Slack API** `conversations.history` med channel + ts, hämta meddelandet, extrahera draft-text från `text` eller från `blocks`. Om draften är i en fil som bifogats till meddelandet, använd Slack `files.sharedPublicURL` eller liknande för att hämta filinnehållet.
- **Därefter:** samma kedja (Base64 → GitHub → Netlify → notify). Du behöver **inte** skriva till Google Sheet för draft; du kan fortfarande uppdatera Sheet med status efter publicering om du vill.

**Nackdel:** Slack truncate:ar långa meddelanden; för väldigt långa artiklar behöver draften postas som fil, och n8n måste hantera filhämtning. **Fördel:** Ingen "Store draft" webhook eller script i OpenClaw.

---

## 5. Sammanfattning – vad du behöver göra

| Steg | Åtgärd |
|------|--------|
| 1 | Skapa n8n-flöde **"Store SEO draft"**: POST webhook → Google Sheets (append/update slug, keyword, draft_content). |
| 2 | Säkerställ att **Eik SEO Publisher** (seo-approve) använder samma Sheet och att "Get Draft Content" matchar på `slug` (så att den nya raden hittas). |
| 3 | Lägg scriptet **store-seo-draft.sh** i OpenClaw-containern och sätt **N8N_STORE_DRAFT_WEBHOOK_URL** (eller motsvarande) till din Store-draft webhook-URL. |
| 4 | Uppdatera **agentinstruktioner** (SEO-SITE-AGENT eller process): för emilingemarkarlsson (eller sajter med n8n-koppling), spara draft till fil → kör store-seo-draft.sh → posta till Slack med **Approve-länk** till `seo-approve?action=approve&slug=...&keyword=...`. |
| 5 | Testa: be agenten skriva en draft för emilingemarkarlsson → kontrollera att en rad dyker upp i Sheet → klicka Approve-länken i Slack → kontrollera att n8n publicerar till GitHub och att Netlify bygger. |

När det är på plats: **artikel kommer till Slack → du klickar Approve (länken) → n8n deployar** enligt ditt befintliga flöde.

---

## 6. Repo-struktur (för script och konfig)

- **Script:** `scripts/store-seo-draft.sh` (i repot) – install-scriptet kan kopiera det till `/data/.openclaw/scripts/` i containern.
- **Webhook-URL:** Sätts i containern via miljö (Coolify) eller fil, t.ex. `/data/.openclaw/n8n-store-draft-url` som scriptet läser.
- **n8n-flöden:** Ditt Eik SEO Publisher-flöde behöver du inte ändra (förutom att Sheet har rätt kolumner). Det nya "Store SEO draft"-flödet kan du spara som egen JSON i repot under t.ex. `n8n/workflows/` om du vill versionera det.
