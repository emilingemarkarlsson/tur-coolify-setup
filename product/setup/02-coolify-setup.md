# Step 2 — Coolify Setup

Estimated time: 15 minutes

Coolify is the self-hosted PaaS that manages all your containers. It replaces Heroku, Railway, Render — but runs on your own VPS.

---

## Install Coolify

SSH into your server and run:

```bash
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

Wait ~2 minutes. When done, Coolify is running at `http://YOUR_SERVER_IP:8000`.

---

## Initial configuration

1. Open `http://YOUR_SERVER_IP:8000` in your browser
2. Create your admin account
3. Add your server:
   - Go to **Servers** → **Add Server**
   - Select **Localhost** (your own VPS)
   - Click **Validate & Save**

---

## Set up a domain (optional but recommended)

Point a domain or subdomain at your server IP (A record), then configure it in Coolify under **Settings → Instance Domain**.

Coolify handles SSL certificates automatically via Let's Encrypt.

---

## Services to deploy via Coolify

Once set up, you'll deploy these services one by one (covered in the following guides):

| Service | Purpose |
|---------|---------|
| n8n | Workflow automation |
| LiteLLM | LLM proxy |
| Minio | Object storage |
| Umami | Analytics |
| Listmonk | Newsletter |
| PostgreSQL | Database for n8n + Umami |
| Redis | Cache for n8n |

Each is deployed from **Services** → **Add New Service** → search by name.

---

## Tips

- Keep Coolify UI behind a strong password — it controls your entire stack
- Enable automatic backups under **Settings → Backups**
- The Coolify API is at `http://localhost:8000/api/v1` (use from the server itself)

---

## Next step

Proceed to [03-n8n-setup.md](03-n8n-setup.md)
