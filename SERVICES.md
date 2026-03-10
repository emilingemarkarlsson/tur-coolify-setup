# 📦 Coolify Services - Översikt & Uppdateringar

## Lista alla resurser (1 kommando)

```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/list-coolify-resources.sh
```

Detta visar:
- ✅ Alla Coolify-services
- ✅ Docker containers och deras status
- ✅ Docker images och versioner
- ✅ Uppdateringsrekommendationer

---

## Aktiva Services

### 1. Langflow
- **Directory:** `langflow/`
- **Domain:** `langflow.theunnamedroads.com`
- **Image:** `langflowai/langflow:latest`
- **Uppdateringsguide:** [langflow/UPGRADE.md](langflow/UPGRADE.md)
- **Status:** Kontrollera med scriptet ovan

---

### 1. Uopen webui
- **Directory:** `open-webui/`
- **Domain:** `openwebui-cckckggw44s8gkkkw008k4cs.46.62.206.47.sslip.io`
- **Image:** `ghcr.io/open-webui/open-webui:main`
- **Uppdateringsguide:** [open-webui/UPGRADE.md](open-webui/UPGRADE.md)
- **Status:** Kontrollera med scriptet ovan

### 2. Uminio
- **Directory:** `minio/`
- **Domain:** `console-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io`
- **Image:** `ghcr.io/coollabsio/minio:RELEASE.2025-10-15T17-29-55Z`
- **Uppdateringsguide:** [minio/UPGRADE.md](minio/UPGRADE.md)
- **Status:** Kontrollera med scriptet ovan

### 3. Uminio p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io
- **Directory:** `minio-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io/`

- **Image:** ``
- **Uppdateringsguide:** [minio-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io/UPGRADE.md](minio-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io/UPGRADE.md)
- **Status:** Kontrollera med scriptet ovan

### 4. Uconsole p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io
- **Directory:** `console-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io/`

- **Image:** ``
- **Uppdateringsguide:** [console-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io/UPGRADE.md](console-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io/UPGRADE.md)
- **Status:** Kontrollera med scriptet ovan

### 5. Uminio p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io
- **Directory:** `minio-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io/`

- **Image:** ``
- **Uppdateringsguide:** [minio-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io/UPGRADE.md](minio-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io/UPGRADE.md)
- **Status:** Kontrollera med scriptet ovan

### 6. Un8n
- **Directory:** `n8n/`
- **Domain:** `n8n.theunnamedroads.com`
- **Image:** `docker.n8n.io/n8nio/n8n`
- **Uppdateringsguide:** [n8n/UPGRADE.md](n8n/UPGRADE.md)
- **Status:** Kontrollera med scriptet ovan

### 7. Un8n.theunnamedroads.com
- **Directory:** `n8n.theunnamedroads.com/`

- **Image:** ``
- **Uppdateringsguide:** [n8n.theunnamedroads.com/UPGRADE.md](n8n.theunnamedroads.com/UPGRADE.md)
- **Status:** Kontrollera med scriptet ovan

### 8. Un8n j88kgkks44cc8wcc4kc8wkkk.46.62.206.47.sslip.io
- **Directory:** `n8n-j88kgkks44cc8wcc4kc8wkkk.46.62.206.47.sslip.io/`

- **Image:** ``
- **Uppdateringsguide:** [n8n-j88kgkks44cc8wcc4kc8wkkk.46.62.206.47.sslip.io/UPGRADE.md](n8n-j88kgkks44cc8wcc4kc8wkkk.46.62.206.47.sslip.io/UPGRADE.md)
- **Status:** Kontrollera med scriptet ovan


---

## Inaktiva Services (Arkiverade)

Följande services är inaktiva och finns i `archive/services/`:

- **Grafana** - Visualization and analytics dashboard
- **Mage AI** - Data pipeline orchestration
- **Crawlab** - Web scraping framework
- **Appsmith** - Low-code application platform
- **ClickHouse** - Data warehouse (decommissioned pga disk space)

---

## Uppdatera Services

### Metod 1: Via Coolify Dashboard (Rekommenderat)

