# 🔄 Uopen-webui - Uppdateringsguide

## Nuvarande Konfiguration

- **Image:** `ghcr.io/open-webui/open-webui:main`
- **Directory:** `open-webui/`
- **Domain:** `openwebui-cckckggw44s8gkkkw008k4cs.46.62.206.47.sslip.io`}
- **Status:** Aktiv i Coolify
- **Senaste tillgänglig version:** `main` (kontrollera Docker Hub/Quay.io för bekräftelse)}

## Uppdatera Uopen-webui

### Metod 1: Via Coolify Dashboard (Rekommenderat)

1. **Öppna Coolify Dashboard**
   - Gå till: https://coolify.theunnamedroads.com
   - Logga in

2. **Välj Uopen-webui Service**
   - Klicka på Uopen-webui service

3. **Uppdatera Image**
   - Klicka på "Edit Compose"
   - Ändra image från `ghcr.io/open-webui/open-webui:main` till senaste version
     - Rekommenderat: `ghcr.io/open-webui/open-webui:main`
   - Klicka "Deploy"

### Metod 2: Via SSH (Manuellt)

```bash
# 1. SSH till servern
ssh tha

# 2. Hitta Uopen-webui service directory
ls -la /data/coolify/services/ | grep cckckggw44s8gkkkw008k4cs

# 3. Gå till Uopen-webui service
cd /data/coolify/services/cckckggw44s8gkkkw008k4cs

# 4. Redigera docker-compose.yml
nano docker-compose.yml

# 5. Uppdatera image-tag
# Ändra från: image: ghcr.io/open-webui/open-webui:main
# Till: image: ghcr.io/open-webui/open-webui:main

# 6. Uppdatera och starta om
docker compose pull
docker compose up -d

# 7. Verifiera
docker compose ps
docker logs <open-webui-container-name> --tail 20
```

## Hitta Senaste Version

**Docker Hub/Quay.io:**
- https://github.com/open-webui/open-webui/releases
- https://hub.docker.com/r/openwebui/open-webui/tags
