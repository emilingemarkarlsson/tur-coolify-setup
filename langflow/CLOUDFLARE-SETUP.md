# Langflow - Cloudflare Subdomän Setup

## Varför Cloudflare Subdomän?

- ✅ Fungerar med HTTPS (SSL-certifikat)
- ✅ Bättre routing och caching
- ✅ Mer professionell lösning
- ✅ Fungerar bättre med Traefik

## Steg 1: Lägg till Subdomän i Cloudflare

1. **Logga in på Cloudflare**
   - Gå till: https://dash.cloudflare.com
   - Välj ditt domän: `theunnamedroads.com`

2. **Lägg till A-record**
   - Klicka på "DNS" i menyn
   - Klicka "Add record"
   - Fyll i:
     - **Type:** A
     - **Name:** `langflow`
     - **IPv4 address:** `46.62.206.47` (din Hetzner server IP)
     - **Proxy status:** Proxied (orange cloud) ✅
     - **TTL:** Auto
   - Klicka "Save"

3. **Vänta på DNS propagation**
   - Det kan ta 1-5 minuter
   - Testa: `nslookup langflow.theunnamedroads.com`

## Steg 2: Uppdatera docker-compose.yml i Coolify

1. **Öppna Langflow service i Coolify**
   - Gå till: https://coolify.theunnamedroads.com
   - Öppna projektet "theunnamedroads platform"
   - Öppna Langflow service
   - Klicka "Edit Compose"

2. **Uppdatera domain i labels**
   - Ändra från:
     ```yaml
     - traefik.http.routers.langflow-http.rule=Host(`langflow-rog04sw8kcc0g848cs4cocso.46.62.206.47.sslip.io`)
     - traefik.http.routers.langflow-https.rule=Host(`langflow-rog04sw8kcc0g848cs4cocso.46.62.206.47.sslip.io`)
     ```
   
   - Till:
     ```yaml
     - traefik.http.routers.langflow-http.rule=Host(`langflow.theunnamedroads.com`)
     - traefik.http.routers.langflow-https.rule=Host(`langflow.theunnamedroads.com`)
     ```

3. **Lägg tillbaka redirect-middleware för HTTP** (nu när vi har SSL):
   ```yaml
   - traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https
   - traefik.http.middlewares.redirect-to-https.redirectscheme.permanent=true
   - traefik.http.routers.langflow-http.middlewares=redirect-to-https
   ```

4. **Spara och deploy**
   - Klicka "Save" eller "Deploy"
   - Vänta på deployment

## Steg 3: Verifiera

1. **Vänta 2-3 minuter** för:
   - DNS propagation
   - SSL-certifikat generering (Let's Encrypt)
   - Traefik routing uppdatering

2. **Testa URL:er:**
   - HTTP (redirectar till HTTPS): `http://langflow.theunnamedroads.com`
   - HTTPS: `https://langflow.theunnamedroads.com`

## Komplett docker-compose.yml för Cloudflare

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
      - traefik.enable=true
      - traefik.docker.network=coolify
      # HTTP entrypoint (redirectar till HTTPS)
      - traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https
      - traefik.http.middlewares.redirect-to-https.redirectscheme.permanent=true
      - traefik.http.routers.langflow-http.entrypoints=http
      - traefik.http.routers.langflow-http.rule=Host(`langflow.theunnamedroads.com`)
      - traefik.http.routers.langflow-http.middlewares=redirect-to-https
      - traefik.http.routers.langflow-http.service=langflow-svc
      # HTTPS entrypoint
      - traefik.http.routers.langflow-https.entrypoints=https
      - traefik.http.routers.langflow-https.rule=Host(`langflow.theunnamedroads.com`)
      - traefik.http.routers.langflow-https.tls=true
      - traefik.http.routers.langflow-https.tls.certresolver=letsencrypt
      - traefik.http.routers.langflow-https.service=langflow-svc
      # Service definition
      - traefik.http.services.langflow-svc.loadbalancer.server.port=7860
    healthcheck:
      test:
        - CMD
        - curl
        - '-f'
        - 'http://127.0.0.1:7860/'
      interval: 5s
      timeout: 30s
      retries: 10
    networks:
      - coolify
    restart: unless-stopped

volumes:
  langflow_data: null

networks:
  coolify:
    external: true
```

## Troubleshooting

### DNS fungerar inte
```bash
# Testa DNS
nslookup langflow.theunnamedroads.com

# Bör visa: 46.62.206.47
```

### SSL-certifikat genereras inte
- Vänta 2-3 minuter
- Kontrollera Traefik logs: `docker logs coolify-proxy --tail 50`
- Kontrollera att DNS är korrekt (A-record med Proxied)

### Fortfarande 404
1. Kontrollera Traefik labels: `docker inspect langflow-rog04sw8kcc0g848cs4cocso | grep traefik`
2. Starta om Traefik: Settings → Proxy → Restart
3. Vänta 1-2 minuter

## Fördelar med Cloudflare

- ✅ HTTPS fungerar perfekt
- ✅ Automatisk SSL/TLS
- ✅ DDoS-skydd
- ✅ CDN och caching
- ✅ Bättre prestanda
- ✅ Professionell lösning


