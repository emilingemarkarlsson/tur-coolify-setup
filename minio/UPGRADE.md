# 🔄 MinIO - Uppdateringsguide

## Nuvarande Konfiguration

- **Image:** `quay.io/minio/minio:latest`
- **Directory:** `minio/`
- **Status:** Aktiv i Coolify

## Uppdatera MinIO

### Metod 1: Via Coolify Dashboard (Rekommenderat)

1. **Öppna Coolify Dashboard**
   - Gå till: https://coolify.theunnamedroads.com
   - Logga in

2. **Välj MinIO Service**
   - Klicka på MinIO service

3. **Uppdatera Image**
   - Klicka på "Edit Compose"
   - Ändra image från `quay.io/minio/minio:latest` till specifik version
   - Exempel: `quay.io/minio/minio:RELEASE.2024-12-20T00-00-00Z`
   - Klicka "Deploy"

### Metod 2: Via SSH (Manuellt)

```bash
# 1. SSH till servern
ssh tha

# 2. Hitta MinIO service directory
ls -la /data/coolify/services/ | grep minio

# 3. Gå till MinIO service
cd /data/coolify/services/<minio-service-id>

# 4. Redigera docker-compose.yml
nano docker-compose.yml

# 5. Uppdatera image-tag
# Ändra från: image: quay.io/minio/minio:latest
# Till: image: quay.io/minio/minio:RELEASE.2024-12-20T00-00-00Z

# 6. Uppdatera och starta om
docker compose pull
docker compose up -d

# 7. Verifiera
docker compose ps
docker logs <minio-container-name> --tail 20
```

## Hitta Senaste Version

**Quay.io:**
- https://quay.io/repository/minio/minio?tab=tags

**Docker Hub (alternativ):**
- https://hub.docker.com/r/minio/minio/tags

**GitHub Releases:**
- https://github.com/minio/minio/releases

**Rekommendation:**
- Använd specifika RELEASE-taggar istället för `:latest`
- Format: `RELEASE.YYYY-MM-DDTHH-MM-SSZ`
- Exempel: `RELEASE.2024-12-20T00-00-00Z`

## Breaking Changes

**Viktigt:** Kontrollera alltid release notes för breaking changes:
- https://github.com/minio/minio/releases

**Vanliga breaking changes:**
- API-ändringar
- Konfigurationsändringar
- Milestone-uppgraderingar (t.ex. RELEASE.2024 → RELEASE.2025)

## Verifiera Uppdatering

Efter uppdatering, kontrollera:

```bash
# Kontrollera container status
ssh tha 'docker ps | grep minio'

# Kontrollera logs
ssh tha 'docker logs <minio-container-name> --tail 50'

# Testa MinIO API (om konfigurerad)
curl -I https://<minio-domain>
```

## Backup innan Uppdatering

**Viktigt:** Säkerhetskopiera data innan större uppdateringar:

```bash
# Backup MinIO data volume
ssh tha 'docker run --rm -v minio_data:/data -v $(pwd):/backup alpine tar czf /backup/minio-backup-$(date +%Y%m%d).tar.gz /data'
```

## Best Practices

1. **Använd specifika versioner** istället för `:latest`
2. **Testa i staging** först (om möjligt)
3. **Säkerhetskopiera data** innan större uppdateringar
4. **Läs release notes** för breaking changes
5. **Uppdatera regelbundet** för säkerhetsuppdateringar

## Troubleshooting

### Service startar inte efter uppdatering

```bash
# Kolla logs
ssh tha 'docker logs <minio-container-name>'

# Starta om service
ssh tha 'cd /data/coolify/services/<minio-service-id> && docker compose restart'
```

### Data går förlorad

```bash
# Återställ från backup
ssh tha 'docker run --rm -v minio_data:/data -v $(pwd):/backup alpine tar xzf /backup/minio-backup-YYYYMMDD.tar.gz -C /'
```

## Ytterligare Resurser

- **MinIO Dokumentation:** https://min.io/docs/
- **MinIO GitHub:** https://github.com/minio/minio
- **Coolify Dashboard:** https://coolify.theunnamedroads.com

