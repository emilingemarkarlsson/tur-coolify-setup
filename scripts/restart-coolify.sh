#!/usr/bin/env bash
set -euo pipefail

# restart-coolify.sh - Startar om Coolify och alla services

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

echo "🔄 Startar om Coolify och alla Services"
echo "========================================"

# ============================================================================
# STEG 1: Verifiera SSH
# ============================================================================
section "1️⃣  Verifierar anslutning"

if ! ssh -o ConnectTimeout=5 "$HOST" 'echo "SSH OK"' &>/dev/null; then
    error "SSH-anslutning misslyckades"
    exit 1
fi

info "SSH-anslutning fungerar ✓"
echo ""

# ============================================================================
# STEG 2: Starta om Docker
# ============================================================================
section "2️⃣  Startar om Docker"

ssh "$HOST" bash <<'REMOTE'
echo "🔄 Startar om Docker-tjänsten..."
echo "  (Detta stoppar alla containers tillfälligt)"
systemctl restart docker
sleep 3

echo ""
echo "✅ Docker omstartad"
echo "  Väntar 5 sekunder för att Docker ska starta klart..."
sleep 5

echo ""
echo "Docker-status:"
systemctl is-active docker >/dev/null && echo "  ✅ Docker körs" || echo "  ❌ Docker körs inte"
REMOTE

echo ""

# ============================================================================
# STEG 3: Starta om Coolify
# ============================================================================
section "3️⃣  Startar om Coolify"

ssh "$HOST" bash <<'REMOTE'
if [ -d "/data/coolify/source" ]; then
    echo "Coolify installation hittad i /data/coolify/source"
    cd /data/coolify/source
    
    echo ""
    echo "🔄 Startar om Coolify..."
    
    # Starta om Coolify med docker compose
    if docker compose version >/dev/null 2>&1; then
        echo "  Stoppar Coolify..."
        docker compose down
        sleep 2
        echo "  Startar Coolify..."
        docker compose up -d
    elif command -v docker-compose >/dev/null 2>&1; then
        echo "  Stoppar Coolify..."
        docker-compose down
        sleep 2
        echo "  Startar Coolify..."
        docker-compose up -d
    else
        echo "⚠️  Docker Compose ej tillgängligt, försöker starta containers manuellt..."
        docker ps -a --filter "name=coolify" --format '{{.Names}}' | xargs -r docker start
    fi
    
    echo ""
    echo "✅ Coolify omstartad"
    echo "  Väntar 15 sekunder för att Coolify ska starta klart..."
    sleep 15
    
    echo ""
    echo "Coolify containers status:"
    if docker compose version >/dev/null 2>&1; then
        docker compose ps 2>/dev/null || docker ps --filter "name=coolify" --format "table {{.Names}}\t{{.Status}}"
    else
        docker-compose ps 2>/dev/null || docker ps --filter "name=coolify" --format "table {{.Names}}\t{{.Status}}"
    fi
else
    echo "⚠️  Coolify installation ej hittad i /data/coolify/source"
    echo "  Söker efter Coolify..."
    
    # Prova andra vanliga platser
    if [ -d "/opt/coolify" ]; then
        echo "  Hittade i /opt/coolify"
        cd /opt/coolify
        docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true
        sleep 2
        docker compose up -d 2>/dev/null || docker-compose up -d 2>/dev/null || true
    else
        echo "  ❌ Coolify installation ej hittad"
    fi
fi
REMOTE

echo ""

# ============================================================================
# STEG 4: Starta om Traefik Proxy
# ============================================================================
section "4️⃣  Startar om Traefik Proxy"

ssh "$HOST" bash <<'REMOTE'
echo "🌐 Traefik Proxy:"

if [ -d "/data/coolify/proxy" ]; then
    echo "  Hittade proxy i /data/coolify/proxy"
    cd /data/coolify/proxy
    
    echo "  🔄 Startar om Traefik..."
    if docker compose version >/dev/null 2>&1; then
        docker compose restart 2>/dev/null || docker compose up -d 2>/dev/null
    else
        docker-compose restart 2>/dev/null || docker-compose up -d 2>/dev/null
    fi
    echo "  ✅ Traefik omstartad"
