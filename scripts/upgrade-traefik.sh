#!/usr/bin/env bash
set -euo pipefail

# upgrade-traefik.sh - Uppgraderar Traefik till version som stödjer Docker API 1.44+

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

echo "⬆️  Uppgraderar Traefik till v3.6.1 (Coolify's Rekommendation)"
echo "================================================================"
echo ""
warn "Enligt Coolify's officiella dokumentation:"
echo "  • Docker 29.x kräver Traefik v3.6.1+ eller v2.11.31+"
echo "  • Coolify rekommenderar specifikt v3.6.1"
echo ""

# ============================================================================
# STEG 1: Kontrollera nuvarande Traefik
# ============================================================================
section "STEG 1: Kontrollerar nuvarande Traefik"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Nuvarande Traefik:"
echo ""

TRAEFIK_CONTAINER=$(docker ps -a --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps -a --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    CURRENT_IMAGE=$(docker inspect "$TRAEFIK_CONTAINER" --format '{{.Config.Image}}' 2>/dev/null || echo "unknown")
    STATUS=$(docker inspect --format='{{.State.Status}}' "$TRAEFIK_CONTAINER" 2>/dev/null || echo "unknown")
    
    echo "  Container: $TRAEFIK_CONTAINER"
    echo "  Status: $STATUS"
    echo "  Nuvarande image: $CURRENT_IMAGE"
    
    echo ""
    echo "  📋 API-fel:"
    API_ERROR=$(docker logs "$TRAEFIK_CONTAINER" 2>/dev/null | grep -i "client version.*too old" | tail -1 || echo "")
    if [ -n "$API_ERROR" ]; then
        echo "    ❌ API-fel: Traefik använder för gammal Docker API (1.24)"
        echo "    Docker kräver: 1.44+"
    else
        echo "    ✅ Inga API-fel"
    fi
else
    echo "  ❌ Traefik container hittades inte"
fi
REMOTE

# ============================================================================
# STEG 2: Uppgradera Traefik via Proxy Directory
# ============================================================================
section "STEG 2: Uppgraderar Traefik till v3.6.1 (Coolify's Rekommendation)"

ssh "$HOST" bash <<'REMOTE'
echo "🔄 Uppgraderar Traefik..."
echo ""

if [ -d "/data/coolify/proxy" ]; then
    cd /data/coolify/proxy
    
    if [ -f "docker-compose.yml" ]; then
        echo "  ✅ docker-compose.yml finns"
        
        # Backup
        cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d-%H%M%S)
        echo "  💾 Backup skapad"
        
        # Uppdatera till Traefik v3.6.1 (Coolify's rekommendation för Docker 29.x)
        echo ""
        echo "  🔄 Uppdaterar image till traefik:v3.6.1 (Coolify's rekommendation)..."
        
        # Ersätt image-tag
        if grep -q "image:" docker-compose.yml; then
            # Ersätt alla traefik image-referenser
            sed -i 's|image:.*traefik.*|image: traefik:v3.6.1|g' docker-compose.yml
            echo "  ✅ Image uppdaterad till traefik:v3.6.1"
        else
            # Lägg till image om den saknas
            if grep -q "traefik:" docker-compose.yml; then
                sed -i '/traefik:/a\    image: traefik:v3.0' docker-compose.yml
                echo "  ✅ Image tillagd: traefik:v3.0"
            fi
        fi
        
        # Säkerställ Docker socket mount
        echo ""
        echo "  🔍 Kontrollerar Docker socket mount..."
        if ! grep -q "/var/run/docker.sock" docker-compose.yml; then
            echo "  ⚠️  Docker socket mount saknas - lägger till..."
            
            # Lägg till volumes section om den saknas
            if ! grep -q "^volumes:" docker-compose.yml; then
                # Lägg till efter services:
                sed -i '/^services:/a\volumes:\n  docker.sock:\n    external: false' docker-compose.yml
            fi
            
            # Lägg till socket mount i traefik service
            if grep -q "traefik:" docker-compose.yml; then
                # Kolla om volumes redan finns i traefik service
                if ! grep -A 30 "traefik:" docker-compose.yml | grep -q "volumes:"; then
                    # Lägg till volumes efter traefik service definition
                    sed -i '/traefik:/a\    volumes:\n      - /var/run/docker.sock:/var/run/docker.sock:ro' docker-compose.yml
                elif ! grep -A 30 "traefik:" docker-compose.yml | grep -q "/var/run/docker.sock"; then
                    # Lägg till socket i befintlig volumes section
                    sed -i '/traefik:/,/^[[:space:]]*[a-z]/ { /volumes:/a\      - /var/run/docker.sock:/var/run/docker.sock:ro' docker-compose.yml
                fi
            fi
            echo "  ✅ Docker socket mount tillagd"
        else
            echo "  ✅ Docker socket mount finns redan"
        fi
        
        echo ""
        echo "  📋 Uppdaterad docker-compose.yml:"
        grep -A 5 "traefik:" docker-compose.yml | head -10 || echo "  Kunde inte visa konfiguration"
        
        echo ""
        echo "  🔄 Pullar Traefik v3.6.1..."
        docker pull traefik:v3.6.1
        
        echo ""
        echo "  🔄 Startar om Traefik med ny version..."
        if docker compose version >/dev/null 2>&1; then
            docker compose down
            sleep 3
            docker compose up -d
        else
            docker-compose down
            sleep 3
            docker-compose up -d
        fi
        
        echo "  ✅ Traefik uppgraderad till v3.6.1 och omstartad"
        echo "  Väntar 25 sekunder för att Traefik ska starta klart..."
        sleep 25
    else
        echo "  ❌ docker-compose.yml saknas"
    fi
