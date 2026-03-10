# OpenClaw + Slack (Socket Mode)

OpenClaw använder **Socket Mode** som standard – då behöver du ingen publik webhook-URL, bara två tokens.

---

## Steg 1: Skapa en Slack-app

1. Gå till **https://api.slack.com/apps** och logga in.
2. Klicka **Create New App** → **From scratch**.
3. **App Name:** t.ex. `OpenClaw` eller `The Unnamed Roads – OpenClaw`.
4. **Workspace:** Välj din The Unnamed Roads–workspace.
5. Klicka **Create App**.

---

## Steg 2: Aktivera Socket Mode och skapa App Token

1. I vänstermenyn: **Settings** → **Socket Mode**.
2. Sätt **Enable Socket Mode** till **On**.
3. Klicka **Generate** under **App-Level Tokens**.
4. **Token Name:** t.ex. `openclaw-socket`.
5. **Scope:** kryssa i **connections:write**.
6. Klicka **Generate**.
7. **Kopiera tokenet** (börjar med `xapp-...`) – du får bara se det en gång. Det är din **SLACK_APP_TOKEN**.

---

## Steg 3: Bot-scopes (OAuth & Permissions)

1. I vänstermenyn: **OAuth & Permissions**.
2. Under **Scopes** → **Bot Token Scopes**, klicka **Add an OAuth Scope** och lägg till:
   - `app_mentions:read`
   - `channels:history`
   - `channels:read`
   - `chat:write`
   - `files:read`
   - `groups:history`
   - `im:history`
   - `im:read`
   - `im:write`
   - `users:read`
   - `assistant:write` (för typing/streaming)
   - `reactions:read`
   - `reactions:write`
   - `pins:read`
   - `pins:write`
   - `emoji:read`
   - `files:write`
   - `commands` (om du vill använda slash-kommandon)
3. Spara.

---

## Steg 4: Prenumerera på bot-events (Event Subscriptions)

1. I vänstermenyn: **Event Subscriptions**.
2. Sätt **Enable Events** till **On**.
3. Under **Subscribe to bot events**, lägg till:
   - `app_mention`
   - `message.channels`
   - `message.groups`
   - `message.im`
   - `message.mpim`
   - `reaction_added`
   - `reaction_removed`
   - `member_joined_channel`
   - `member_left_channel`
   - `channel_rename`
   - `pin_added`
   - `pin_removed`
4. Spara.

**App Home:** Under **App Home** → aktivera **Messages Tab** (så att boten kan användas i DM).

---

## Steg 5: Installera appen i workspace

1. I vänstermenyn: **Install App** (eller **OAuth & Permissions** → **Install to Workspace**).
2. Klicka **Install to Workspace** och godkänn behörigheterna.
3. **Kopiera Bot User OAuth Token** (börjar med `xoxb-...`). Det är din **SLACK_BOT_TOKEN**.

---

## Steg 6: Lägg tokens i Coolify

1. Gå till **Coolify** → **openclaw-tur** (eller din OpenClaw-resurs) → **Configuration** → **Environment Variables**.
2. Lägg till (eller uppdatera):
   - **SLACK_BOT_TOKEN** = `xoxb-...` (Bot User OAuth Token från steg 5)
   - **SLACK_APP_TOKEN** = `xapp-...` (App-Level Token från steg 2)
3. Spara.
4. **Restart** (eller Redeploy) OpenClaw.

---

## Steg 7: Använda OpenClaw i Slack

- **DM:** Öppna en direktmeddelande med OpenClaw-boten (hitta den under Apps eller via **Message** på botens profil). Första gången kan du behöva godkänna “pairing” (se OpenClaw-dokumentation om `openclaw pairing approve slack` om du kör gateway separat).
- **Kanal:** Invitera boten till en kanal (`/invite @OpenClaw`), sedan @-nämn boten i ett meddelande så svarar den.

---

## Felsökning

- **Ingen respons:** Kontrollera att båda tokens är rätt (inga mellanslag), att Socket Mode är på och att event subscriptions är sparade. Kolla OpenClaw-loggar i Coolify.
- **DM fungerar inte:** DMs använder ofta “pairing” – se [OpenClaw Pairing](https://docs.openclaw.ai/channels/pairing).
- **Kanal:** Boten måste vara inbjuden i kanalen och du måste @-nämna den (eller svara i en tråd där boten är med).

---

**Källor:** [OpenClaw – Slack](https://docs.openclaw.ai/channels/slack), [OpenClaw Slack Integration](https://www.getopenclaw.ai/integrations/slack).
