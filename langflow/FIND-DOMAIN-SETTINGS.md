# Hitta Domain-inställningar i Coolify

## Var hittar jag Domain-inställningar?

Domain-inställningar kan finnas på olika ställen beroende på Coolify-version och hur servicen är deployad:

### Metod 1: I Service-sidan (vanligast)

1. **Öppna Langflow service**
   - Gå till projektet "theunnamedroads platform"
   - Klicka på Langflow service

2. **Leta efter dessa knappar/flikar:**
   - **"Domains"** (flik eller knapp)
   - **"Edit Domains"** (knapp)
   - **"Settings"** → **"Domains"**
   - **"Configuration"** → **"Domains"**
   - **"Edit"** → **"Domains"**

3. **Om du ser en "Deploy" eller "Redeploy" knapp:**
   - Klicka på den
   - Under deployment kan du ofta konfigurera domain

### Metod 2: Under Deployment

Om servicen precis deployats eller inte är helt konfigurerad:

1. **Gå till Langflow service**
2. **Klicka på "Edit" eller "Edit Compose"**
3. **Scrolla ner** - domain-inställningar kan finnas längre ner på sidan
4. **Leta efter "Domains" eller "FQDN"**

### Metod 3: Via Service Settings

1. **I Langflow service-sidan**
2. **Klicka på kugghjulet (⚙️) eller "Settings"**
3. **Leta efter:**
   - "Domains"
   - "FQDN"
   - "Public URL"
   - "Proxy Configuration"

### Metod 4: Om inget fungerar - Manuellt via SSH

Om du inte hittar domain-inställningar i UI, kan du lägga till domänen manuellt:

```bash
# SSH till servern
ssh tha

# Hitta Langflow service directory
ls -la /data/coolify/services/ | grep langflow

# Gå till service directory
cd /data/coolify/services/<service-id>

# Öppna docker-compose.yml
nano docker-compose.yml
```

Sedan lägg till Traefik labels manuellt (se nästa avsnitt).

## Manuell Domain-konfiguration (Om UI saknas)

Om Coolify UI inte visar domain-inställningar, kan du lägga till dem manuellt i `docker-compose.yml`:

```yaml
services:
  langflow:
    image: 'langflowai/langflow:latest'
    environment:
      - SERVICE_URL_LANGFLOW_7860
      - LANGFLOW_HOST=0.0.0.0
      - LANGFLOW_PORT=7860
      - LANGFLOW_LOG_LEVEL=INFO
    volumes:
      - 'langflow_data:/app/data'
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.langflow.rule=Host(`langflow.theunnamedroads.com`)"
      - "traefik.http.routers.langflow.entrypoints=https"
      - "traefik.http.routers.langflow.tls=true"
      - "traefik.http.routers.langflow.tls.certresolver=letsencrypt"
      - "traefik.http.services.langflow.loadbalancer.server.port=7860"
      - "traefik.http.routers.langflow.service=langflow"
    healthcheck:
      test:
        - CMD
        - curl
        - '-f'
        - 'http://127.0.0.1:7860'
      interval: 5s
      timeout: 30s
      retries: 10
    networks:
      - coolify

volumes:
  langflow_data: null

networks:
  coolify:
    external: true
```

Sedan:
```bash
# I service directory
docker compose up -d
```

## Kontrollera om Domain redan är konfigurerad

```bash
ssh tha

# Hitta Langflow container
docker ps | grep langflow

# Kontrollera Traefik labels
docker inspect <container-name> | grep -A 20 traefik
```

Om du ser Traefik labels med din domän, är den redan konfigurerad!

## Tips

- **Coolify kan ha olika UI-versioner** - vissa versioner har domain-inställningar på olika ställen
- **Om servicen är ny** - domain kan konfigureras under första deployment
- **Kontrollera service-status** - om servicen inte är "Running" kan vissa inställningar vara dolda
- **Uppdatera sidan** - ibland behöver man refresha för att se alla inställningar

## Nästa steg

När du har hittat och konfigurerat domain:
1. Spara inställningarna
2. Vänta 1-2 minuter för SSL/TLS
3. Testa: `https://langflow.theunnamedroads.com`


