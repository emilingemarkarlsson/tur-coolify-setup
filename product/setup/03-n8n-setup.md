# Step 3 — n8n Setup

Estimated time: 10 minutes

n8n is the workflow engine. It runs all 33 workflows in this pack — scheduling, API calls, content generation, publishing, and notifications.

---

## Deploy via Coolify

1. In Coolify, go to **Services** → **Add New Service**
2. Search for **n8n** and select it
3. Set environment variables:

```
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your-strong-password
N8N_HOST=n8n.yourdomain.com
N8N_PORT=5678
N8N_PROTOCOL=https
WEBHOOK_URL=https://n8n.yourdomain.com/
N8N_ENCRYPTION_KEY=generate-a-random-32-char-string
```

4. Set your domain (e.g. `n8n.yourdomain.com`)
5. Click **Deploy**

---

## Generate encryption key

```bash
openssl rand -hex 16
```

Save this key — you'll need it if you ever migrate n8n. If you lose it, your credentials are unrecoverable.

---

## Import the workflow templates

After n8n is running:

1. Open n8n at your domain
2. Go to **Workflows** → **Import from file**
3. Import each `.json` file from the `workflows/` folder in this pack

The workflows come with placeholder values — update credentials before activating. See `workflows/README.md` for what each workflow needs.

---

## Set up credentials

You'll need to add credentials for:

| Credential | Used by |
|-----------|---------|
| Telegram Bot Token | All notification workflows |
| GitHub Personal Access Token | All publisher workflows |
| Groq API Key | Content generation workflows |
| Gemini API Key | THB Daily workflow |
| Minio (S3) | SEO workflows |
| SMTP / Resend | Newsletter dispatch |

Go to **Credentials** → **Add Credential** for each.

---

## Key n8n gotchas (from hard experience)

- **Backtick template literals fail silently** in `{{ }}` expressions — use string concatenation instead
- **Parallel fan-out is unreliable** without an explicit Merge node — chain sequentially
- **`$credentials` doesn't work in HTTP request bodies** — hardcode credential values
- **Webhook nodes need `webhookId`** set explicitly for clean URLs
- After adding/changing webhooks: deactivate workflow → activate again to re-register

---

## Next step

Proceed to [04-litellm-setup.md](04-litellm-setup.md)
