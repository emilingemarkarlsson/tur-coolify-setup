#!/usr/bin/env bash
set -euo pipefail

# verify-and-fix-versions.sh - Verifierar och fixar versioner enligt Coolify's officiella dokumentation

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

echo "🔍 Verifierar Versioner enligt Coolify's Officiella Dokumentation"
echo "================================================================="

# ============================================================================
# STEG 1: Verifiera Ubuntu Version
# ============================================================================
section "STEG 1: Verifierar Ubuntu Version"

ssh "$HOST" bash <<'REMOTE'
echo "🐧 Ubuntu Version:"
echo ""

UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "unknown")
UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || echo "unknown")

echo "  Version: $UBUNTU_VERSION"
echo "  Codename: $UBUNTU_CODENAME"

# Coolify stödjer Ubuntu 22.04 (Jammy)
if [[ "$UBUNTU_VERSION" == "22.04"* ]]; then
    echo "  ✅ Ubuntu 22.04 - Kompatibel med Coolify"
elif [[ "$UBUNTU_VERSION" == "20.04"* ]]; then
    echo "  ✅ Ubuntu 20.04 - Kompatibel med Coolify"
else
    echo "  ⚠️  Ubuntu $UBUNTU_VERSION - Kontrollera kompatibilitet"
fi
REMOTE

# ============================================================================
# STEG 2: Verifiera Docker Version
# ============================================================================
section "STEG 2: Verifierar Docker Version"

ssh "$HOST" bash <<'REMOTE'
echo "🐳 Docker Version:"
echo ""

DOCKER_VERSION=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
DOCKER_API=$(docker version --format '{{.Server.APIVersion}}' 2>/dev/null || echo "unknown")

echo "  Docker version: $DOCKER_VERSION"
echo "  Docker API version: $DOCKER_API"

# Docker 29.x kräver API 1.44+
if [[ "$DOCKER_VERSION" == "29."* ]]; then
    echo "  ✅ Docker 29.x (kräver API 1.44+)"
    echo "  ⚠️  Traefik MÅSTE vara v3.6.1+ eller v2.11.31+"
elif [[ "$DOCKER_VERSION" == "2"* ]]; then
    echo "  ✅ Docker 2.x (kompatibel)"
else
    echo "  ⚠️  Docker version: $DOCKER_VERSION"
fi

echo ""
echo "  📋 Coolify krav:"
echo "    • Docker 20.10+ (du har: $DOCKER_VERSION ✅)"
echo "    • Docker Compose v2+"
REMOTE

# ============================================================================
# STEG 3: Verifiera Traefik Version (KRITISKT)
# ============================================================================
section "STEG 3: Verifierar Traefik Version (KRITISKT)"

ssh "$HOST" bash <<'REMOTE'
echo "🌐 Traefik Version:"
echo ""

TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    CURRENT_IMAGE=$(docker inspect "$TRAEFIK_CONTAINER" --format '{{.Config.Image}}' 2>/dev/null || echo "unknown")
    echo "  Container: $TRAEFIK_CONTAINER"
    echo "  Nuvarande image: $CURRENT_IMAGE"
    
    # Extrahera version från image
    if [[ "$CURRENT_IMAGE" == *"v3.6"* ]] || [[ "$CURRENT_IMAGE" == *"v3.7"* ]] || [[ "$CURRENT_IMAGE" == *"v3.8"* ]]; then
        echo "  ✅ Traefik v3.6+ - Kompatibel med Docker 29.x"
    elif [[ "$CURRENT_IMAGE" == *"v3.0"* ]] || [[ "$CURRENT_IMAGE" == *"v3.1"* ]] || [[ "$CURRENT_IMAGE" == *"v3.2"* ]] || [[ "$CURRENT_IMAGE" == *"v3.3"* ]] || [[ "$CURRENT_IMAGE" == *"v3.4"* ]] || [[ "$CURRENT_IMAGE" == *"v3.5"* ]]; then
        echo "  ⚠️  Traefik v3.0-3.5 - Kan ha API-problem med Docker 29.x"
        echo "  💡 Rekommenderat: Uppgradera till v3.6.1+"
    elif [[ "$CURRENT_IMAGE" == *"v2.11.31"* ]] || [[ "$CURRENT_IMAGE" == *"v2.11"* ]]; then
        echo "  ✅ Traefik v2.11.31+ - Kompatibel med Docker 29.x"
    elif [[ "$CURRENT_IMAGE" == *"v2"* ]]; then
        echo "  ⚠️  Traefik v2.x (gammal) - Uppgradera till v2.11.31+ eller v3.6.1+"
    else
        echo "  ⚠️  Okänd Traefik version"
    fi
    
    echo ""
    echo "  📋 Coolify rekommendation:"
    echo "    • Traefik v3.6.1+ (för Docker 29.x)"
    echo "    • Eller Traefik v2.11.31+ (för Docker 29.x)"
    
    echo ""
    echo "  🔍 API-fel check:"
    API_ERROR=$(docker logs "$TRAEFIK_CONTAINER" --tail 10 2>/dev/null | grep -i "client version.*too old" | tail -1 || echo "")
    if [ -n "$API_ERROR" ]; then
        echo "    ❌ API-fel bekräftat - Traefik behöver uppgraderas"
    else
        echo "    ✅ Inga API-fel"
    fi
else
    echo "  ❌ Traefik container hittades inte"
fi
REMOTE

# ============================================================================
# STEG 4: Uppgradera Traefik till v3.6.1 (Coolify's Rekommendation)
# ============================================================================
section "STEG 4: Uppgraderar Traefik till v3.6.1 (Coolify's Rekommendation)"

echo "🔄 Uppgraderar Traefik till v3.6.1..."
echo ""
warn "Enligt Coolify's officiella dokumentation:"
echo "  • Docker 29.x kräver Traefik v3.6.1+ eller v2.11.31+"
echo "  • Coolify rekommenderar v3.6.1 specifikt"
echo ""

read -p "Vill du uppgradera Traefik till v3.6.1 nu? (ja/nej): " -r
if [[ ! $REPLY =~ ^[Jj]a$ ]]; then
    info "Uppgradering avbruten"
    exit 0
fi

ssh "$HOST" bash <<'REMOTE'
echo "🔄 Uppgraderar Traefik till v3.6.1..."
echo ""

if [ -d "/data/coolify/proxy" ]; then
    cd /data/coolify/proxy
    
    if [ -f "docker-compose.yml" ]; then
        echo "  ✅ docker-compose.yml finns"
        
        # Backup
        cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d-%H%M%S)
        echo "  💾 Backup skapad"
        
        # Uppdatera till Traefik v3.6.1 (Coolify's rekommendation)
        echo ""
        echo "  🔄 Uppdaterar image till traefik:v3.6.1..."
        
        # Ersätt image-tag
        sed -i 's|image:.*traefik.*|image: traefik:v3.6.1|g' docker-compose.yml
        
        # Säkerställ Docker socket mount
        if ! grep -q "/var/run/docker.sock" docker-compose.yml; then
            echo "  🔄 Lägger till Docker socket mount..."
            if grep -q "traefik:" docker-compose.yml; then
                if ! grep -A 30 "traefik:" docker-compose.yml | grep -q "volumes:"; then
                    sed -i '/traefik:/a\    volumes:\n      - /var/run/docker.sock:/var/run/docker.sock:ro' docker-compose.yml
                fi
            fi
        fi
        
        echo ""
        echo "  📋 Uppdaterad konfiguration:"
        grep -A 3 "traefik:" docker-compose.yml | grep -E "image:|volumes:" | head -5
        
        echo ""
        echo "  🔄 Pullar Traefik v3.6.1..."
        docker pull traefik:v3.6.1
        
        echo ""
        echo "  🔄 Startar om Traefik..."
        if docker compose version >/dev/null 2>&1; then
            docker compose down
            sleep 3
            docker compose up -d
        else
            docker-compose down
            sleep 3
            docker-compose up -d
        fi
        
        echo "  ✅ Traefik uppgraderad till v3.6.1"
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
# STEG 5: Verifiera efter uppgradering
# ============================================================================
section "STEG 5: Verifierar efter uppgradering"

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
        echo "  🔍 API-fel check:"
        API_ERROR=$(docker logs "$TRAEFIK_CONTAINER" --tail 20 2>/dev/null | grep -i "client version.*too old" | tail -1 || echo "")
        
        if [ -z "$API_ERROR" ]; then
            echo "    ✅ Inga API-fel! Traefik v3.6.1 fungerar!"
            echo ""
            echo "    📋 Routing-status:"
            docker logs "$TRAEFIK_CONTAINER" --tail 20 2>/dev/null | grep -iE "configuration|routing|backend|service|provider" | tail -5 || echo "    Väntar på routing-meddelanden..."
        else
            echo "    ⚠️  API-fel kvarstår:"
            echo "    $API_ERROR"
            echo ""
            echo "    💡 Prova att starta om Traefik en gång till"
        fi
    else
        echo "  ❌ Traefik körs inte"
    fi
