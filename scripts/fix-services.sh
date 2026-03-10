#!/usr/bin/env bash
set -euo pipefail

# fix-services.sh - Felsöker och fixar services som inte fungerar efter serveruppdatering

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

echo "🔧 Felsökning: Services inte tillgängliga"
echo "=========================================="

# ============================================================================
# STEG 1: Kontrollera Docker Status
# ============================================================================
section "1️⃣  Docker Status"

ssh "$HOST" bash <<'REMOTE'
echo "🐳 Docker-tjänst:"
if systemctl is-active docker >/dev/null 2>&1; then
    echo "  ✅ Docker körs"
else
    echo "  ❌ Docker körs INTE - startar..."
    systemctl start docker
    sleep 2
    systemctl is-active docker >/dev/null && echo "  ✅ Docker startad" || echo "  ❌ Kunde inte starta Docker"
fi

echo ""
echo "📦 Container Status:"
RUNNING=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)
STOPPED=$(docker ps -a --filter "status=exited" --format '{{.Names}}' 2>/dev/null | wc -l)
echo "  Körs: $RUNNING"
echo "  Stoppade: $STOPPED"
REMOTE

# ============================================================================
# STEG 2: Identifiera Stoppade Services
# ============================================================================
section "2️⃣  Stoppade Services"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Söker efter stoppade containers (utom Coolify core):"
echo ""

STOPPED_CONTAINERS=$(docker ps -a --filter "status=exited" --format '{{.Names}}' 2>/dev/null | grep -v "coolify" | grep -v "traefik" | grep -v "postgres" || true)

if [ -n "$STOPPED_CONTAINERS" ]; then
    echo "⚠️  Stoppade service-containers:"
    while IFS= read -r container; do
        if [ -n "$container" ]; then
            echo "  • $container"
        fi
    done <<< "$STOPPED_CONTAINERS"
else
    echo "✅ Inga stoppade service-containers hittades"
fi
REMOTE

# ============================================================================
# STEG 3: Kontrollera Traefik (Proxy)
# ============================================================================
section "3️⃣  Traefik Proxy Status"

ssh "$HOST" bash <<'REMOTE'
echo "🌐 Traefik (Coolify Proxy):"
echo ""

TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)

