#!/usr/bin/env bash
set -euo pipefail

# start-langflow.sh - Startar Langflow och Traefik

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

echo "🚀 Startar Langflow och Traefik"
echo "==============================="
echo ""

ssh "$HOST" bash <<'REMOTE'
CONTAINER="langflow-rog04sw8kcc0g848cs4cocso"
TRAEFIK="coolify-proxy"

echo "1️⃣  Startar Traefik (coolify-proxy)..."
if docker ps -a --filter "name=$TRAEFIK" --format '{{.Names}}' | grep -q "$TRAEFIK"; then
    docker start "$TRAEFIK" 2>/dev/null && echo "  ✅ Traefik startad" || echo "  ⚠️  Kunde inte starta Traefik"
    sleep 2
else
    echo "  ⚠️  Traefik container hittades inte: $TRAEFIK"
    echo "  💡 Starta Traefik via Coolify Dashboard"
fi

echo ""
echo "2️⃣  Startar Langflow container..."
if docker ps -a --filter "name=$CONTAINER" --format '{{.Names}}' | grep -q "$CONTAINER"; then
    docker start "$CONTAINER" 2>/dev/null && echo "  ✅ Langflow startad" || {
        echo "  ⚠️  Kunde inte starta med docker start, försöker med docker-compose..."
        SERVICE_DIR="/data/coolify/services/rog04sw8kcc0g848cs4cocso"
        if [ -f "$SERVICE_DIR/docker-compose.yml" ]; then
            cd "$SERVICE_DIR"
            docker-compose up -d 2>/dev/null && echo "  ✅ Langflow startad via docker-compose" || echo "  ❌ Kunde inte starta Langflow"
        else
            echo "  ❌ docker-compose.yml saknas"
        fi
    }
    sleep 3
else
    echo "  ❌ Langflow container hittades inte: $CONTAINER"
fi

echo ""
echo "3️⃣  Verifierar status..."
sleep 2

# Kontrollera Traefik
TRAEFIK_STATUS=$(docker ps --filter "name=$TRAEFIK" --format '{{.State.Status}}' 2>/dev/null || echo "stopped")
if [ "$TRAEFIK_STATUS" = "running" ]; then
    echo "  ✅ Traefik körs"
else
    echo "  ❌ Traefik körs inte (status: $TRAEFIK_STATUS)"
    echo "  💡 Starta Traefik via Coolify Dashboard: Settings → Proxy → Start"
fi

# Kontrollera Langflow
LANGFLOW_STATUS=$(docker ps --filter "name=$CONTAINER" --format '{{.State.Status}}' 2>/dev/null || echo "stopped")
if [ "$LANGFLOW_STATUS" = "running" ]; then
    echo "  ✅ Langflow körs"
    
    # Vänta lite och testa port
    sleep 2
    if docker exec "$CONTAINER" curl -sf http://127.0.0.1:7860 >/dev/null 2>&1; then
        echo "  ✅ Port 7860 svarar"
    else
        echo "  ⚠️  Port 7860 svarar inte ännu (kan ta några sekunder att starta)"
        echo "  📋 Container logs:"
        docker logs "$CONTAINER" --tail 10 2>/dev/null | sed 's/^/    /' || echo "    Kunde inte hämta logs"
    fi
else
    echo "  ❌ Langflow körs inte (status: $LANGFLOW_STATUS)"
    echo "  📋 Senaste logs:"
    docker logs "$CONTAINER" --tail 20 2>/dev/null | sed 's/^/    /' || echo "    Kunde inte hämta logs"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 SAMMANFATTNING"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Om något fortfarande inte fungerar:"
echo "   1. Starta Traefik via Coolify Dashboard: Settings → Proxy → Start"
echo "   2. Starta Langflow via Coolify Dashboard: Langflow service → Start"
echo "   3. Vänta 1-2 minuter och testa:"
echo "      http://langflow-rog04sw8kcc0g848cs4cocso.46.62.206.47.sslip.io"
echo ""
REMOTE

echo ""
info "Start-script körs!"
echo ""