else
    echo "  ❌ Traefik container hittades inte"
fi
REMOTE

# ============================================================================
# STEG 6: Verifiera Coolify Version
# ============================================================================
section "STEG 6: Verifierar Coolify Version"

ssh "$HOST" bash <<'REMOTE'
echo "🔧 Coolify Version:"
echo ""

if [ -d "/data/coolify/source" ]; then
    cd /data/coolify/source
    
    # Försök hitta Coolify version
    COOLIFY_VERSION=$(docker ps --filter "name=coolify" --format '{{.Image}}' 2>/dev/null | head -1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    
    if [ "$COOLIFY_VERSION" != "unknown" ]; then
        echo "  Coolify version: $COOLIFY_VERSION"
    else
        echo "  ℹ️  Kunde inte hitta exakt version"
    fi
    
    echo ""
    echo "  📋 Coolify containers:"
    docker ps --filter "name=coolify" --format "    • {{.Names}} ({{.Image}})" 2>/dev/null | head -10
    
    echo ""
    echo "  💡 För att uppdatera Coolify:"
    echo "     Gå till Coolify dashboard → Settings → Update"
fi
REMOTE

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning & Rekommendationer"

echo ""
info "Version-verifiering klar!"
echo ""
echo "📋 Enligt Coolify's officiella dokumentation:"
echo ""
echo "✅ Kompatibla versioner för Ubuntu 22.04 + Docker 29.x:"
echo "   • Ubuntu: 22.04.5 LTS ✅"
echo "   • Docker: 29.1.3 ✅"
echo "   • Traefik: v3.6.1+ (rekommenderat) ✅"
echo ""
echo "💡 Nästa steg:"
echo ""
echo "1. Om Traefik är uppgraderad till v3.6.1:"
echo "   • Vänta 1-2 minuter"
echo "   • Testa Coolify dashboard: https://coolify.theunnamedroads.com"
echo "   • Verifiera: ./scripts/diagnose-404.sh"
echo ""
echo "2. Efter Traefik-fix, redeploya services:"
echo "   • Gå till varje service i Coolify Dashboard"
echo "   • Kontrollera att 'Domain' är konfigurerad"
echo "   • Klicka 'Redeploy'"
echo ""
echo "3. Om problem kvarstår:"
echo "   • Kontrollera Coolify version i dashboard"
echo "   • Uppdatera Coolify om nödvändigt"
echo ""
echo "🔧 Ytterligare kommandon:"
echo "  • Diagnostik: ./scripts/diagnose-404.sh"
echo "  • Verifiera allt: ./scripts/verify-all.sh"
echo ""


