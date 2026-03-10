# Langflow - Uppdateringsguide

## Nuvarande Konfiguration

- **Image:** `langflowai/langflow:latest`
- **Directory:** `langflow/`
- **Domain:** `langflow.theunnamedroads.com`
- **Status:** Aktiv i Coolify

## Uppdateringsmetoder

### Metod 1: Via Coolify Dashboard (Rekommenderat)

1. **Öppna Coolify Dashboard**
   - Gå till: https://coolify.theunnamedroads.com
   - Logga in

2. **Hitta Langflow Service**
   - Navigera till projektet "theunnamedroads platform"
   - Välj Langflow service

3. **Uppdatera Image**
   - Klicka på "Edit Compose"
   - Ändra image från `langflowai/langflow:latest` till senaste version
   - Rekommenderat: `langflowai/langflow:latest` (eller specifik tag)
   - Klicka "Deploy"

### Metod 2: Via SSH (Manuellt)

```bash
# 1. SSH till servern
ssh tha

# 2. Hitta Langflow service directory
ls -la /data/coolify/services/ | grep langflow

# 3. Gå till Langflow service
cd /data/coolify/services/<service-id>

# 4. Backup docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup

# 5. Uppdatera image-tag
# Ändra från: image: langflowai/langflow:latest
# Till: image: langflowai/langflow:<ny-version>

# 6. Uppdatera via docker-compose
docker-compose pull
docker-compose up -d
```

### Metod 3: Via Git (Om synkat)

```bash
# 1. Uppdatera docker-compose.yml lokalt
cd ~/Documents/dev/tur-coolify-setup/langflow
# Redigera docker-compose.yml och uppdatera image

# 2. Commit och push
git add langflow/docker-compose.yml
git commit -m "Update Langflow to latest version"
git push

# 3. SSH till servern och pull
ssh tha
cd /data/coolify/services/<service-id>
git pull
docker-compose pull
docker-compose up -d
```

## Hitta Senaste Version

**Docker Hub:**
- https://hub.docker.com/r/langflowai/langflow/tags

**GitHub:**
- https://github.com/langflow-ai/langflow/releases

## Verifiera Uppdatering

```bash
# SSH till servern
ssh tha

# Kontrollera version
docker exec tha_langflow langflow --version

# Kontrollera container status
docker ps | grep langflow

# Kontrollera logs
docker logs tha_langflow --tail 50
```

## Troubleshooting

### Service startar inte
1. Kontrollera logs: `docker logs tha_langflow`
2. Kontrollera diskutrymme: `df -h`
3. Kontrollera Docker: `docker ps -a | grep langflow`

### 404 eller "Not Available"
1. Kontrollera Traefik labels i docker-compose.yml
2. Verifiera att containern körs: `docker ps | grep langflow`
3. Kontrollera nätverk: `docker network inspect coolify`
4. Se [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) för mer hjälp

### Port-konflikter
- Langflow använder port 7860 internt
- Externa portar hanteras av Traefik
- Kontrollera att ingen annan service använder port 7860

## Best Practices

1. **Backup innan uppdatering**
   - Backup volumes: `docker run --rm -v langflow_data:/data -v $(pwd):/backup alpine tar czf /backup/langflow-backup.tar.gz /data`

2. **Testa i staging först** (om tillgängligt)

3. **Uppdatera regelbundet**
   - Kontrollera nya versioner månadsvis
   - Följ Langflow's release notes

4. **Övervaka efter uppdatering**
   - Kontrollera logs första timmen
   - Verifiera att alla funktioner fungerar

## Rollback

Om något går fel efter uppdatering:

```bash
# 1. SSH till servern
ssh tha

# 2. Gå till service directory
cd /data/coolify/services/<service-id>

# 3. Återställ backup
cp docker-compose.yml.backup docker-compose.yml

# 4. Pull och starta om
docker-compose pull
docker-compose up -d
```

## Ytterligare Resurser

- **Langflow Dokumentation:** https://docs.langflow.org/
- **Langflow GitHub:** https://github.com/langflow-ai/langflow
- **Coolify Dokumentation:** https://coolify.io/docs
- **Projekt Troubleshooting:** [../TROUBLESHOOTING.md](../TROUBLESHOOTING.md)


