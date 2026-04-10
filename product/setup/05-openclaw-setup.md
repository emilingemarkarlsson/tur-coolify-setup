# Step 5 — OpenClaw Setup

Estimated time: 15 minutes

OpenClaw is a Python webhook server that handles the final step: turning a JSON payload from n8n into a committed markdown file in a GitHub repo — triggering a Netlify or Vercel deploy automatically.

---

## How it works

```
n8n workflow
    → POST /store-and-publish
        { slug, umamiName, content }
    → OpenClaw writes markdown file
    → git commit + push to GitHub repo
    → Netlify/Vercel auto-deploys
    → Telegram notification sent
```

One HTTP call. Article is live in ~60 seconds.

---

## Install on your VPS

SSH into your server:

```bash
# Create directory
mkdir -p /opt/openclaw
cd /opt/openclaw

# Install dependencies
apt install python3-pip git -y
pip3 install flask gitpython requests

# Clone or create the server
# (server.py is included in this pack — see openclaw/server.py)
cp /path/to/server.py /opt/openclaw/server.py
```

---

## Configure site-repos.json

This file tells OpenClaw where to publish for each site. See `templates/site-repos.json` for the template.

```json
{
  "theunnamedroads": {
    "contentPath": "src/content/posts",
    "githubRepo": "yourusername/your-tur-repo",
    "domain": "https://theunnamedroads.com",
    "umamiName": "theunnamedroads.com",
    "listUuid": "your-listmonk-list-uuid"
  }
}
```

Add one entry per site.

---

## GitHub authentication

Generate a Personal Access Token with `repo` scope at github.com/settings/tokens.

```bash
# Store as environment variable
export GITHUB_TOKEN=ghp_yourtoken
```

Or set it in your systemd service file (see below).

---

## Run as a service

Create `/etc/systemd/system/openclaw.service`:

```ini
[Unit]
Description=OpenClaw Webhook Server
After=network.target

[Service]
User=root
WorkingDirectory=/opt/openclaw
Environment=GITHUB_TOKEN=ghp_yourtoken
Environment=TELEGRAM_BOT_TOKEN=your-bot-token
Environment=TELEGRAM_CHAT_ID=your-chat-id
ExecStart=/usr/bin/python3 /opt/openclaw/server.py
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable openclaw
systemctl start openclaw
```

OpenClaw now runs on port `9191` and restarts automatically on reboot.

---

## Test it

```bash
curl -X POST http://localhost:9191/health
# → {"status": "ok"}

curl -X POST http://localhost:9191/store-and-publish \
  -H "Content-Type: application/json" \
  -d '{"slug": "test-article", "umamiName": "theunnamedroads.com", "content": "---\ntitle: Test\n---\nHello world"}'
```

---

## Connect from n8n

In your n8n article generator workflows, the final HTTP Request node calls:

```
POST http://YOUR_VPS_IP:9191/store-and-publish
Content-Type: application/json

{
  "slug": "{{ $json.slug }}",
  "umamiName": "theunnamedroads.com",
  "content": "{{ $json.articleContent }}"
}
```

---

## Setup complete

Your stack is now running. Next steps:
1. Import the 33 workflow JSONs into n8n
2. Update credentials in each workflow
3. Activate workflows one by one
4. Check the `workflows/README.md` for what each workflow does and what it needs
