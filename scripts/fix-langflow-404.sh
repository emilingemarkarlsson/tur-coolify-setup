#!/usr/bin/env bash
set -euo pipefail

# fix-langflow-404.sh - Fixar 404-fel för Langflow

HOST="${1:-tha}"

# Färger
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
section() { echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${CYAN}$1${NC}"; }

echo "🔧 Fixar Langflow 404-fel"
echo "=========================="
echo ""

# ============================================================================
# STEG 1: Hitta Langflow Container
# ============================================================================
section "STEG 1: Hittar Langflow Container"

LANGFLOW_INFO=$(ssh "$HOST" bash <<'REMOTE'
# Hitta Langflow container
CONTAINER=$(docker ps -a --filter "name=langflow" --format '{{.Names}}' 2>/dev/null | head -1)

if [ -z "$CONTAINER" ]; then
    echo "NOT_FOUND"
    exit 0
fi

# Hitta service directory
SERVICE_DIR=$(docker inspect "$CONTAINER" --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' 2>/dev/null || echo "")

if [ -z "$SERVICE_DIR" ]; then
    # Försök hitta via container name
    SERVICE_ID=$(echo "$CONTAINER" | grep -oE '[a-z0-9]{20,}' | head -1 || echo "")
    if [ -n "$SERVICE_ID" ]; then
        SERVICE_DIR="/data/coolify/services/$SERVICE_ID"
    fi
fi

echo "$CONTAINER|$SERVICE_DIR"
REMOTE
)

if [ "$LANGFLOW_INFO" = "NOT_FOUND" ]; then
    error "Langflow container hittades inte"
    echo ""
    echo "💡 Kontrollera att Langflow är deployad i Coolify Dashboard"
    exit 1
fi

CONTAINER_NAME=$(echo "$LANGFLOW_INFO" | cut -d'|' -f1)
SERVICE_DIR=$(echo "$LANGFLOW_INFO" | cut -d'|' -f2)

info "Container: $CONTAINER_NAME"
info "Service directory: $SERVICE_DIR"
echo ""

# ============================================================================
# STEG 2: Kontrollera Container Status
# ============================================================================
section "STEG 2: Kontrollerar Container Status"

CONTAINER_STATUS=$(ssh "$HOST" docker ps --filter "name=$CONTAINER_NAME" --format '{{.State.Status}}' 2>/dev/null || echo "not_running")

if [ "$CONTAINER_STATUS" != "running" ]; then
    warn "Container är inte running: $CONTAINER_STATUS"
    echo ""
    echo "🔄 Startar container..."
    ssh "$HOST" docker start "$CONTAINER_NAME" || error "Kunde inte starta container"
    sleep 3
else
    info "Container körs"
fi

# ============================================================================
# STEG 3: Kontrollera Traefik Labels
# ============================================================================
section "STEG 3: Kontrollerar Traefik Labels"

TRAEFIK_LABELS=$(ssh "$HOST" docker inspect "$CONTAINER_NAME" --format '{{range $k, $v := .Config.Labels}}{{if match $k "traefik.*"}}{{$k}}={{$v}}{{println}}{{end}}{{end}}' 2>/dev/null)

if [ -z "$TRAEFIK_LABELS" ]; then
    warn "Inga Traefik labels hittades!"
    echo ""
    echo "🔧 Lägger till Traefik labels..."
    
    # Hämta domain från docker-compose.yml eller använd default
    DOMAIN=$(ssh "$HOST" "grep -E 'traefik.http.routers.*.rule=Host' '$SERVICE_DIR/docker-compose.yml' 2>/dev/null | sed 's/.*Host(\`\([^`]*\)\`).*/\1/' | head -1" || echo "")
    
    if [ -z "$DOMAIN" ]; then
        # Hitta domain från container environment
        DOMAIN=$(ssh "$HOST" docker inspect "$CONTAINER_NAME" --format '{{range .Config.Env}}{{if match . "SERVICE_URL.*"}}{{.}}{{println}}{{end}}{{end}}' 2>/dev/null | grep -oE '[a-z0-9.-]+\.sslip\.io' | head -1 || echo "")
    fi
    
    if [ -z "$DOMAIN" ]; then
        warn "Kunde inte hitta domain, använder default"
        DOMAIN="langflow-rog04sw8kcc0g848cs4cocso.46.62.206.47.sslip.io"
    fi
    
    info "Använder domain: $DOMAIN"
    echo ""
    
    # Lägg till labels i docker-compose.yml
    ssh "$HOST" bash <<REMOTE
cd "$SERVICE_DIR"

# Backup
cp docker-compose.yml docker-compose.yml.backup 2>/dev/null || true

# Hämta nuvarande domain från environment eller använd default
CURRENT_DOMAIN="$DOMAIN"

# Lägg till labels (ersätt befintliga om de finns)
if ! grep -q "traefik.http.routers.langflow.rule" docker-compose.yml 2>/dev/null; then
    # Hitta var labels ska läggas till (efter volumes eller environment)
    if grep -A 20 "^  langflow:" docker-compose.yml | grep -q "volumes:"; then
        # Lägg till efter volumes
        sed -i '/^  langflow:/,/^  [a-z]/ { /volumes:/a\    labels:\n      - "traefik.enable=true"\n      - "traefik.http.routers.langflow.rule=Host(\`'"$DOMAIN"'\`)"\n      - "traefik.http.routers.langflow.entrypoints=https"\n      - "traefik.http.routers.langflow.tls=true"\n      - "traefik.http.routers.langflow.tls.certresolver=letsencrypt"\n      - "traefik.http.services.langflow.loadbalancer.server.port=7860"\n      - "traefik.http.routers.langflow.service=langflow"\n      - "traefik.http.routers.langflow-http.entrypoints=http"\n      - "traefik.http.routers.langflow-http.rule=Host(\`'"$DOMAIN"'\`)"\n      - "traefik.http.routers.langflow-http.middlewares=redirect-to-https"\n      - "traefik.http.routers.langflow-http.service=langflow"\n      - "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https"\n      - "traefik.http.middlewares.redirect-to-https.redirectscheme.permanent=true"' docker-compose.yml
    elif grep -A 20 "^  langflow:" docker-compose.yml | grep -q "environment:"; then
        # Lägg till efter environment
        sed -i '/^  langflow:/,/^  [a-z]/ { /environment:/a\    labels:\n      - "traefik.enable=true"\n      - "traefik.http.routers.langflow.rule=Host(\`'"$DOMAIN"'\`)"\n      - "traefik.http.routers.langflow.entrypoints=https"\n      - "traefik.http.routers.langflow.tls=true"\n      - "traefik.http.routers.langflow.tls.certresolver=letsencrypt"\n      - "traefik.http.services.langflow.loadbalancer.server.port=7860"\n      - "traefik.http.routers.langflow.service=langflow"\n      - "traefik.http.routers.langflow-http.entrypoints=http"\n      - "traefik.http.routers.langflow-http.rule=Host(\`'"$DOMAIN"'\`)"\n      - "traefik.http.routers.langflow-http.middlewares=redirect-to-https"\n      - "traefik.http.routers.langflow-http.service=langflow"\n      - "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https"\n      - "traefik.http.middlewares.redirect-to-https.redirectscheme.permanent=true"' docker-compose.yml
    else
        # Lägg till direkt efter service name
        sed -i '/^  langflow:/a\    labels:\n      - "traefik.enable=true"\n      - "traefik.http.routers.langflow.rule=Host(\`'"$DOMAIN"'\`)"\n      - "traefik.http.routers.langflow.entrypoints=https"\n      - "traefik.http.routers.langflow.tls=true"\n      - "traefik.http.routers.langflow.tls.certresolver=letsencrypt"\n      - "traefik.http.services.langflow.loadbalancer.server.port=7860"\n      - "traefik.http.routers.langflow.service=langflow"\n      - "traefik.http.routers.langflow-http.entrypoints=http"\n      - "traefik.http.routers.langflow-http.rule=Host(\`'"$DOMAIN"'\`)"\n      - "traefik.http.routers.langflow-http.middlewares=redirect-to-https"\n      - "traefik.http.routers.langflow-http.service=langflow"\n      - "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https"\n      - "traefik.http.middlewares.redirect-to-https.redirectscheme.permanent=true"' docker-compose.yml
    fi
fi

# Lägg till networks om de saknas
if ! grep -q "networks:" docker-compose.yml 2>/dev/null; then
    echo "" >> docker-compose.yml
    echo "networks:" >> docker-compose.yml
    echo "  coolify:" >> docker-compose.yml
    echo "    external: true" >> docker-compose.yml
fi

    # Lägg till network till service om det saknas
if ! grep -A 30 "^  langflow:" docker-compose.yml | grep -q "networks:"; then
    # Lägg till efter healthcheck, labels, eller volumes
    if grep -A 30 "^  langflow:" docker-compose.yml | grep -q "healthcheck:"; then
        sed -i '/^  langflow:/,/^  [a-z]/ { /healthcheck:/a\    networks:\n      - coolify' docker-compose.yml
    elif grep -A 30 "^  langflow:" docker-compose.yml | grep -q "labels:"; then
        sed -i '/^  langflow:/,/^  [a-z]/ { /labels:/a\    networks:\n      - coolify' docker-compose.yml
    elif grep -A 30 "^  langflow:" docker-compose.yml | grep -q "volumes:"; then
        sed -i '/^  langflow:/,/^  [a-z]/ { /volumes:/a\    networks:\n      - coolify' docker-compose.yml
    fi
fi

# Anslut containern till coolify-nätverket direkt om den körs
if docker ps --filter "name=$CONTAINER_NAME" --format '{{.Names}}' | grep -q "$CONTAINER_NAME"; then
    if ! docker inspect "$CONTAINER_NAME" --format '{{range \$net, \$conf := .NetworkSettings.Networks}}{{\$net}}{{println}}{{end}}' | grep -q "coolify"; then
        echo "Ansluter container till coolify-nätverket..."
        docker network connect coolify "$CONTAINER_NAME" 2>/dev/null || echo "Kunde inte ansluta (kan redan vara ansluten eller nätverket saknas)"
    fi
fi

echo "✅ docker-compose.yml uppdaterad"
REMOTE

    # Starta om servicen
    echo ""
    echo "🔄 Startar om Langflow..."
    ssh "$HOST" bash <<REMOTE
cd "$SERVICE_DIR"
docker compose down
docker compose up -d
REMOTE

    info "Langflow omstartad med Traefik labels"
else
    info "Traefik labels finns redan"
    echo ""
    echo "📋 Nuvarande Traefik labels:"
    echo "$TRAEFIK_LABELS" | sed 's/^/  /'
fi

# ============================================================================
# STEG 4: Kontrollera Nätverk
# ============================================================================
section "STEG 4: Kontrollerar Nätverk"

NETWORK_CHECK=$(ssh "$HOST" docker inspect "$CONTAINER_NAME" --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}}{{println}}{{end}}' 2>/dev/null | grep coolify || echo "")

if [ -z "$NETWORK_CHECK" ]; then
    warn "Container är inte ansluten till coolify-nätverket"
    echo ""
    echo "🔧 Ansluter till coolify-nätverket..."
    ssh "$HOST" docker network connect coolify "$CONTAINER_NAME" 2>/dev/null || warn "Kunde inte ansluta (kan redan vara ansluten)"
else
    info "Container är ansluten till coolify-nätverket"
fi

# ============================================================================
# STEG 5: Kontrollera Port
# ============================================================================
section "STEG 5: Kontrollerar Port"

PORT_CHECK=$(ssh "$HOST" docker exec "$CONTAINER_NAME" curl -sf http://127.0.0.1:7860 >/dev/null 2>&1 && echo "ok" || echo "fail")

if [ "$PORT_CHECK" = "ok" ]; then
    info "Port 7860 svarar"
else
    warn "Port 7860 svarar inte"
    echo ""
    echo "📋 Container logs:"
    ssh "$HOST" docker logs "$CONTAINER_NAME" --tail 20
fi

# ============================================================================
# STEG 6: Kontrollera Traefik
# ============================================================================
section "STEG 6: Kontrollerar Traefik"

# Hitta Traefik container (kan ha olika namn)
TRAEFIK_CONTAINER=$(ssh "$HOST" docker ps -a --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1 || echo "")

if [ -z "$TRAEFIK_CONTAINER" ]; then
    # Försök hitta via coolify proxy
    TRAEFIK_CONTAINER=$(ssh "$HOST" docker ps -a --filter "name=coolify" --filter "label=com.docker.compose.service=proxy" --format '{{.Names}}' 2>/dev/null | head -1 || echo "")
fi

if [ -z "$TRAEFIK_CONTAINER" ]; then
    # Försök hitta alla containers med traefik i image
    TRAEFIK_CONTAINER=$(ssh "$HOST" docker ps -a --filter "ancestor=traefik" --format '{{.Names}}' 2>/dev/null | head -1 || echo "")
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_STATUS=$(ssh "$HOST" docker ps --filter "name=$TRAEFIK_CONTAINER" --format '{{.State.Status}}' 2>/dev/null || echo "not_running")
    
    if [ "$TRAEFIK_STATUS" != "running" ]; then
        warn "Traefik ($TRAEFIK_CONTAINER) körs inte!"
        echo ""
        echo "🔄 Startar Traefik..."
        ssh "$HOST" docker start "$TRAEFIK_CONTAINER" 2>/dev/null || warn "Kunde inte starta Traefik"
        sleep 2
    else
        info "Traefik ($TRAEFIK_CONTAINER) körs"
    fi
else
    error "Traefik container hittades inte!"
    echo ""
    echo "💡 Traefik bör köras som del av Coolify. Kontrollera Coolify status."
    echo "   ssh $HOST 'docker ps | grep coolify'"
fi

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning"

echo ""
info "Diagnostik klar!"
echo ""
echo "💡 Testa nu:"
echo "   http://langflow-rog04sw8kcc0g848cs4cocso.46.62.206.47.sslip.io"
echo ""
echo "📋 Om det fortfarande inte fungerar:"
echo "   1. Kontrollera Traefik logs: ssh tha 'docker logs traefik --tail 50'"
echo "   2. Kontrollera Langflow logs: ssh tha 'docker logs $CONTAINER_NAME --tail 50'"
echo "   3. Vänta 1-2 minuter för Traefik att uppdatera routing"
echo ""

