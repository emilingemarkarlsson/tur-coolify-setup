# 🔄 Grafana - Uppdateringsguide

## Nuvarande Konfiguration

- **Image:** `grafana/grafana:latest`
- **Directory:** `grafana/`
- **Domain:** `analytics.thehockeyanalytics.com`
- **Status:** Aktiv i Coolify

## Uppdatera Grafana

### Metod 1: Via Coolify Dashboard (Rekommenderat)

1. **Öppna Coolify Dashboard**
   - Gå till: https://coolify.theunnamedroads.com
   - Logga in

2. **Välj Grafana Service**
   - Klicka på Grafana service

3. **Uppdatera Image**
   - Klicka på "Edit Compose"
   - Ändra image från `grafana/grafana:latest` till specifik version
   - Exempel: `grafana/grafana:10.2.0`
   - Klicka "Deploy"

### Metod 2: Via SSH (Manuellt)

```bash
# 1. SSH till servern
ssh tha

# 2. Hitta Grafana service directory
ls -la /data/coolify/services/ | grep grafana

# 3. Gå till Grafana service
cd /data/coolify/services/<grafana-service-id>

# 4. Redigera docker-compose.yml
nano docker-compose.yml

# 5. Uppdatera image-tag
# Ändra från: image: grafana/grafana:latest
# Till: image: grafana/grafana:10.2.0

# 6. Uppdatera och starta om
docker compose pull
docker compose up -d

# 7. Verifiera
docker compose ps
docker logs <grafana-container-name> --tail 20
```

## Hitta Senaste Version

**Docker Hub:**
- https://hub.docker.com/r/grafana/grafana/tags

**GitHub Releases:**
- https://github.com/grafana/grafana/releases

**Rekommendation:**
- Använd specifika versioner istället för `:latest`
- Format: `MAJOR.MINOR.PATCH` (t.ex. `10.2.0`)
- Undvik beta/alpha-versioner i produktion

## Breaking Changes

**Viktigt:** Kontrollera alltid release notes för breaking changes:
- https://github.com/grafana/grafana/blob/main/CHANGELOG.md

**Vanliga breaking changes:**
- Major version-uppgraderingar (t.ex. 9.x → 10.x)
- Plugin-API-ändringar
- Datasource-ändringar
- Dashboard-format-ändringar

## Verifiera Uppdatering

Efter uppdatering, kontrollera:

```bash
# Kontrollera container status
ssh tha 'docker ps | grep grafana'

# Kontrollera logs
ssh tha 'docker logs <grafana-container-name> --tail 50'

# Testa Grafana dashboard
curl -I https://analytics.thehockeyanalytics.com
```

## Backup innan Uppdatering

**Viktigt:** Säkerhetskopiera data innan större uppdateringar:

```bash
# Backup Grafana data volume
ssh tha 'docker run --rm -v grafana_data:/data -v $(pwd):/backup alpine tar czf /backup/grafana-backup-$(date +%Y%m%d).tar.gz /data'
```

## Best Practices

1. **Använd specifika versioner** istället för `:latest`
2. **Testa i staging** först (om möjligt)
3. **Säkerhetskopiera data** innan större uppdateringar
4. **Läs release notes** för breaking changes
5. **Uppdatera regelbundet** för säkerhetsuppdateringar
6. **Kontrollera plugin-kompatibilitet** innan uppdatering

## Troubleshooting

### Service startar inte efter uppdatering

```bash
# Kolla logs
ssh tha 'docker logs <grafana-container-name>'

# Starta om service
ssh tha 'cd /data/coolify/services/<grafana-service-id> && docker compose restart'
```

### Dashboards försvinner

```bash
# Kontrollera data volume
ssh tha 'docker volume inspect grafana_data'

# Återställ från backup om nödvändigt
```

### Plugin-problem

```bash
# Lista installerade plugins
ssh tha 'docker exec <grafana-container-name> grafana-cli plugins ls'

# Uppdatera plugins efter Grafana-uppdatering
ssh tha 'docker exec <grafana-container-name> grafana-cli plugins update-all'
```

## Ytterligare Resurser

- **Grafana Dokumentation:** https://grafana.com/docs/
- **Grafana GitHub:** https://github.com/grafana/grafana
- **Coolify Dashboard:** https://coolify.theunnamedroads.com