else
    echo "  ⚠️  Proxy directory ej hittad, försöker hitta Traefik container..."
    
    TRAEFIK_CONTAINER=$(docker ps -a --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
    if [ -z "$TRAEFIK_CONTAINER" ]; then
        TRAEFIK_CONTAINER=$(docker ps -a --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
    fi
    
    if [ -n "$TRAEFIK_CONTAINER" ]; then
        echo "  Hittade: $TRAEFIK_CONTAINER"
        docker restart "$TRAEFIK_CONTAINER" 2>/dev/null && echo "  ✅ Traefik omstartad" || echo "  ⚠️  Kunde inte starta om"
    else
        echo "  ⚠️  Traefik container ej hittad"
    fi
fi

sleep 5
REMOTE

echo ""

# ============================================================================
# STEG 5: Starta om alla Services
# ============================================================================
section "5️⃣  Startar om alla Services"

ssh "$HOST" bash <<'REMOTE'
echo "🔄 Startar om services i Coolify..."
echo ""

if [ -d "/data/coolify/services" ]; then
    SERVICE_COUNT=$(find /data/coolify/services -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    echo "Hittade $SERVICE_COUNT service(s)"
    echo ""
    
    for service_dir in /data/coolify/services/*; do
        if [ -d "$service_dir" ] && [ -f "$service_dir/docker-compose.yml" ]; then
            SERVICE_NAME=$(basename "$service_dir")
            echo "📦 Startar om $SERVICE_NAME..."
            
            cd "$service_dir"
            
            # Starta om service
            if docker compose version >/dev/null 2>&1; then
                docker compose restart 2>/dev/null && echo "  ✅ $SERVICE_NAME omstartad" || echo "  ⚠️  Kunde inte starta om $SERVICE_NAME"
            elif command -v docker-compose >/dev/null 2>&1; then
                docker-compose restart 2>/dev/null && echo "  ✅ $SERVICE_NAME omstartad" || echo "  ⚠️  Kunde inte starta om $SERVICE_NAME"
            else
                # Fallback: starta containers manuellt
                CONTAINER_NAMES=$(grep -E "container_name:" "$service_dir/docker-compose.yml" | sed 's/.*container_name:[[:space:]]*//' | tr -d '"' || true)
                if [ -n "$CONTAINER_NAMES" ]; then
                    echo "$CONTAINER_NAMES" | while read -r container; do
                        docker restart "$container" 2>/dev/null && echo "  ✅ $container omstartad" || echo "  ⚠️  Kunde inte starta om $container"
                    done
                fi
            fi
        fi
    done
    
    echo ""
    echo "✅ Services omstartade"
    echo "  Väntar 10 sekunder för att services ska starta klart..."
    sleep 10
else
    echo "⚠️  /data/coolify/services/ katalog finns inte"
    echo "  Hoppar över service-omstart"
fi
REMOTE

echo ""

# ============================================================================
# STEG 6: Verifiering
# ============================================================================
section "6️⃣  Verifiering"

ssh "$HOST" bash <<'REMOTE'
echo "📊 Status efter omstart:"
echo ""

echo "🐳 Docker:"
systemctl is-active docker >/dev/null && echo "  ✅ Docker körs" || echo "  ❌ Docker körs inte"

echo ""
echo "🔧 Coolify:"
COOLIFY_CONTAINERS=$(docker ps --filter "name=coolify" --format '{{.Names}}' 2>/dev/null | wc -l)
echo "  Coolify-containers körs: $COOLIFY_CONTAINERS"

echo ""
echo "🌐 Traefik:"
TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi
if [ -n "$TRAEFIK_CONTAINER" ]; then
    STATUS=$(docker inspect --format='{{.State.Status}}' "$TRAEFIK_CONTAINER" 2>/dev/null || echo "unknown")
    if [ "$STATUS" = "running" ]; then
        echo "  ✅ Traefik körs: $TRAEFIK_CONTAINER"
    else
        echo "  ⚠️  Traefik status: $STATUS"
    fi
else
    echo "  ⚠️  Traefik hittades inte"
fi

echo ""
echo "📦 Services:"
SERVICE_COUNT=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -v "coolify" | grep -v "traefik" | grep -v "postgres" | wc -l)
echo "  Service-containers körs: $SERVICE_COUNT"

echo ""
echo "📋 Alla containers:"
docker ps --format "  • {{.Names}} ({{.Status}})" 2>/dev/null | head -15
REMOTE

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning"

echo ""
info "Coolify och services omstartade!"
echo ""
echo "💡 Nästa steg:"
echo "  1. Vänta 1-2 minuter för att allt ska starta klart"
echo "  2. Testa Coolify dashboard: https://coolify.theunnamedroads.com"
echo "  3. Testa dina services"
echo "  4. Om fortfarande problem:"
echo "     • 404-fel: ./scripts/fix-404.sh"
echo "     • Services körs inte: ./scripts/fix-services.sh"
echo "     • Verifiera allt: ./scripts/verify-all.sh"
echo ""
echo "🔧 Ytterligare kommandon:"
echo "  • Lista resurser: ./scripts/list-coolify-resources.sh"
echo "  • Testa endpoints: ./scripts/diagnose.sh"
echo "  • SSH direkt: ssh $HOST"
echo ""