if [ -n "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_STATUS=$(docker inspect --format='{{.State.Status}}' "$TRAEFIK_CONTAINER" 2>/dev/null || echo "unknown")
    if [ "$TRAEFIK_STATUS" = "running" ]; then
        echo "  ✅ Traefik körs: $TRAEFIK_CONTAINER"
    else
        echo "  ⚠️  Traefik status: $TRAEFIK_STATUS"
    fi
else
    echo "  ⚠️  Traefik container hittades inte"
    echo "  Söker efter coolify-proxy..."
    PROXY_CONTAINER=$(docker ps -a --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
    if [ -n "$PROXY_CONTAINER" ]; then
        echo "  Hittade: $PROXY_CONTAINER"
        PROXY_STATUS=$(docker inspect --format='{{.State.Status}}' "$PROXY_CONTAINER" 2>/dev/null || echo "unknown")
        echo "  Status: $PROXY_STATUS"
    fi
fi
REMOTE

# ============================================================================
# STEG 4: Kontrollera Coolify Network
# ============================================================================
section "4️⃣  Docker Networks"

ssh "$HOST" bash <<'REMOTE'
echo "🌐 Docker Networks:"
echo ""

COOLIFY_NETWORK=$(docker network ls --filter "name=coolify" --format '{{.Name}}' 2>/dev/null | head -1)

if [ -n "$COOLIFY_NETWORK" ]; then
    echo "  ✅ Coolify network finns: $COOLIFY_NETWORK"
else
    echo "  ⚠️  Coolify network saknas!"
    echo "  Detta kan orsaka att services inte kan nås"
fi

echo ""
echo "Alla networks:"
docker network ls 2>/dev/null | head -10
REMOTE

# ============================================================================
# STEG 5: Försök Starta Om Stoppade Services
# ============================================================================
section "5️⃣  Starta Om Services"

echo "🔄 Försöker starta om stoppade services..."
echo ""

ssh "$HOST" bash <<'REMOTE'
# Hitta alla stoppade service-containers
STOPPED=$(docker ps -a --filter "status=exited" --format '{{.Names}}' 2>/dev/null | grep -v "coolify" | grep -v "traefik" | grep -v "postgres" || true)

if [ -n "$STOPPED" ]; then
    echo "Startar om stoppade containers:"
    while IFS= read -r container; do
        if [ -n "$container" ]; then
            echo "  • Startar $container..."
            docker start "$container" 2>/dev/null && echo "    ✅ Startad" || echo "    ❌ Kunde inte starta"
        fi
    done <<< "$STOPPED"
else
    echo "✅ Inga stoppade containers att starta"
fi
REMOTE

# ============================================================================
# STEG 6: Starta Om via Coolify Services Directory
# ============================================================================
section "6️⃣  Starta Om via Coolify Services"

ssh "$HOST" bash <<'REMOTE'
echo "🔧 Startar om services via Coolify services directory..."
echo ""

if [ -d "/data/coolify/services" ]; then
    SERVICE_COUNT=$(find /data/coolify/services -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    echo "Hittade $SERVICE_COUNT service(s)"
    echo ""
    
    for service_dir in /data/coolify/services/*; do
        if [ -d "$service_dir" ] && [ -f "$service_dir/docker-compose.yml" ]; then
            SERVICE_NAME=$(basename "$service_dir")
            echo "📦 $SERVICE_NAME:"
            
            cd "$service_dir"
            
            # Försök starta om med docker compose
            if docker compose ps 2>/dev/null | grep -q "Exit"; then
                echo "  ⚠️  Några containers är stoppade - startar om..."
                docker compose up -d 2>/dev/null && echo "  ✅ Startad" || echo "  ❌ Kunde inte starta"
            else
                echo "  ✅ Alla containers körs"
            fi
        fi
    done
else
    echo "⚠️  /data/coolify/services/ katalog finns inte"
fi
REMOTE

# ============================================================================
# STEG 7: Verifiera Efter Fix
# ============================================================================
section "7️⃣  Verifiering Efter Fix"

ssh "$HOST" bash <<'REMOTE'
echo "📊 Status efter fix:"
echo ""

RUNNING=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)
STOPPED=$(docker ps -a --filter "status=exited" --format '{{.Names}}' 2>/dev/null | wc -l)

echo "  Containers körs: $RUNNING"
echo "  Containers stoppade: $STOPPED"

echo ""
echo "📋 Service-containers (utom Coolify core):"
SERVICE_CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -v "coolify" | grep -v "traefik" | grep -v "postgres" || true)

if [ -n "$SERVICE_CONTAINERS" ]; then
    while IFS= read -r container; do
        if [ -n "$container" ]; then
            STATUS=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
            if [ "$STATUS" = "running" ]; then
                echo "  ✅ $container"
            else
                echo "  ⚠️  $container (Status: $STATUS)"
            fi
        fi
    done <<< "$SERVICE_CONTAINERS"
else
    echo "  ℹ️  Inga service-containers hittades"
fi
REMOTE

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning"

echo ""
info "Felsökning klar!"
echo ""
echo "💡 Nästa steg:"
echo "  1. Vänta 1-2 minuter för att services ska starta"
echo "  2. Testa att öppna services igen"
echo "  3. Om fortfarande problem, kör: ./scripts/list-coolify-resources.sh"
echo "  4. Kolla logs: ssh $HOST 'docker logs <container-name>'"
echo ""
echo "🔧 Ytterligare felsökning:"
echo "  • Lista alla resurser: ./scripts/list-coolify-resources.sh"
echo "  • Kolla Traefik logs: ssh $HOST 'docker logs coolify-proxy'"
echo "  • Kolla service logs: ssh $HOST 'docker logs <container-name>'"
echo ""


