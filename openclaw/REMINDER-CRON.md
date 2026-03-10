# Schemalagd påminnelse – ny artikel (inga AI-krediter)

En enkel **påminnelse** som postar till Slack (t.ex. varje dag eller varannan dag) så du inte glömmer att hålla igång artikelplanen. Scriptet använder bara **Slack Incoming Webhook** – ingen OpenClaw, inga AI-krediter.

---

## 1. Skapa Incoming Webhook i Slack

1. Gå till [api.slack.com/apps](https://api.slack.com/apps) → välj din workspace → **Create New App** → **From scratch** (eller använd befintlig app).
2. **Incoming Webhooks** → **On** → **Add New Webhook to Workspace** → välj kanal **#all-tur-ab** (eller den kanal där du vill få påminnelsen).
3. Kopiera **Webhook URL** (ser ut ungefär som `https://hooks.slack.com/services/T.../B.../...`).

---

## 2. Kör scriptet (test)

Sätt URL:en och kör en gång:

```bash
cd ~/Documents/dev/tur-coolify-setup
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T.../B.../..."
chmod +x scripts/slack-seo-reminder.sh
./scripts/slack-seo-reminder.sh
```

Du ska få ett meddelande i #all-tur-ab med påminnelsen och nästa steg.

---

## 3. Schemalägg (cron)

### Rekommenderat: kör på servern (tha)

Då går påminnelsen ut **varje dag kl 09:00 även när din Mac är av** – du får den i Slack på mobilen.

**Steg A – kopiera script till servern**

```bash
cd ~/Documents/dev/tur-coolify-setup
scp scripts/slack-seo-reminder.sh tha:/usr/local/bin/  # eller tha:~/
ssh tha 'chmod +x /usr/local/bin/slack-seo-reminder.sh'
```

**Steg B – sätt webhook-URL på servern (en gång)**

Skapa en fil med bara URL:en (byt ut mot din egen webhook):

```bash
ssh tha "echo 'https://hooks.slack.com/services/DIN/WEBHOOK/URL' > ~/.slack-seo-reminder-url && chmod 600 ~/.slack-seo-reminder-url"
```
(Ersätt `DIN/WEBHOOK/URL` med din faktiska Incoming Webhook-URL från Slack.)

Om du kör cron som root på servern, använd istället:  
`ssh tha "echo 'https://...' | sudo tee /etc/slack-seo-reminder-url && sudo chmod 600 /etc/slack-seo-reminder-url"`

**Steg C – lägg in cron på servern**

```bash
ssh tha ' (crontab -l 2>/dev/null | grep -v slack-seo-reminder; echo "0 9 * * * /usr/local/bin/slack-seo-reminder.sh") | crontab - '
```

(Om du lade scriptet i din hemkatalog på tha, använd t.ex. `$HOME/slack-seo-reminder.sh` i stället för `/usr/local/bin/slack-seo-reminder.sh`.)

**Testa från servern:**  
`ssh tha '/usr/local/bin/slack-seo-reminder.sh'` – då ska ett meddelande dyka upp i #all-tur-ab.

---

### Alternativ: kör på din Mac

Påminnelsen körs bara när datorn är på och inte i sömn:

```bash
crontab -e
```

Lägg till:  
`0 9 * * * export SLACK_WEBHOOK_URL='https://hooks.slack.com/services/...' /Users/emilkarlsson/Documents/dev/tur-coolify-setup/scripts/slack-seo-reminder.sh`

---

## Innehåll i påminnelsen

Scriptet skickar ungefär:

> 📝 **Påminnelse – ny artikel på emilingemarkarlsson.com**  
>  
> Idag är en bra dag att posta en ny artikel för att nå våra SEO-mål.  
>  
> **Nästa steg:** Skriv i denna kanal: `@tur-openclaw artikel-förslag för emilingemarkarlsson` – sedan välj ett förslag (t.ex. skriv `2`) och följ flödet.

Du kan redigera **scripts/slack-seo-reminder.sh** och ändra texten eller sajten om du vill.
