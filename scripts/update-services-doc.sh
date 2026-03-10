#!/usr/bin/env bash
set -euo pipefail

# update-services-doc.sh - Uppdaterar SERVICES.md med aktiva services från Coolify

HOST="${1:-tha}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Hämta aktiva services
ACTIVE_SERVICES=$(ssh "$HOST" bash <<'REMOTE'
if [ -d "/data/coolify/services" ]; then
    for service_dir in /data/coolify/services/*; do
        if [ -d "$service_dir" ] && [ -f "$service_dir/docker-compose.yml" ]; then
            SERVICE_ID=$(basename "$service_dir")
            CONTAINER_NAME=$(grep -E "^\s+container_name:" "$service_dir/docker-compose.yml" 2>/dev/null | sed 's/.*container_name:[[:space:]]*//' | tr -d "'\"" || echo "")
            IMAGE=$(grep -E "^\s+image:" "$service_dir/docker-compose.yml" 2>/dev/null | head -1 | sed 's/.*image:[[:space:]]*//' | tr -d "'\"" || echo "")
            DOMAIN=$(grep -E "traefik.http.routers.*.rule=Host" "$service_dir/docker-compose.yml" 2>/dev/null | sed 's/.*Host(`\([^`]*\)`).*/\1/' || echo "")
            
            # Identifiera service-typ
            SERVICE_TYPE=""
            if [[ "$CONTAINER_NAME" == *"n8n"* ]] || [[ "$IMAGE" == *"n8n"* ]]; then
                SERVICE_TYPE="n8n"
            elif [[ "$CONTAINER_NAME" == *"minio"* ]] || [[ "$IMAGE" == *"minio"* ]]; then
                SERVICE_TYPE="minio"
            elif [[ "$CONTAINER_NAME" == *"open-webui"* ]] || [[ "$IMAGE" == *"open-webui"* ]] || [[ "$IMAGE" == *"openwebui"* ]]; then
                SERVICE_TYPE="open-webui"
            fi
            
            if [ -n "$SERVICE_TYPE" ]; then
                echo "$SERVICE_TYPE|$IMAGE|$DOMAIN"
            fi
        fi
    done
fi
REMOTE
)

# Uppdatera SERVICES.md
cat > "$PROJECT_ROOT/SERVICES.md" <<'EOF'
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

EOF

# Lägg till aktiva services
COUNTER=1
while IFS='|' read -r SERVICE_TYPE IMAGE DOMAIN; do
    if [ -z "$SERVICE_TYPE" ]; then
        continue
    fi
    
    # Konvertera till läsbart namn (bash-kompatibel)
    SERVICE_NAME=$(echo "$SERVICE_TYPE" | sed 's/-/ /g' | sed 's/^./\U&/')
    
    cat >> "$PROJECT_ROOT/SERVICES.md" <<SERVICE
### ${COUNTER}. ${SERVICE_NAME}
- **Directory:** \`${SERVICE_TYPE}/\`
${DOMAIN:+- **Domain:** \`${DOMAIN}\`}
- **Image:** \`${IMAGE}\`
- **Uppdateringsguide:** [${SERVICE_TYPE}/UPGRADE.md](${SERVICE_TYPE}/UPGRADE.md)
- **Status:** Kontrollera med scriptet ovan

SERVICE
    
    COUNTER=$((COUNTER + 1))
done <<< "$ACTIVE_SERVICES"

cat >> "$PROJECT_ROOT/SERVICES.md" <<'EOF'

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

EOF

# Lägg till länkar till uppdateringsguider
while IFS='|' read -r SERVICE_TYPE IMAGE DOMAIN; do
    if [ -n "$SERVICE_TYPE" ]; then
        # Konvertera till stor första bokstav (bash-kompatibel)
        SERVICE_NAME=$(echo "$SERVICE_TYPE" | sed 's/^./\U&/')
        echo "- **${SERVICE_NAME}:** [${SERVICE_TYPE}/UPGRADE.md](${SERVICE_TYPE}/UPGRADE.md)" >> "$PROJECT_ROOT/SERVICES.md"
    fi
done <<< "$ACTIVE_SERVICES"

cat >> "$PROJECT_ROOT/SERVICES.md" <<'EOF'

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

EOF

echo "✅ Uppdaterade SERVICES.md"

