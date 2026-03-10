# OpenClaw Slack: "channel not allowed"

När loggen visar:
```text
slack: drop channel C07TJRLTM9C (groupPolicy=allowlist, matchKey=none matchSource=none)
slack: drop message (channel not allowed)
```
betyder det att kanalen inte finns i allowlist. Standard är `groupPolicy=allowlist`.

## Lösning 1: Tillåt alla kanaler (groupPolicy=open)

Redigera `/data/.openclaw/openclaw.json` **inuti openclaw-containern** så att `channels.slack` har `groupPolicy: "open"`.

Exempel (om filen är minimal eller du lägger till för första gången):

```json
{
  "channels": {
    "slack": {
      "groupPolicy": "open"
    }
  }
}
```

Om det redan finns `channels` med annat innehåll, lägg bara till (eller uppdatera) `slack`-delen:

```json
"slack": {
  "groupPolicy": "open"
}
```

## Lösning 2: Lägg bara in en kanal (allowlist)

I stället för `groupPolicy: "open"` kan du lägga kanalen i allowlist:

```json
"channels": {
  "slack": {
    "groupPolicy": "allowlist",
    "channels": {
      "C07TJRLTM9C": {}
    }
  }
}
```

`C07TJRLTM9C` är kanal-ID för #all-tur-ab. För fler kanaler, lägg till fler nycklar under `channels.slack.channels`.

## Så redigerar du filen

1. **Backa upp (på servern):**
   ```bash
   docker exec <OPENCLAW_CONTAINER_NAME> cp /data/.openclaw/openclaw.json /data/.openclaw/openclaw.json.bak
   ```

2. **Kopiera ut filen till din dator (från servern):**
   ```bash
   docker cp <OPENCLAW_CONTAINER_NAME>:/data/.openclaw/openclaw.json ./openclaw.json
   ```

3. Redigera `openclaw.json` lokalt (lägg till/uppdatera `channels.slack` enligt ovan).

4. **Sätt tillbaka:**
   ```bash
   docker cp ./openclaw.json <OPENCLAW_CONTAINER_NAME>:/data/.openclaw/openclaw.json
   ```

5. **Starta om OpenClaw** (Coolify → openclaw-tur → Restart).

Containernamn: `docker ps | grep openclaw` (ofta något i stil med `openclaw-...` eller namnet Coolify ger).

---

## Snabb fix: kör script på servern

Ett script i repot sätter `groupPolicy: "open"` åt dig. **Kör det på servern** (SSH till Hetzner):

```bash
# På servern (efter clone eller om repot redan finns där)
cd /path/to/tur-coolify-setup   # eller: git clone ... && cd tur-coolify-setup
chmod +x scripts/openclaw-slack-allow-channels.sh
./scripts/openclaw-slack-allow-channels.sh
```

Om repot inte finns på servern, kopiera bara scriptet och kör det:

```bash
scp scripts/openclaw-slack-allow-channels.sh user@46.62.206.47:/tmp/
ssh user@46.62.206.47 'bash /tmp/openclaw-slack-allow-channels.sh'
```

Efter det: **Restart** OpenClaw i Coolify.