1. **Öppna Coolify Dashboard**
   - Gå till: https://coolify.theunnamedroads.com
   - Logga in

2. **Välj Service**
   - Klicka på service du vill uppdatera

3. **Uppdatera Image**
   - Klicka på "Edit Compose"
   - Ändra image-tag (t.ex. från `:latest` till specifik version)
   - Klicka "Deploy"

### Metod 2: Via SSH (Manuellt)

```bash
# 1. SSH till servern
ssh tha

# 2. Lista services
ls -la /data/coolify/services/

# 3. Gå till specifik service
cd /data/coolify/services/<service-id>

# 4. Redigera docker-compose.yml
nano docker-compose.yml

# 5. Uppdatera image-tag (t.ex. ändra från :latest till v10.2.0)
# Spara: Ctrl+O, Enter, Ctrl+X

# 6. Uppdatera och starta om
docker compose pull
docker compose up -d

# 7. Verifiera
docker compose ps
```

---

## Kontrollera Uppdateringar

### Kolla senaste versioner

För varje service, se individuella uppdateringsguider:

- **Uopen-webui:** [open-webui/UPGRADE.md](open-webui/UPGRADE.md)
- **Uminio:** [minio/UPGRADE.md](minio/UPGRADE.md)
- **Uminio-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io:** [minio-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io/UPGRADE.md](minio-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io/UPGRADE.md)
- **Uconsole-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io:** [console-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io/UPGRADE.md](console-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io/UPGRADE.md)
- **Uminio-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io:** [minio-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io/UPGRADE.md](minio-p8o8w08osogk4kkok4so884c.46.62.206.47.sslip.io/UPGRADE.md)
- **Un8n:** [n8n/UPGRADE.md](n8n/UPGRADE.md)
- **Un8n.theunnamedroads.com:** [n8n.theunnamedroads.com/UPGRADE.md](n8n.theunnamedroads.com/UPGRADE.md)
- **Un8n-j88kgkks44cc8wcc4kc8wkkk.46.62.206.47.sslip.io:** [n8n-j88kgkks44cc8wcc4kc8wkkk.46.62.206.47.sslip.io/UPGRADE.md](n8n-j88kgkks44cc8wcc4kc8wkkk.46.62.206.47.sslip.io/UPGRADE.md)

---

## Verifiera att Services Körs

### Snabb verifiering

```bash
# Lista alla resurser
./scripts/list-coolify-resources.sh

# Komplett verifiering
./scripts/verify-all.sh
```

### Manuell kontroll

```bash
# SSH till servern
ssh tha

# Lista alla containers
docker ps

# Kolla specifik service
docker ps | grep <service-name>

# Kolla logs
docker logs <container-name> --tail 50
```

---

## Troubleshooting

### Service körs inte

1. **Kontrollera container status:**
   ```bash
   ssh tha 'docker ps -a | grep <service-name>'
   ```

2. **Kolla logs:**
   ```bash
   ssh tha 'docker logs <container-name>'
   ```

3. **Starta om service:**
   ```bash
   ssh tha 'cd /data/coolify/services/<service-id> && docker compose restart'
   ```

### Service behöver uppdateras

1. **Kontrollera nuvarande version:**
   ```bash
   ssh tha 'docker images | grep <image-name>'
   ```

2. **Uppdatera via Coolify UI** (rekommenderat)
   - Eller följ "Metod 2" ovan

---

## Best Practices

1. **Använd specifika versioner** istället för `:latest`
2. **Testa uppdateringar** i staging först (om möjligt)
3. **Säkerhetskopiera data** innan större uppdateringar
4. **Uppdatera regelbundet** för säkerhetsuppdateringar
5. **Dokumentera ändringar** i service README-filer

---

## Ytterligare Resurser

- **Coolify Dashboard:** https://coolify.theunnamedroads.com
- **Verifiera allt:** `./scripts/verify-all.sh`
- **Lista resurser:** `./scripts/list-coolify-resources.sh`
- **Automatisk uppgradering:** `./scripts/auto-upgrade-all.sh`

