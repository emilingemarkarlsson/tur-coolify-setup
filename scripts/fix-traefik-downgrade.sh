#!/usr/bin/env bash
set -euo pipefail

# fix-traefik-downgrade.sh - Återställer Traefik till fungerande version

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

echo "🔧 Återställer Traefik till fungerande version"
echo "=============================================="

# ============================================================================
# STEG 1: Kontrollera Traefik Status
# ============================================================================
section "STEG 1: Kontrollerar Traefik Status"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Traefik Status:"
echo ""

TRAEFIK_CONTAINER=$(docker ps -a --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps -a --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    STATUS=$(docker inspect --format='{{.State.Status}}' "$TRAEFIK_CONTAINER" 2>/dev/null || echo "unknown")
    IMAGE=$(docker inspect --format='{{.Config.Image}}' "$TRAEFIK_CONTAINER" 2>/dev/null || echo "unknown")
    
    echo "  Container: $TRAEFIK_CONTAINER"
    echo "  Status: $STATUS"
    echo "  Image: $IMAGE"
    
    if [ "$STATUS" != "running" ]; then
        echo ""
        echo "  ⚠️  Traefik körs inte - detta orsakar att Coolify inte når!"
    fi
else
    echo "  ❌ Traefik container hittades inte!"
fi
REMOTE

# ============================================================================
# STEG 2: Återställ Traefik via Proxy Directory
# ============================================================================
section "STEG 2: Återställer Traefik till v3.0.4 (fungerande version)"

ssh "$HOST" bash <<'REMOTE'
echo "🔄 Återställer Traefik..."
echo ""

if [ -d "/data/coolify/proxy" ]; then
    cd /data/coolify/proxy
    
    if [ -f "docker-compose.yml" ]; then
        echo "  ✅ docker-compose.yml finns"
        
        # Backup
        cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d-%H%M%S)
        
        # Återställ till v3.0.4 (fungerande version)
        echo "  🔄 Återställer till traefik:v3.0.4..."
        sed -i 's|image:.*traefik.*|image: traefik:v3.0.4|g' docker-compose.yml
        
        # Säkerställ Docker socket mount
        if ! grep -q "/var/run/docker.sock" docker-compose.yml; then
            echo "  🔄 Lägger till Docker socket mount..."
            if grep -q "traefik:" docker-compose.yml; then
                # Lägg till volumes efter traefik service
                sed -i '/traefik:/a\    volumes:\n      - /var/run/docker.sock:/var/run/docker.sock:ro' docker-compose.yml
            fi
        fi
        
        echo ""
        echo "  🔄 Startar om Traefik med v3.0.4..."
        if docker compose version >/dev/null 2>&1; then
            docker compose pull traefik:v3.0.4 2>/dev/null || true
            docker compose down
            sleep 3
            docker compose up -d
        else
            docker-compose pull traefik:v3.0.4 2>/dev/null || true
            docker-compose down
            sleep 3
            docker-compose up -d
        fi
        
        echo "  ✅ Traefik återställd till v3.0.4"
        echo "  Väntar 20 sekunder för att Traefik ska starta klart..."
        sleep 20
    else
        echo "  ⚠️  docker-compose.yml saknas"
    fi
else
    echo "  ⚠️  /data/coolify/proxy directory saknas"
    
    # Prova att starta Traefik direkt
    echo ""
    echo "  Försöker starta Traefik direkt..."
    TRAEFIK_CONTAINER=$(docker ps -a --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
    if [ -z "$TRAEFIK_CONTAINER" ]; then
        TRAEFIK_CONTAINER=$(docker ps -a --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
    fi
    
    if [ -n "$TRAEFIK_CONTAINER" ]; then
        echo "  Stoppar $TRAEFIK_CONTAINER..."
        docker stop "$TRAEFIK_CONTAINER" 2>/dev/null || true
        
        echo "  Startar med v3.0.4..."
        # Hämta konfiguration från container
        docker start "$TRAEFIK_CONTAINER" 2>/dev/null || echo "  ⚠️  Kunde inte starta"
    fi
fi
REMOTE

# ============================================================================
# STEG 3: Verifiera Traefik
# ============================================================================
section "STEG 3: Verifierar Traefik"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Kontrollerar Traefik efter återställning..."
echo ""

TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    STATUS=$(docker inspect --format='{{.State.Status}}' "$TRAEFIK_CONTAINER" 2>/dev/null || echo "unknown")
    IMAGE=$(docker inspect --format='{{.Config.Image}}' "$TRAEFIK_CONTAINER" 2>/dev/null || echo "unknown")
    
    echo "  Container: $TRAEFIK_CONTAINER"
    echo "  Status: $STATUS"
    echo "  Image: $IMAGE"
    
    if [ "$STATUS" = "running" ]; then
        echo "  ✅ Traefik körs"
        
        echo ""
        echo "  📋 Senaste logs:"
        docker logs "$TRAEFIK_CONTAINER" --tail 10 2>/dev/null | tail -10
        
        echo ""
        echo "  🔍 API-fel:"
        API_ERROR=$(docker logs "$TRAEFIK_CONTAINER" --tail 10 2>/dev/null | grep -i "client version.*too old" | tail -1 || echo "")
        if [ -z "$API_ERROR" ]; then
            echo "    ✅ Inga API-fel"
        else
            echo "    ⚠️  API-fel kvarstår"
        fi
    else
        echo "  ❌ Traefik körs inte"
    fi
else
    echo "  ❌ Traefik container hittades inte"
fi
REMOTE

# ============================================================================
# STEG 4: Testa Coolify Dashboard
# ============================================================================
section "STEG 4: Testar Coolify Dashboard"

echo "🔍 Testar Coolify dashboard..."
echo ""

COOLIFY_URL="https://coolify.theunnamedroads.com"
HTTP_CODE=$(curl -I -s --max-time 10 "$COOLIFY_URL" 2>/dev/null | head -1 | awk '{print $2}' || echo "000")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
    info "Coolify dashboard nåbar ($HTTP_CODE)"
else
    warn "Coolify dashboard når inte ($HTTP_CODE)"
    echo "  Vänta 1-2 minuter och testa igen"
fi

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning"

echo ""
info "Traefik återställd till v3.0.4!"
echo ""
echo "💡 Nästa steg:"
echo ""
echo "1. Vänta 1-2 minuter för att Traefik ska starta klart"
echo "2. Testa Coolify dashboard: https://coolify.theunnamedroads.com"
echo "3. Om Coolify fortfarande inte når:"
echo "   • Vänta 2-3 minuter till"
echo "   • Kontrollera: ssh tha 'docker ps | grep traefik'"
echo "   • Starta om Traefik: ssh tha 'cd /data/coolify/proxy && docker compose restart'"
echo ""
echo "⚠️  VIKTIGT: Uppdatera INTE Traefik till v3.6 i Coolify Dashboard ännu!"
echo "   Vänta tills allt fungerar stabilt först."
echo ""
echo "🔧 Ytterligare kommandon:"
echo "  • Diagnostik: ./scripts/diagnose-404.sh"
echo "  • Verifiera: ./scripts/verify-all.sh"
echo ""


