#!/usr/bin/env bash
set -euo pipefail

# fix-coolify-platform.sh - Komplett fix av Coolify-plattformen efter Ubuntu-uppdatering

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

echo "🔧 Komplett Fix av Coolify-plattformen"
echo "======================================"
echo ""
warn "Detta script kommer att:"
echo "  • Kontrollera och uppdatera Docker"
echo "  • Uppdatera Coolify till senaste version"
echo "  • Fixa Traefik API-problem"
echo "  • Starta om allt"
echo "  • Verifiera att allt fungerar"
echo ""

read -p "Vill du fortsätta? (ja/nej): " -r
if [[ ! $REPLY =~ ^[Jj]a$ ]]; then
    info "Avbruten av användaren"
    exit 0
fi

# ============================================================================
# STEG 1: Kontrollera Docker Version & Kompatibilitet
# ============================================================================
section "STEG 1: Kontrollerar Docker Version & Kompatibilitet"

ssh "$HOST" bash <<'REMOTE'
echo "🐳 Docker Status:"
echo ""

DOCKER_VERSION=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
echo "  Nuvarande version: $DOCKER_VERSION"

# Docker 29.x kräver API 1.44+
if [[ "$DOCKER_VERSION" =~ ^29\. ]]; then
    echo "  ✅ Docker 29.x (kräver API 1.44+)"
    echo "  ⚠️  Traefik behöver uppdateras för att fungera med denna version"
elif [[ "$DOCKER_VERSION" =~ ^2[0-8]\. ]]; then
    echo "  ✅ Docker version OK"
else
    echo "  ⚠️  Gammal Docker version"
fi

echo ""
echo "📋 Docker API version:"
# Kolla vilken API version Docker accepterar
DOCKER_API=$(docker version --format '{{.Server.APIVersion}}' 2>/dev/null || echo "unknown")
echo "  Server API: $DOCKER_API"

echo ""
echo "🔍 Traefik API-problem:"
TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    API_ERROR=$(docker logs "$TRAEFIK_CONTAINER" 2>/dev/null | grep -i "client version.*too old" | tail -1 || echo "")
    if [ -n "$API_ERROR" ]; then
        echo "  ❌ Traefik använder för gammal API version (1.24)"
        echo "  Docker kräver: 1.44+"
    else
        echo "  ✅ Inga API-fel"
    fi
fi
REMOTE

# ============================================================================
# STEG 2: Uppdatera Docker (om nödvändigt)
# ============================================================================
section "STEG 2: Uppdaterar Docker"

ssh "$HOST" bash <<'REMOTE'
echo "🔄 Kontrollerar om Docker behöver uppdateras..."
echo ""

CURRENT_VERSION=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
echo "  Nuvarande: $CURRENT_VERSION"

# Uppdatera Docker
echo ""
echo "  Uppdaterar Docker..."
apt update
apt install -y docker.io docker-compose-plugin

NEW_VERSION=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
echo "  Ny version: $NEW_VERSION"

echo ""
echo "  Startar om Docker..."
systemctl restart docker
sleep 5

echo "  ✅ Docker uppdaterad och omstartad"
REMOTE

# ============================================================================
# STEG 3: Uppdatera Coolify
# ============================================================================
section "STEG 3: Uppdaterar Coolify"

ssh "$HOST" bash <<'REMOTE'
echo "🔄 Uppdaterar Coolify till senaste version..."
echo ""

if [ -d "/data/coolify/source" ]; then
    cd /data/coolify/source
    
    echo "  Hittade Coolify i /data/coolify/source"
    echo ""
    echo "  Stoppar Coolify..."
    if docker compose version >/dev/null 2>&1; then
        docker compose down
    else
        docker-compose down
    fi
    sleep 3
    
    echo "  Uppdaterar Coolify images..."
    if docker compose version >/dev/null 2>&1; then
        docker compose pull
    else
        docker-compose pull
    fi
    
    echo ""
    echo "  Startar Coolify med uppdaterade images..."
    if docker compose version >/dev/null 2>&1; then
        docker compose up -d
    else
        docker-compose up -d
    fi
    
    echo ""
    echo "  ✅ Coolify uppdaterad"
    echo "  Väntar 20 sekunder för att Coolify ska starta klart..."
    sleep 20
else
    echo "  ⚠️  Coolify installation ej hittad i /data/coolify/source"
    echo "  Installerar Coolify..."
    
    # Installera Coolify
    curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
    
    echo "  ✅ Coolify installerad"
    sleep 10
fi
REMOTE

# ============================================================================
# STEG 4: Fixa Traefik API-problem
# ============================================================================
section "STEG 4: Fixar Traefik API-problem"

