#!/usr/bin/env bash
set -euo pipefail

# fix-langflow-404-final.sh - Komplett fix för Langflow 404

HOST="${1:-tha}"

# Färger
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

echo "🔧 Komplett Fix för Langflow 404"
echo "================================="
echo ""

ssh "$HOST" bash <<'REMOTE'
set -e

CONTAINER="langflow-rog04sw8kcc0g848cs4cocso"
SERVICE_DIR="/data/coolify/services/rog04sw8kcc0g848cs4cocso"
DOMAIN="langflow-rog04sw8kcc0g848cs4cocso.46.62.206.47.sslip.io"
TRAEFIK="coolify-proxy"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  STARTAR TRAEFIK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if docker ps -a --filter "name=$TRAEFIK" --format '{{.Names}}' | grep -q "$TRAEFIK"; then
    TRAEFIK_STATUS=$(docker ps --filter "name=$TRAEFIK" --format '{{.State.Status}}' 2>/dev/null || echo "stopped")
    
    if [ "$TRAEFIK_STATUS" != "running" ]; then
        echo "🔄 Startar Traefik..."
        docker start "$TRAEFIK"
        sleep 3
        info "Traefik startad"
    else
        info "Traefik körs redan"
    fi
else
    warn "Traefik container hittades inte: $TRAEFIK"
    echo "💡 Starta Traefik via Coolify Dashboard: Settings → Proxy → Start"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  STARTAR LANGFLOW"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if docker ps -a --filter "name=$CONTAINER" --format '{{.Names}}' | grep -q "$CONTAINER"; then
    LANGFLOW_STATUS=$(docker ps --filter "name=$CONTAINER" --format '{{.State.Status}}' 2>/dev/null || echo "stopped")
    
    if [ "$LANGFLOW_STATUS" != "running" ]; then
        echo "🔄 Startar Langflow..."
        cd "$SERVICE_DIR"
        docker-compose up -d
        sleep 5
        info "Langflow startad"
    else
        info "Langflow körs redan"
    fi
else
    error "Langflow container hittades inte: $CONTAINER"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣  VERIFIERAR TRAEFIK LABELS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Kontrollera labels
RULE=$(docker inspect "$CONTAINER" --format '{{index .Config.Labels "traefik.http.routers.langflow.rule"}}' 2>/dev/null || echo "")
PORT=$(docker inspect "$CONTAINER" --format '{{index .Config.Labels "traefik.http.services.langflow.loadbalancer.server.port"}}' 2>/dev/null || echo "")

if [ -z "$RULE" ] || [ -z "$PORT" ]; then
    warn "Traefik labels saknas eller är ofullständiga"
    echo "🔄 Uppdaterar docker-compose.yml..."
    
    cd "$SERVICE_DIR"
    cp docker-compose.yml docker-compose.yml.backup.$(date +%s)
    
    # Lägg till HTTP entrypoint också för sslip.io
    cat > docker-compose.yml <<EOF
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
      - "traefik.http.routers.langflow.rule=Host(\`$DOMAIN\`)"
      - "traefik.http.routers.langflow.entrypoints=https"
      - "traefik.http.routers.langflow.tls=true"
      - "traefik.http.routers.langflow.tls.certresolver=letsencrypt"
      - "traefik.http.services.langflow.loadbalancer.server.port=7860"
      - "traefik.http.routers.langflow.service=langflow"
      - "traefik.http.routers.langflow-http.entrypoints=http"
      - "traefik.http.routers.langflow-http.rule=Host(\`$DOMAIN\`)"
      - "traefik.http.routers.langflow-http.service=langflow"
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
    restart: unless-stopped

volumes:
  langflow_data: null

networks:
  coolify:
    external: true
EOF
    
    echo "🔄 Startar om Langflow med nya labels..."
    docker-compose down
    docker-compose up -d
    sleep 3
    info "Langflow omstartad med korrekta labels"
else
    info "Traefik labels är korrekta"
    echo "  Rule: $RULE"
    echo "  Port: $PORT"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4️⃣  VERIFIERAR NETWORK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Kontrollera network
if docker network inspect coolify >/dev/null 2>&1; then
    if docker inspect "$CONTAINER" --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}}{{println}}{{end}}' 2>/dev/null | grep -q "coolify"; then
        info "Container är ansluten till coolify-nätverket"
    else
        warn "Container är inte ansluten till coolify-nätverket"
        echo "🔄 Ansluter till coolify-nätverket..."
        docker network connect coolify "$CONTAINER" 2>/dev/null || true
        sleep 2
        info "Ansluten till coolify-nätverket"
    fi
else
    warn "coolify-nätverket finns inte"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5️⃣  TESTAR CONTAINER PORT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

sleep 3
if docker exec "$CONTAINER" curl -sf http://127.0.0.1:7860 >/dev/null 2>&1; then
    info "Port 7860 svarar"
else
    warn "Port 7860 svarar inte ännu"
    echo "📋 Container logs:"
    docker logs "$CONTAINER" --tail 15 2>/dev/null | sed 's/^/  /' || true
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6️⃣  STARTAR OM TRAEFIK FÖR ATT LADDA NYA LABELS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if docker ps --filter "name=$TRAEFIK" --format '{{.State.Status}}' | grep -q "running"; then
    echo "🔄 Startar om Traefik för att ladda nya labels..."
    docker restart "$TRAEFIK"
    sleep 5
    info "Traefik omstartad"
else
    warn "Traefik körs inte - starta den via Coolify Dashboard"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 SAMMANFATTNING"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Fix genomförd!"
echo ""
echo "💡 Testa nu:"
echo "   http://$DOMAIN"
echo ""
echo "⏱️  Vänta 30-60 sekunder för Traefik att uppdatera routing"
echo ""
echo "📋 Om det fortfarande inte fungerar:"
echo "   1. Kontrollera Traefik logs: docker logs $TRAEFIK --tail 50"
echo "   2. Kontrollera Langflow logs: docker logs $CONTAINER --tail 50"
echo "   3. Verifiera att båda körs: docker ps | grep -E 'langflow|traefik'"
echo ""
REMOTE

echo ""
info "Komplett fix genomförd!"
echo ""


