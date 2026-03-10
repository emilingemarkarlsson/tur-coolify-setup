# Slack "Publicera"-knapp – koppla webhook

Artikel-förslag skickas till Slack. För att kunna **trycka Publicera** i Slack och då trigga skrivning + publicering på sajten behöver du en **Request URL** som tar emot Slack Interactivity-payloads.

---

## Krav

1. **Slack-appen** (samma som OpenClaw använder) måste ha **Interactivity** aktiverat.
2. En **HTTPS-URL** (Request URL) som Slack kan POSTa till när någon klickar på en knapp.
3. En **liten tjänst** (webhook) som:
   - Tar emot POST från Slack (payload med `type: block_actions`, `actions[].value` = `umamiName|keyword`).
   - Anropar OpenClaw (t.ex. Gateway API) med ett jobb: "Publicera artikel: sajt=X, keyword=Y".
   - Svarar till Slack med `200 OK` (obligatoriskt inom ~3 s).

OpenClaw använder Socket Mode och exponerar normalt inte en publik URL för Interactivity – därför behöver du antingen:

- **A)** En egen liten tjänst (t.ex. på Coolify) som har en publik HTTPS-URL och som vid klick anropar OpenClaw Gateway (session create / cron run med rätt meddelande), eller  
- **B)** Kolla om OpenClaw Gateway har stöd för Interactivity Request URL i konfigurationen – i så fall peka Slacks Request URL dit.

---

## Steg 1: Aktivera Interactivity i Slack

1. Gå till [api.slack.com/apps](https://api.slack.com/apps) → välj din OpenClaw-app.
2. **Interactivity & Shortcuts** → sätt **Interactivity** till **On**.
3. **Request URL:** lämna tom tills webhook-tjänsten är uppe, eller ange din webhook-URL (måste vara HTTPS).

---

## Steg 2: Webhook-tjänst (egen tjänst)

Du behöver en endpoint som:

1. **Tar emot POST** med Content-Type `application/x-www-form-urlencoded`; body innehåller `payload` (JSON-sträng).
2. **Parsar** `payload` → JSON. Hämta `actions[0].value` (format: `umamiName|keyword`, t.ex. `theunnamedroads|packlista vandring`).
3. **Anropar OpenClaw** – t.ex.:
   - OpenClaw Gateway API: skapa session eller trigga agent med meddelande:  
     *"Du är SEO-agenten. Publicera artikel: sajt=theunnamedroads, keyword=packlista vandring. Läs /data/.openclaw/agents/SEO-SITE-AGENT.md. Kör Fas 3 (content brief) och skicka till Slack för godkännande. Efter godkännande: kör Fas 4 (skrivning), skicka draft till Slack, efter godkännande pusha till rätt repo enligt site-repos.json."*
   - Hur du anropar beror på din OpenClaw-version (REST API för session/cron – se OpenClaw-dokumentation).
4. **Svarar** till Slack med `200 OK` och body antingen tom eller `{"ok": true}`. Du kan också uppdatera meddelandet med `response_url` från payload (t.ex. "Publiceras …").

### Exempel på payload från Slack (utdrag)

```json
{
  "type": "block_actions",
  "user": { "id": "U..." },
  "channel": { "id": "C07TJRLTM9C" },
  "actions": [
    {
      "action_id": "publish_article",
      "value": "theunnamedroads|packlista vandring"
    }
  ],
  "response_url": "https://hooks.slack.com/actions/..."
}
```

Värden i `value` ska delas upp på `|`: första delen = umamiName, resten = keyword.

---

## Steg 3: Knappar i meddelanden (Block Kit)

När agenten postar artikel-förslag kan den (om den har tillgång till Slack API med Block Kit) skicka blocks som innehåller en knapp:

```json
{
  "type": "actions",
  "elements": [
    {
      "type": "button",
      "text": { "type": "plain_text", "text": "Publicera" },
      "action_id": "publish_article",
      "value": "theunnamedroads|packlista vandring"
    }
  ]
}
```

Idag postar agenten vanlig text. För att få knappar krävs antingen att agenten använder Slack API (`chat.postMessage` med `blocks`) i stället för enkel text, eller att en separat tjänst läser förslag (t.ex. från en kö eller från senaste meddelanden) och postar ett nytt meddelande med knappar. Enklaste vägen kort sikt: användaren skriver i Slack *"@agent producera artikel för theunnamedroads om packlista vandring"* – då behövs ingen webhook för knappen.

---

## Sammanfattning

| Komponent        | Status |
|------------------|--------|
| Artikel-förslag  | Agenten skickar förslag till Slack enligt SEO-ARTICLE-SUGGESTIONS.md (cron eller på begäran). |
| Publicera (text) | Skriv i Slack: *"producera artikel för [sajt] om [keyword]"* – agenten kör Fas 3+4. |
| Publicera (knapp)| Kräver: Interactivity Request URL + webhook-tjänst som anropar OpenClaw; ev. Block Kit i meddelanden. |

Om du vill bygga webhook-tjänsten kan du använda t.ex. en minimal Express (Node) eller Flask (Python) app på Coolify med en HTTPS-URL, och i den anropa OpenClaw Gateway API enligt deras dokumentation.
