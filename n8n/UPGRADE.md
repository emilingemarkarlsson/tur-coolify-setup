# 🔄 N8N - Uppdateringsguide

## Nuvarande Konfiguration

- **Image:** `n8nio/n8n:latest`
- **Directory:** `n8n/`
- **Domain:** `automation.thehockeyanalytics.com`
- **Status:** Aktiv i Coolify

## Uppdatera N8N

### Metod 1: Via Coolify Dashboard (Rekommenderat)

1. **Öppna Coolify Dashboard**
   - Gå till: https://coolify.theunnamedroads.com
   - Logga in

2. **Välj N8N Service**
   - Klicka på N8N service

3. **Uppdatera Image**
   - Klicka på "Edit Compose"
   - Ändra image från `n8nio/n8n:latest` till specifik version
   - Exempel: `n8nio/n8n:1.65.0`
   - Klicka "Deploy"

### Metod 2: Via SSH (Manuellt)

```bash
# 1. SSH till servern
ssh tha

# 2. Hitta N8N service directory
ls -la /data/coolify/services/ | grep n8n

# 3. Gå till N8N service
cd /data/coolify/services/<n8n-service-id>

# 4. Redigera docker-compose.yml
nano docker-compose.yml

# 5. Uppdatera image-tag
# Ändra från: image: n8nio/n8n:latest
# Till: image: n8nio/n8n:1.65.0

# 6. Uppdatera och starta om
docker compose pull
docker compose up -d

# 7. Verifiera
docker compose ps
docker logs <n8n-container-name> --tail 20
```

## Hitta Senaste Version

**Docker Hub:**
- https://hub.docker.com/r/n8nio/n8n/tags

**GitHub Releases:**
- https://github.com/n8n-io/n8n/releases

**Rekommendation:**
- Använd specifika versioner istället för `:latest`
- Format: `MAJOR.MINOR.PATCH` (t.ex. `1.65.0`)
- Undvik beta/alpha-versioner i produktion

## Breaking Changes

**Viktigt:** Kontrollera alltid release notes för breaking changes:
- https://github.com/n8n-io/n8n/releases

**Vanliga breaking changes:**
- Major version-uppgraderingar (t.ex. 1.x → 2.x)
- Workflow-format-ändringar
- Node-API-ändringar
- Credential-format-ändringar

## Verifiera Uppdatering

Efter uppdatering, kontrollera:

```bash
# Kontrollera container status
ssh tha 'docker ps | grep n8n'

# Kontrollera logs
ssh tha 'docker logs <n8n-container-name> --tail 50'

# Testa N8N dashboard
curl -I https://automation.thehockeyanalytics.com
```

## Backup innan Uppdatering

**Viktigt:** Säkerhetskopiera data innan större uppdateringar:

```bash
# Backup N8N data volume
ssh tha 'docker run --rm -v n8n_data:/data -v $(pwd):/backup alpine tar czf /backup/n8n-backup-$(date +%Y%m%d).tar.gz /data'
```

## Best Practices

1. **Använd specifika versioner** istället för `:latest`
2. **Testa i staging** först (om möjligt)
3. **Säkerhetskopiera data** innan större uppdateringar
4. **Läs release notes** för breaking changes
5. **Uppdatera regelbundet** för säkerhetsuppdateringar
6. **Exportera workflows** innan större uppdateringar

## Troubleshooting

### Service startar inte efter uppdatering

```bash
# Kolla logs
ssh tha 'docker logs <n8n-container-name>'

# Starta om service
ssh tha 'cd /data/coolify/services/<n8n-service-id> && docker compose restart'
```

### Workflows fungerar inte

```bash
# Kontrollera workflow-format
# N8N kan automatiskt migrera workflows, men kontrollera logs

# Exportera workflows som backup
# Gå till N8N dashboard → Settings → Export
```

### Credential-problem

```bash
# Kontrollera credential-format
# N8N kan automatiskt migrera credentials, men kontrollera logs
```

## Ytterligare Resurser

- **N8N Dokumentation:** https://docs.n8n.io/
- **N8N GitHub:** https://github.com/n8n-io/n8n
- **Coolify Dashboard:** https://coolify.theunnamedroads.com


