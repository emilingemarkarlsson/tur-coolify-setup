# ✅ Verifiera Coolify & Hetzner-plattformen

## Snabb verifiering (1 kommando)

```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/verify-all.sh
```

Detta script kontrollerar allt:

- ✅ **Serveranslutning** - SSH och ping
- ✅ **Serveruppdateringar** - Antal tillgängliga uppdateringar
- ✅ **Docker Status** - Version och containers
- ✅ **Coolify Status** - Installation och containers
- ✅ **Externa Endpoints** - DNS och HTTPS för alla domäner
- ✅ **Systemhälsa** - Disk, minne, swap, zombie processes

---

## Vad scriptet visar

### 1. Serveruppdateringar
- Visar antal paket som kan uppdateras
- Om 0 = allt är uppdaterat ✅
- Om >0 = kör `./scripts/update-server.sh`

### 2. Coolify Status
- Kontrollerar att Coolify är installerat
- Visar alla Coolify-containers och deras status
- Verifierar att Coolify körs korrekt

### 3. Externa Endpoints
- Testar DNS-resolution
- Testar HTTPS-anslutning
- Visar status för alla domäner

### 4. Systemhälsa
- Disk usage (varning om >70%)
- Memory usage (varning om >90%)
- Swap usage (varning om >50%)
- Zombie processes

---

## Efter verifiering

### Om allt är grönt ✅
- Öppna Coolify dashboard: https://coolify.theunnamedroads.com
- Kontrollera att alla services körs i Coolify UI

### Om det finns varningar ⚠️
- **Uppdateringar tillgängliga:** Kör `./scripts/update-server.sh`
- **Coolify körs inte:** Se `docs/guides/EMERGENCY-RECOVERY.md`
- **Services inte tillgängliga:** Kör `./scripts/fix-services.sh`
- **Endpoints når inte:** Kontrollera DNS i Cloudflare

---

## Ytterligare kommandon

```bash
# Snabb serverstatus
./scripts/quick-ssh.sh

# Externa endpoints
./scripts/diagnose.sh

# SSH direkt
ssh tha
```

