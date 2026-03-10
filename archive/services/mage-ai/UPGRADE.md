# 🔄 Mage AI - Uppdateringsguide

## Nuvarande Konfiguration

- **Image:** `mageai/mageai:latest`
- **Directory:** `mage-ai/`
- **Status:** Aktiv i Coolify

## Uppdatera Mage AI

### Metod 1: Via Coolify Dashboard (Rekommenderat)

1. **Öppna Coolify Dashboard**
   - Gå till: https://coolify.theunnamedroads.com
   - Logga in

2. **Välj Mage AI Service**
   - Klicka på Mage AI service

3. **Uppdatera Image**
   - Klicka på "Edit Compose"
   - Ändra image från `mageai/mageai:latest` till specifik version
   - Exempel: `mageai/mageai:0.9.80`
   - Klicka "Deploy"

### Metod 2: Via SSH (Manuellt)

```bash
# 1. SSH till servern
ssh tha

# 2. Hitta Mage AI service directory
ls -la /data/coolify/services/ | grep mage

# 3. Gå till Mage AI service
cd /data/coolify/services/<mage-service-id>

# 4. Redigera docker-compose.yml
nano docker-compose.yml

# 5. Uppdatera image-tag
# Ändra från: image: mageai/mageai:latest
# Till: image: mageai/mageai:0.9.80

# 6. Uppdatera och starta om
docker compose pull
docker compose up -d

# 7. Verifiera
docker compose ps
docker logs <mage-container-name> --tail 20
```

## Hitta Senaste Version

**Docker Hub:**
- https://hub.docker.com/r/mageai/mageai/tags

**GitHub Releases:**
- https://github.com/mage-ai/mage-ai/releases

**PyPI (för Python-paket):**
- https://pypi.org/project/mage-ai/

**Rekommendation:**
- Använd specifika versioner istället för `:latest`
- Format: `MAJOR.MINOR.PATCH` (t.ex. `0.9.80`)
- Undvik beta/alpha-versioner i produktion

## Breaking Changes

**Viktigt:** Kontrollera alltid release notes för breaking changes:
- https://github.com/mage-ai/mage-ai/releases

**Vanliga breaking changes:**
- Major version-uppgraderingar (t.ex. 0.8.x → 0.9.x)
- Pipeline-format-ändringar
- Block-API-ändringar
- Datasource-ändringar

## Verifiera Uppdatering

Efter uppdatering, kontrollera:

```bash
# Kontrollera container status
ssh tha 'docker ps | grep mage'

# Kontrollera logs
ssh tha 'docker logs <mage-container-name> --tail 50'

# Testa Mage AI dashboard (om konfigurerad)
curl -I https://<mage-domain>
```

## Backup innan Uppdatering

**Viktigt:** Säkerhetskopiera data innan större uppdateringar:

```bash
# Backup Mage AI data volume
ssh tha 'docker run --rm -v mage_data:/data -v $(pwd):/backup alpine tar czf /backup/mage-backup-$(date +%Y%m%d).tar.gz /data'
```

## Best Practices

1. **Använd specifika versioner** istället för `:latest`
2. **Testa i staging** först (om möjligt)
3. **Säkerhetskopiera data** innan större uppdateringar
4. **Läs release notes** för breaking changes
5. **Uppdatera regelbundet** för säkerhetsuppdateringar
6. **Exportera pipelines** innan större uppdateringar

## Troubleshooting

### Service startar inte efter uppdatering

```bash
# Kolla logs
ssh tha 'docker logs <mage-container-name>'

# Starta om service
ssh tha 'cd /data/coolify/services/<mage-service-id> && docker compose restart'
```

### Pipelines fungerar inte

```bash
# Kontrollera pipeline-format
# Mage AI kan automatiskt migrera pipelines, men kontrollera logs

# Exportera pipelines som backup
# Gå till Mage AI dashboard → Export
```

### Block-problem

```bash
# Kontrollera block-kompatibilitet
# Vissa blocks kan behöva uppdateras efter Mage AI-uppdatering
```

## Ytterligare Resurser

- **Mage AI Dokumentation:** https://docs.mage.ai/
- **Mage AI GitHub:** https://github.com/mage-ai/mage-ai
- **Coolify Dashboard:** https://coolify.theunnamedroads.com

