# Knappar i Slack (valfritt / avancerat)

**Enklare variant:** Du behöver inga knappar. Använd bara **korta svar** – se **openclaw/SNABBKOMMANDON.md**. T.ex. siffra (1–5) för att välja förslag, sedan "Godkänn" och "publicera slug".

Om du ändå vill ha **knappar** (klicka i stället för att skriva) gäller nedan.

---

## Vad som behövs

1. **Slack Interactivity** – aktiverat för din app, med en **Request URL** som pekar på en egen tjänst (webhook).
2. **En webhook-tjänst** (t.ex. på Coolify) som:
   - Tar emot POST från Slack när någon klickar på en knapp.
   - Utför rätt åtgärd (kör script, skickar meddelande till kanalen, eller anropar OpenClaw).
   - Svarar till Slack med `200 OK` inom några sekunder (obligatoriskt).

Knappar i meddelanden kräver **Block Kit** – dvs. agenten eller webhooken måste skicka meddelanden med `blocks` (knappar) i stället för bara text. Idag skickar agenten vanlig text; för knappar behöver antingen agenten använda Slack API med blocks, eller en tjänst som läser innehåll och postar ett nytt meddelande med knappar.

---

## Vilka knappar kan vi ha?

| Steg i flödet | Knapp | Åtgärd (webhook) |
|---------------|--------|-------------------|
| **Artikel-förslag** | "Skriv denna" | Skicka meddelande till kanalen (samma tråd): "producera artikel för {sajt} om {keyword}" så att agenten svarar. Eller anropa OpenClaw API med samma text. |
| **Efter content brief** | "Godkänn" | Skicka "Godkänn" i samma tråd (eller anropa OpenClaw) så att agenten går vidare till skrivning. |
| **Efter draft** | "Publicera" / "Kassera" | **Publicera:** kör `publish-draft.sh {slug}` (webhook kan SSH:a till servern och köra scriptet – behöver inte gå via agenten). **Kassera:** ta bort draft-filer eller bara uppdatera meddelandet "Kasserad". |
| **Publicera (direkt)** | "Publicera" med slug | Samma som ovan – kör scriptet, rapportera till Slack via response_url. |

Enklast att implementera först: **knappen "Publicera"** (value = slug). Då behöver webhooken bara köra `publish-draft.sh` (t.ex. via SSH + docker exec) och uppdatera Slack-meddelandet – ingen OpenClaw-API.

---

## Steg 1: Aktivera Interactivity i Slack

1. Gå till [api.slack.com/apps](https://api.slack.com/apps) → välj din app (samma som OpenClaw).
2. **Interactivity & Shortcuts** → **Interactivity** → **On**.
3. **Request URL:** sätt till din webhook-URL (HTTPS), t.ex. `https://din-tjanst.coolify.app/slack-interaction` (fyll i när tjänsten är uppe).

---

## Steg 2: Bygg en minimal webhook (först för "Publicera")

Webhooken ska:

1. Ta emot POST med `application/x-www-form-urlencoded`; body innehåller nyckeln `payload` (JSON-sträng).
2. Verifiera att anropet kommer från Slack (t.ex. **Slack Signing Secret** – signatur i header `X-Slack-Signature`).
3. Parsa `payload` → JSON. Hämta `actions[0].action_id` och `actions[0].value`.
4. Om `action_id` = `publish_draft` och `value` = slug (t.ex. `n8n-data-pipeline-tutorial`):
   - Köra publiceringsscriptet (t.ex. SSH till `tha` och `docker exec <container> /data/.openclaw/scripts/publish-draft.sh <slug>`).
   - Använda `response_url` från payload för att uppdatera meddelandet i Slack (t.ex. "✅ Publicerad: https://...") med en POST till den URL:en.
5. Svara till Slack med **200 OK** **inom 3 sekunder** (annars visar Slack fel). Om scriptet tar längre tid: svara 200 direkt och gör scriptet + uppdatering av meddelandet i bakgrunden.

Exempel på payload (utdrag):

```json
{
  "type": "block_actions",
  "actions": [{ "action_id": "publish_draft", "value": "n8n-data-pipeline-tutorial" }],
  "response_url": "https://hooks.slack.com/actions/..."
}
```

I repot finns (nedan) en skiss för en **minimal Node/Express-webhook** som du kan deploya på Coolify. Den hanterar bara "Publicera"-knappen.

---

## Steg 3: Knappar i meddelanden (Block Kit)

För att ett meddelande ska ha knappar måste det skickas med **blocks**. Idag skickar agenten vanlig text. Två vägar:

- **A) Agenten skickar blocks:** Om agenten har tillgång till Slack API (t.ex. `chat.postMessage` med `blocks`) kan vi uppdatera agentinstruktionerna så att den efter en draft skickar ett meddelande med en block som innehåller knapparna "Publicera" och "Kassera" med `value` = slug. Det kräver att OpenClaw/agenten kan skicka Block Kit.
- **B) Webhook lägger till knappar:** När agenten postat vanlig text kan en annan tjänst (eller samma webhook som lyssnar på nya meddelanden) läsa senaste meddelandet, parsa slug, och posta ett nytt meddelande med knappar. Mer komplext.

Praktiskt: börja med **A** om din OpenClaw-version kan skicka blocks; annars behåll text + "Kopiera och skriv: publicera slug" och lägg bara till en **separat** "Publicera"-knapp som anropar webhooken (t.ex. i ett verktyg eller kort som du själv postar efter draft).

---

## Sammanfattning

| Vad | Kräver |
|-----|--------|
| **Knapp "Publicera" (slug)** | Interactivity + webhook som kör `publish-draft.sh` (SSH/docker exec). Enklast att bygga först. |
| **Knapp "Skriv denna" / "Godkänn"** | Webhook som antingen postar text i kanalen/tråden (så agenten ser det) eller anropar OpenClaw API. |
| **Knappar i agentens meddelanden** | Att agenten skickar Block Kit (blocks) i stället för bara text, eller att en tjänst omformaterar meddelanden till blocks. |

**Färdig webhook för "Publicera"-knappen:** Se mappen **openclaw/slack-webhook/** – minimal Node.js-tjänst som tar emot klick, verifierar Slack-signatur, kör `publish-draft.sh` (via `PUBLISH_CMD` med `SLUG`), och uppdaterar Slack-meddelandet. Deploya på Coolify, sätt Request URL i Slack till `https://din-tjanst/slack-interaction`. Se **openclaw/slack-webhook/README.md**.
