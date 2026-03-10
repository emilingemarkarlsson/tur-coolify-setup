# n8n Workflows

## store-seo-draft.json

**Syfte:** Tar emot en SEO-draft (POST med `slug`, `keyword`, `content`) och skriver den till samma Google Sheet som **Eik SEO Publisher** använder. Då kan OpenClaw-agenten spara draften här innan den postar till Slack med en "Approve"-länk; när användaren klickar triggas Eik SEO Publisher som publicerar från Sheet.

**Efter import i n8n:**
1. Sätt **Webhook** till POST (om det inte redan är GET/POST).
2. I **Append to Sheet**: välj samma **Google Sheet-dokument** och **ark** (Sheet1 / samma gid) som i Eik SEO Publisher, så att "Find Article Metadata" och "Get Draft Content" hittar raden på `slug`.
3. Koppla samma **Google Sheets-credentials** som i Eik SEO Publisher.
4. Aktivera flödet och kopiera **Webhook URL** (t.ex. `https://din-n8n.example.com/webhook/seo-store-draft`) till OpenClaw: sätt `N8N_STORE_DRAFT_WEBHOOK_URL` i containern eller skriv URL till `/data/.openclaw/n8n-store-draft-url`.

**Body-format:**  
`POST` med `Content-Type: application/json`:  
`{ "slug": "my-article-slug", "keyword": "my keyword", "content": "# Title\n\nFull markdown..." }`