else
    echo "  ❌ /data/coolify/proxy directory saknas"
fi
REMOTE

# ============================================================================
# STEG 3: Verifiera Traefik efter uppgradering
# ============================================================================
section "STEG 3: Verifierar Traefik efter uppgradering"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Kontrollerar Traefik efter uppgradering..."
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
        echo "  📋 Senaste logs (väntar 5 sekunder)..."
        sleep 5
        
        echo ""
        echo "  🔍 API-fel:"
        API_ERROR=$(docker logs "$TRAEFIK_CONTAINER" --tail 20 2>/dev/null | grep -i "client version.*too old" | tail -1 || echo "")
        
        if [ -z "$API_ERROR" ]; then
            echo "    ✅ Inga API-fel! Traefik v3.6.1 fungerar!"
            echo ""
            echo "    📋 Routing-status:"
            docker logs "$TRAEFIK_CONTAINER" --tail 15 2>/dev/null | grep -iE "configuration|routing|backend|service|provider" | tail -5 || echo "    Väntar på routing-meddelanden..."
        else
            echo "    ⚠️  API-fel kvarstår:"
            echo "    $API_ERROR"
            echo ""
            echo "    💡 Prova att starta om Traefik en gång till"
        fi
    else
        echo "  ❌ Traefik körs inte"
        echo "  Försöker starta..."
        docker start "$TRAEFIK_CONTAINER" 2>/dev/null && echo "  ✅ Startad" || echo "  ❌ Kunde inte starta"
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
    echo "  Öppna: $COOLIFY_URL"
else
    warn "Coolify dashboard når inte ännu ($HTTP_CODE)"
    echo "  Vänta 1-2 minuter och testa igen"
    echo "  Eller kör: ./scripts/diagnose-404.sh"
fi

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning"

echo ""
info "Traefik uppgraderad!"
echo ""
echo "💡 Nästa steg:"
echo ""
echo "1. Vänta 1-2 minuter för att Traefik ska starta klart"
echo "2. Testa Coolify dashboard: https://coolify.theunnamedroads.com"
echo "3. Om API-fel kvarstår, starta om Traefik en gång till:"
echo "   ssh tha 'cd /data/coolify/proxy && docker compose restart'"
echo ""
echo "4. Efter att Traefik fungerar, redeploya services:"
echo "   • Gå till varje service i Coolify Dashboard"
echo "   • Kontrollera att 'Domain' är konfigurerad"
echo "   • Klicka 'Redeploy'"
echo ""
echo "🔧 Ytterligare kommandon:"
echo "  • Diagnostik: ./scripts/diagnose-404.sh"
echo "  • Verifiera: ./scripts/verify-all.sh"
echo ""

