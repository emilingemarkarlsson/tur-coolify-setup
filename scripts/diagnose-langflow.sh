#!/usr/bin/env bash
set -euo pipefail

# diagnose-langflow.sh - Systematisk diagnostik av Langflow 404

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

echo "🔍 Systematisk Diagnostik av Langflow"
echo "======================================"
echo ""

ssh "$HOST" bash <<'REMOTE'
CONTAINER="langflow-rog04sw8kcc0g848cs4cocso"
DOMAIN="langflow-rog04sw8kcc0g848cs4cocso.46.62.206.47.sslip.io"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  CONTAINER STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Kontrollera om containern finns
if docker ps -a --filter "name=$CONTAINER" --format '{{.Names}}' | grep -q "$CONTAINER"; then
    STATUS=$(docker ps --filter "name=$CONTAINER" --format '{{.State.Status}}' 2>/dev/null || echo "stopped")
    echo "Container: $CONTAINER"
    echo "Status: $STATUS"
    
    if [ "$STATUS" != "running" ]; then
        echo ""
        echo "❌ Container körs inte!"
        echo "📋 Senaste logs:"
        docker logs "$CONTAINER" --tail 20 2>/dev/null | sed 's/^/  /'
    else
        echo "✅ Container körs"
    fi
else
    echo "❌ Container hittades inte: $CONTAINER"
    echo ""
    echo "💡 Lista alla langflow-containers:"
    docker ps -a | grep langflow | sed 's/^/  /'
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  TRAEFIK LABELS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if docker ps -a --filter "name=$CONTAINER" --format '{{.Names}}' | grep -q "$CONTAINER"; then
    TRAEFIK_ENABLE=$(docker inspect "$CONTAINER" --format '{{index .Config.Labels "traefik.enable"}}' 2>/dev/null || echo "")
    RULE=$(docker inspect "$CONTAINER" --format '{{index .Config.Labels "traefik.http.routers.langflow.rule"}}' 2>/dev/null || echo "")
    PORT=$(docker inspect "$CONTAINER" --format '{{index .Config.Labels "traefik.http.services.langflow.loadbalancer.server.port"}}' 2>/dev/null || echo "")
    
    if [ "$TRAEFIK_ENABLE" = "true" ]; then
        echo "✅ traefik.enable=true"
    else
        echo "❌ traefik.enable saknas eller är false"
    fi
    
    if [ -n "$RULE" ]; then
        echo "✅ Router rule: $RULE"
        if echo "$RULE" | grep -q "$DOMAIN"; then
            echo "✅ Domain matchar: $DOMAIN"
        else
            echo "⚠️  Domain matchar inte! Förväntad: $DOMAIN"
        fi
    else
        echo "❌ Router rule saknas"
    fi
    
    if [ -n "$PORT" ]; then
        echo "✅ Port: $PORT"
        if [ "$PORT" = "7860" ]; then
            echo "✅ Port är korrekt (7860)"
        else
            echo "⚠️  Port är fel! Förväntad: 7860, Faktisk: $PORT"
        fi
    else
        echo "❌ Port saknas"
    fi
    
    echo ""
    echo "📋 Alla Traefik labels:"
    docker inspect "$CONTAINER" --format '{{range $k, $v := .Config.Labels}}{{if match $k "traefik.*"}}{{$k}}={{$v}}{{println}}{{end}}{{end}}' 2>/dev/null | sed 's/^/  /' || echo "  Inga Traefik labels"
else
    echo "❌ Kan inte kontrollera labels - container finns inte"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣  NETWORK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if docker ps -a --filter "name=$CONTAINER" --format '{{.Names}}' | grep -q "$CONTAINER"; then
    NETWORKS=$(docker inspect "$CONTAINER" --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}' 2>/dev/null || echo "")
    
    if echo "$NETWORKS" | grep -q "coolify"; then
        echo "✅ Container är ansluten till coolify-nätverket"
    else
        echo "❌ Container är INTE ansluten till coolify-nätverket"
        echo "  Nuvarande nätverk: $NETWORKS"
    fi
    
    # Kontrollera om coolify-nätverket finns
    if docker network inspect coolify >/dev/null 2>&1; then
        echo "✅ coolify-nätverket finns"
    else
        echo "❌ coolify-nätverket finns INTE"
    fi
else
    echo "❌ Kan inte kontrollera network - container finns inte"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4️⃣  PORT 7860"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if docker ps --filter "name=$CONTAINER" --format '{{.Names}}' | grep -q "$CONTAINER"; then
    if docker exec "$CONTAINER" curl -sf http://127.0.0.1:7860 >/dev/null 2>&1; then
        echo "✅ Port 7860 svarar"
    else
        echo "❌ Port 7860 svarar INTE"
        echo ""
        echo "📋 Container logs (senaste 20 raderna):"
        docker logs "$CONTAINER" --tail 20 2>/dev/null | sed 's/^/  /' || echo "  Kunde inte hämta logs"
    fi
else
    echo "❌ Container körs inte - kan inte testa port"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5️⃣  TRAEFIK STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Hitta Traefik container
TRAEFIK_CONTAINER=$(docker ps -a --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1 || echo "")

if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps -a --filter "name=coolify" --format '{{.Names}}' 2>/dev/null | grep -i proxy | head -1 || echo "")
fi

if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps -a --filter "ancestor=traefik" --format '{{.Names}}' 2>/dev/null | head -1 || echo "")
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_STATUS=$(docker ps --filter "name=$TRAEFIK_CONTAINER" --format '{{.State.Status}}' 2>/dev/null || echo "stopped")
    echo "Traefik container: $TRAEFIK_CONTAINER"
    echo "Status: $TRAEFIK_STATUS"
    
    if [ "$TRAEFIK_STATUS" = "running" ]; then
        echo "✅ Traefik körs"
        echo ""
        echo "📋 Traefik logs (senaste 20 raderna) - letar efter langflow:"
        docker logs "$TRAEFIK_CONTAINER" --tail 50 2>/dev/null | grep -i langflow | tail -10 | sed 's/^/  /' || echo "  Inga langflow-referenser i logs"
    else
        echo "❌ Traefik körs INTE"
    fi
else
    echo "❌ Traefik container hittades inte"
    echo ""
    echo "💡 Lista alla containers:"
    docker ps -a | head -10 | sed 's/^/  /'
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6️⃣  DOCKER-COMPOSE.YML"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SERVICE_DIR="/data/coolify/services/rog04sw8kcc0g848cs4cocso"

if [ -f "$SERVICE_DIR/docker-compose.yml" ]; then
    echo "✅ docker-compose.yml finns"
    echo ""
    echo "📋 Traefik labels i filen:"
    grep -A 10 "labels:" "$SERVICE_DIR/docker-compose.yml" 2>/dev/null | sed 's/^/  /' || echo "  Inga labels hittades"
    echo ""
    echo "📋 Networks i filen:"
    grep -A 5 "networks:" "$SERVICE_DIR/docker-compose.yml" 2>/dev/null | sed 's/^/  /' || echo "  Inga networks hittades"
else
    echo "❌ docker-compose.yml saknas: $SERVICE_DIR"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 SAMMANFATTNING"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Om något är fel, kör:"
echo "   ./scripts/fix-langflow-complete.sh tha"
echo ""
REMOTE

echo ""
info "Diagnostik klar!"
echo ""


