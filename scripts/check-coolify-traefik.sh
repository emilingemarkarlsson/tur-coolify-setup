#!/usr/bin/env bash
set -euo pipefail

# check-coolify-traefik.sh - Kontrollerar Traefik labels på Coolify-containers

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

echo "🔍 Kontrollerar Traefik Labels på Coolify"
echo "=========================================="
echo ""

ssh "$HOST" bash <<'REMOTE'
# Hitta alla Coolify-containers
echo "📦 Coolify-containers:"
docker ps --filter "name=coolify" --format "  • {{.Names}}" 2>/dev/null | grep -v "proxy" | grep -v "db"
echo ""

# Kontrollera varje container
for container in $(docker ps --filter "name=coolify" --format '{{.Names}}' 2>/dev/null | grep -v "proxy" | grep -v "db" | grep -v "realtime" | grep -v "redis"); do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 $container:"
    echo ""
    
    # Traefik enable
    TRAEFIK_ENABLED=$(docker inspect "$container" --format '{{index .Config.Labels "traefik.enable"}}' 2>/dev/null || echo "")
    if [ "$TRAEFIK_ENABLED" = "true" ]; then
        echo "  ✅ traefik.enable=true"
    else
        echo "  ❌ traefik.enable saknas eller är false"
    fi
    
    # Alla Traefik labels
    echo ""
    echo "  📋 Alla Traefik labels:"
    TRAEFIK_LABELS=$(docker inspect "$container" --format '{{range $k, $v := .Config.Labels}}{{if match $k "traefik.*"}}{{$k}}={{$v}}{{println}}{{end}}{{end}}' 2>/dev/null)
    
    if [ -n "$TRAEFIK_LABELS" ]; then
        echo "$TRAEFIK_LABELS" | while IFS='=' read -r key value; do
            if [ -n "$key" ]; then
                echo "    • $key = $value"
            fi
        done
    else
        echo "    ⚠️  Inga Traefik labels"
    fi
    
    # Network
    echo ""
    echo "  🌐 Networks:"
    docker inspect "$container" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null | tr ' ' '\n' | grep -v '^$' | while read -r network; do
        if [ -n "$network" ]; then
            echo "    • $network"
        fi
    done
    
    echo ""
done
REMOTE

echo ""
echo "💡 Om Coolify saknar Traefik labels:"
echo "   1. Gå till Coolify dashboard (via IP om möjligt)"
echo "   2. Settings → Server → Proxy"
echo "   3. Kontrollera att 'Domain' är konfigurerad: coolify.theunnamedroads.com"
echo "   4. Klicka 'Redeploy' på Coolify"
echo ""