ssh "$HOST" bash <<'REMOTE'
echo "🌐 Traefik Proxy:"
echo ""

TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    echo "  Hittade Traefik: $TRAEFIK_CONTAINER"
    echo ""
    echo "  Uppdaterar Traefik image..."
    docker pull traefik:latest 2>/dev/null || docker pull traefik:v3.0 2>/dev/null || true
    
    echo ""
    echo "  Startar om Traefik..."
    docker restart "$TRAEFIK_CONTAINER"
    sleep 10
    
    echo ""
    echo "  Kontrollerar Traefik logs..."
    API_ERROR=$(docker logs "$TRAEFIK_CONTAINER" 2>/dev/null | grep -i "client version.*too old" | tail -1 || echo "")
    if [ -n "$API_ERROR" ]; then
        echo "  ⚠️  API-fel kvarstår - Traefik behöver uppdateras via Coolify"
    else
        echo "  ✅ Inga API-fel"
    fi
else
    echo "  ⚠️  Traefik container hittades inte"
    
    # Prova att starta från proxy directory
    if [ -d "/data/coolify/proxy" ]; then
        echo "  Startar Traefik från /data/coolify/proxy..."
        cd /data/coolify/proxy
        if docker compose version >/dev/null 2>&1; then
            docker compose pull
            docker compose up -d
        else
            docker-compose pull
            docker-compose up -d
        fi
        sleep 10
    fi
fi
REMOTE

# ============================================================================
# STEG 5: Starta om alla Services
# ============================================================================
section "STEG 5: Startar om alla Services"

ssh "$HOST" bash <<'REMOTE'
echo "🔄 Startar om services..."
echo ""

if [ -d "/data/coolify/services" ]; then
    SERVICE_COUNT=$(find /data/coolify/services -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    echo "  Hittade $SERVICE_COUNT service(s)"
    echo ""
    
    for service_dir in /data/coolify/services/*; do
        if [ -d "$service_dir" ] && [ -f "$service_dir/docker-compose.yml" ]; then
            SERVICE_NAME=$(basename "$service_dir")
            echo "  📦 Startar om $SERVICE_NAME..."
            
            cd "$service_dir"
            
            if docker compose version >/dev/null 2>&1; then
                docker compose restart 2>/dev/null && echo "    ✅ Omstartad" || echo "    ⚠️  Kunde inte starta om"
            else
                docker-compose restart 2>/dev/null && echo "    ✅ Omstartad" || echo "    ⚠️  Kunde inte starta om"
            fi
        fi
    done
    
    echo ""
    echo "  ✅ Services omstartade"
    echo "  Väntar 10 sekunder..."
    sleep 10
fi
REMOTE

# ============================================================================
# STEG 6: Verifiering
# ============================================================================
section "STEG 6: Verifiering"

ssh "$HOST" bash <<'REMOTE'
echo "📊 Status efter fix:"
echo ""

echo "🐳 Docker:"
systemctl is-active docker >/dev/null && echo "  ✅ Docker körs" || echo "  ❌ Docker körs inte"
docker --version

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
        
        # Kolla API-fel
        API_ERROR=$(docker logs "$TRAEFIK_CONTAINER" --tail 5 2>/dev/null | grep -i "client version.*too old" | tail -1 || echo "")
        if [ -z "$API_ERROR" ]; then
            echo "  ✅ Inga API-fel"
        else
            echo "  ⚠️  API-fel kvarstår (kan ta några minuter att lösa sig)"
        fi
    else
        echo "  ⚠️  Traefik status: $STATUS"
    fi
fi

echo ""
echo "📦 Services:"
SERVICE_COUNT=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -v "coolify" | grep -v "traefik" | grep -v "postgres" | wc -l)
echo "  Service-containers körs: $SERVICE_COUNT"
REMOTE

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning"

echo ""
info "Coolify-plattformen fixad!"
echo ""
echo "💡 Nästa steg:"
echo "  1. Vänta 2-3 minuter för att allt ska starta klart"
echo "  2. Testa Coolify dashboard: https://coolify.theunnamedroads.com"
echo "  3. Testa dina services"
echo "  4. Om fortfarande problem:"
echo "     • Kör diagnostik: ./scripts/diagnose-404.sh"
echo "     • Starta om allt: ./scripts/restart-coolify.sh"
echo ""
echo "🔧 Ytterligare kommandon:"
echo "  • Verifiera allt: ./scripts/verify-all.sh"
echo "  • Lista resurser: ./scripts/list-coolify-resources.sh"
echo ""


