# Langflow - Deployment Guide

## Steg 1: Deploya i Coolify Dashboard

1. **Öppna Coolify Dashboard**
   - Gå till: https://coolify.theunnamedroads.com
   - Logga in

2. **Gå till ditt projekt**
   - Välj projektet "theunnamedroads platform"

3. **Skapa ny resurs**
   - Klicka på "Create New Resource" eller "+"
   - Välj "Docker Compose" eller "From Git" (om du har pushat till Git)

4. **Konfigurera deployment**
   - Om från Git: Ange repository och branch
   - Om Docker Compose: Kopiera innehållet från `langflow/docker-compose.yml`
   - Välj build pack: "Docker Compose"

5. **Deploy**
   - Klicka på "Deploy" eller "Save & Deploy"
   - Vänta på att deploymenten slutförs (2-5 minuter)

## Steg 2: Konfigurera Domän

**⚠️ Om du inte hittar domain-inställningar, se [FIND-DOMAIN-SETTINGS.md](FIND-DOMAIN-SETTINGS.md)**

1. **Öppna Langflow service**
   - Gå till projektet "theunnamedroads platform"
   - Klicka på Langflow service

2. **Hitta domain-inställningar** (kan vara på olika ställen):
   - **Alternativ 1:** Klicka på "Domains" eller "Edit Domains" (knapp/flik)
   - **Alternativ 2:** Klicka på "Settings" → "Domains"
   - **Alternativ 3:** Klicka på "Edit" → Scrolla ner till "Domains"
   - **Alternativ 4:** Under "Deploy" kan domain konfigureras

3. **Lägg till domän**
   - **För test:** Använd den genererade sslip.io-domänen
   - **För produktion:** Lägg till `langflow.theunnamedroads.com` (utan port)

4. **Spara**
   - Klicka "Save" eller "Deploy"
   - Coolify kommer automatiskt att:
     - Lägga till Traefik labels
     - Konfigurera SSL/TLS via Let's Encrypt
     - Skapa reverse proxy routing

**Om du inte hittar domain-inställningar i UI:**
- Se [FIND-DOMAIN-SETTINGS.md](FIND-DOMAIN-SETTINGS.md) för manuell konfiguration
- Eller lägg till Traefik labels direkt i docker-compose.yml (se guide ovan)

## Steg 3: Konfigurera DNS (Om egen domän)

Om du använder `langflow.theunnamedroads.com`:

1. **Gå till Cloudflare (eller din DNS-provider)**
   - Logga in på Cloudflare Dashboard

2. **Lägg till A-record**
   - **Type:** A
   - **Name:** langflow
   - **IPv4 address:** `46.62.206.47` (din Hetzner server IP)
   - **Proxy status:** Proxied (orange cloud) - för SSL/TLS
   - **TTL:** Auto

3. **Vänta på DNS propagation**
   - Det kan ta 1-5 minuter för DNS att uppdateras

## Steg 4: Verifiera Deployment

### Via Coolify Dashboard:
1. Gå till Langflow service
2. Kontrollera att status är "Running" (grön)
3. Klicka på domänen för att öppna Langflow

### Via SSH:
```bash
# SSH till servern
ssh tha

# Kontrollera container status
docker ps | grep langflow

# Kontrollera logs
docker logs <langflow-container-name> --tail 50

# Kontrollera Traefik labels
docker inspect <langflow-container-name> | grep -A 20 traefik
```

### Via Webbläsare:
1. Öppna din domän:
   - Test: `http://langflow-<id>.46.62.206.47.sslip.io:7860`
   - Produktion: `https://langflow.theunnamedroads.com`

2. Du bör se Langflow's inloggningssida eller dashboard

## Steg 5: Första Gången

1. **Öppna Langflow**
   - Gå till din domän i webbläsaren

2. **Skapa konto**
   - Följ Langflow's setup-guide
   - Skapa ditt första admin-konto

3. **Börja bygga flows**
   - Langflow är nu redo att användas!

## Troubleshooting

### Service startar inte
```bash
ssh tha
docker logs <langflow-container-name>
# Kontrollera felmeddelanden
```

### 404 eller "Not Available"
1. Kontrollera Traefik labels:
   ```bash
   ssh tha
   docker inspect <langflow-container-name> | grep traefik
   ```

2. Kontrollera att containern körs:
   ```bash
   docker ps | grep langflow
   ```

3. Se [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) för mer hjälp

### DNS fungerar inte
- Kontrollera A-record i Cloudflare
- Vänta på DNS propagation (kan ta upp till 5 minuter)
- Testa med: `nslookup langflow.theunnamedroads.com`

### SSL/TLS fungerar inte
- Coolify konfigurerar automatiskt Let's Encrypt
- Vänta 1-2 minuter efter deployment
- Kontrollera att DNS är korrekt konfigurerad

## Ytterligare Resurser

- **Langflow Dokumentation:** https://docs.langflow.org/
- **Coolify Dokumentation:** https://coolify.io/docs
- **Projekt Troubleshooting:** [../TROUBLESHOOTING.md](../TROUBLESHOOTING.md)

