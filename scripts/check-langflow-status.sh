#!/usr/bin/env bash
set -euo pipefail

# check-langflow-status.sh - Kontrollerar Langflow status

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

echo "🔍 Kontrollerar Langflow Status"
echo "================================"
echo ""

ssh "$HOST" bash <<'REMOTE'
CONTAINER="langflow-rog04sw8kcc0g848cs4cocso"

# Container status
echo "📦 Container Status:"
STATUS=$(docker ps --filter "name=$CONTAINER" --format '{{.State.Status}}' 2>/dev/null || echo "not_found")
if [ "$STATUS" = "running" ]; then
    echo "  ✅ Container körs"
else
    echo "  ❌ Container status: $STATUS"
fi
echo ""

# Traefik labels
echo "🏷️  Traefik Labels:"
TRAEFIK_ENABLED=$(docker inspect "$CONTAINER" --format '{{index .Config.Labels "traefik.enable"}}' 2>/dev/null || echo "")
if [ "$TRAEFIK_ENABLED" = "true" ]; then
    echo "  ✅ traefik.enable=true"
    
    RULE=$(docker inspect "$CONTAINER" --format '{{index .Config.Labels "traefik.http.routers.langflow.rule"}}' 2>/dev/null || echo "")
    if [ -n "$RULE" ]; then
        echo "  ✅ Router rule: $RULE"
    else
        echo "  ⚠️  Router rule saknas"
    fi
    
    PORT=$(docker inspect "$CONTAINER" --format '{{index .Config.Labels "traefik.http.services.langflow.loadbalancer.server.port"}}' 2>/dev/null || echo "")
    if [ -n "$PORT" ]; then
        echo "  ✅ Port: $PORT"
    else
        echo "  ⚠️  Port saknas"
    fi
else
    echo "  ❌ Traefik labels saknas!"
fi
echo ""

# Network
echo "🌐 Network:"
NETWORKS=$(docker inspect "$CONTAINER" --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}' 2>/dev/null || echo "")
if echo "$NETWORKS" | grep -q "coolify"; then
    echo "  ✅ Ansluten till coolify-nätverket"
else
    echo "  ⚠️  Inte ansluten till coolify-nätverket"
    echo "  Networks: $NETWORKS"
fi
echo ""

# Port check
echo "🔌 Port 7860:"
if docker exec "$CONTAINER" curl -sf http://127.0.0.1:7860 >/dev/null 2>&1; then
    echo "  ✅ Port 7860 svarar"
else
    echo "  ⚠️  Port 7860 svarar inte"
    echo "  📋 Senaste logs:"
    docker logs "$CONTAINER" --tail 10 2>/dev/null | sed 's/^/    /'
fi
echo ""

# Traefik status
echo "🚦 Traefik:"
TRAEFIK_STATUS=$(docker ps --filter "name=traefik" --format '{{.State.Status}}' 2>/dev/null || echo "not_found")
if [ "$TRAEFIK_STATUS" = "running" ]; then
    echo "  ✅ Traefik körs"
else
    echo "  ❌ Traefik status: $TRAEFIK_STATUS"
fi
REMOTE

echo ""
echo "💡 Om Traefik labels saknas, kör:"
echo "   ./scripts/fix-langflow-404.sh tha"
echo ""


