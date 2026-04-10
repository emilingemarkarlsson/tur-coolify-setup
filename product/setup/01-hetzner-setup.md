# Step 1 — Hetzner VPS Setup

Estimated time: 5 minutes

---

## Create the server

1. Sign up at [hetzner.cloud/?ref=ECLED3WXrvIQ](https://hetzner.cloud/?ref=ECLED3WXrvIQ) (you get €20 in credits)
2. Create a new project (e.g. "ai-stack")
3. Click **Add Server**
4. Select:
   - **Location:** Nuremberg or Frankfurt (lowest latency for EU)
   - **Image:** Ubuntu 22.04
   - **Type:** CX32 (4 vCPU, 8GB RAM) — €13.10/month
   - **SSH Key:** add your public key (recommended) or use password
5. Click **Create & Buy Now**

Your server will be ready in ~30 seconds.

---

## Connect to the server

```bash
ssh root@YOUR_SERVER_IP
```

---

## Initial setup

Run these commands after connecting:

```bash
# Update packages
apt update && apt upgrade -y

# Install Docker (required for Coolify)
curl -fsSL https://get.docker.com | sh

# Optional: create a non-root user
adduser emil
usermod -aG sudo,docker emil
```

---

## Firewall (optional but recommended)

```bash
ufw allow ssh
ufw allow 80
ufw allow 443
ufw allow 8000  # Coolify UI
ufw enable
```

---

## Next step

Proceed to [02-coolify-setup.md](02-coolify-setup.md)
