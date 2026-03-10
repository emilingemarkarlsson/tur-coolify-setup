#!/usr/bin/env bash
set -euo pipefail

# upgrade-check.sh - Kontrollerar vad som behöver uppdateras enligt officiell dokumentation

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

echo "🔍 Uppgraderingskontroll - Enligt Officiell Dokumentation"
echo "=========================================================="

# ============================================================================
# STEG 1: Kontrollera Systemversioner
# ============================================================================
section "STEG 1: Systemversioner"

ssh "$HOST" bash <<'REMOTE'
echo "🐧 Ubuntu:"
UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "unknown")
echo "  Version: $UBUNTU_VERSION"

echo ""
echo "🐳 Docker:"
DOCKER_VERSION=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
DOCKER_API=$(docker version --format '{{.Server.APIVersion}}' 2>/dev/null || echo "unknown")
echo "  Version: $DOCKER_VERSION"
echo "  API: $DOCKER_API"

echo ""
echo "🔧 Coolify:"
if [ -d "/data/coolify/source" ]; then
    COOLIFY_VERSION=$(docker ps --filter "name=^coolify$" --format '{{.Image}}' 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    echo "  Version: $COOLIFY_VERSION"
else
    echo "  ⚠️  Coolify installation ej hittad"
fi

echo ""
echo "🌐 Traefik:"
TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi
if [ -n "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_IMAGE=$(docker inspect "$TRAEFIK_CONTAINER" --format '{{.Config.Image}}' 2>/dev/null || echo "unknown")
    echo "  Image: $TRAEFIK_IMAGE"
else
    echo "  ⚠️  Traefik container ej hittad"
fi
REMOTE

# ============================================================================
# STEG 2: Kontrollera Kompatibilitet
# ============================================================================
section "STEG 2: Kompatibilitetskontroll"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Kontrollerar kompatibilitet..."
echo ""

# Docker 29.x kräver Traefik v3.6.1+ eller v2.11.31+
DOCKER_VERSION=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [[ "$DOCKER_VERSION" == "29."* ]]; then
    echo "  ✅ Docker 29.x (kräver API 1.44+)"
    
    if [ -n "$TRAEFIK_CONTAINER" ]; then
        TRAEFIK_IMAGE=$(docker inspect "$TRAEFIK_CONTAINER" --format '{{.Config.Image}}' 2>/dev/null || echo "")
        
        if [[ "$TRAEFIK_IMAGE" == *"v3.6"* ]] || [[ "$TRAEFIK_IMAGE" == *"v3.7"* ]] || [[ "$TRAEFIK_IMAGE" == *"v3.8"* ]]; then
            echo "  ✅ Traefik v3.6+ - Kompatibel"
        elif [[ "$TRAEFIK_IMAGE" == *"v2.11.31"* ]] || [[ "$TRAEFIK_IMAGE" == *"v2.11"* ]]; then
            echo "  ✅ Traefik v2.11.31+ - Kompatibel"
        else
            echo "  ⚠️  Traefik behöver uppdateras till v3.6.1+ eller v2.11.31+"
            echo "     Nuvarande: $TRAEFIK_IMAGE"
        fi
        
        # Kontrollera API-fel
        API_ERROR=$(docker logs "$TRAEFIK_CONTAINER" --tail 5 2>/dev/null | grep -i "client version.*too old" | tail -1 || echo "")
        if [ -n "$API_ERROR" ]; then
            echo "  ❌ API-fel bekräftat - Traefik behöver uppdateras"
        fi
    fi
fi
REMOTE

# ============================================================================
# STEG 3: Kontrollera Uppdateringar
# ============================================================================
section "STEG 3: Tillgängliga Uppdateringar"

ssh "$HOST" bash <<'REMOTE'
echo "🔄 Kontrollerar tillgängliga uppdateringar..."
echo ""

echo "  Systempaket:"
UPDATES=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
if [ "$UPDATES" -gt 0 ]; then
    echo "    ⚠️  $UPDATES paket kan uppdateras"
    echo "    Kör: ./scripts/update-server.sh"
else
    echo "    ✅ Alla paket är uppdaterade"
fi

echo ""
echo "  Docker:"
DOCKER_VERSION=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
echo "    Nuvarande: $DOCKER_VERSION"
echo "    💡 Kontrollera senaste version: https://docs.docker.com/engine/release-notes/"

echo ""
echo "  Coolify:"
if [ -d "/data/coolify/source" ]; then
    COOLIFY_VERSION=$(docker ps --filter "name=^coolify$" --format '{{.Image}}' 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    echo "    Nuvarande: $COOLIFY_VERSION"
    echo "    💡 Uppdatera via Coolify dashboard: Settings → Update"
else
    echo "    ⚠️  Coolify installation ej hittad"
fi

echo ""
echo "  Traefik:"
TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi
if [ -n "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_IMAGE=$(docker inspect "$TRAEFIK_CONTAINER" --format '{{.Config.Image}}' 2>/dev/null || echo "unknown")
    echo "    Nuvarande: $TRAEFIK_IMAGE"
    echo "    💡 Rekommenderat: v3.6.1+ (för Docker 29.x)"
    echo "    💡 Uppdatera via: ./scripts/upgrade-traefik.sh"
fi
REMOTE

# ============================================================================
# STEG 4: Rekommendationer
# ============================================================================
section "📊 Rekommendationer"

echo ""
echo "💡 Nästa steg baserat på kontrollen:"
echo ""

# Kontrollera vad som behöver göras
ssh "$HOST" bash <<'REMOTE' > /tmp/upgrade-status.txt 2>&1
NEEDS_UPDATE=0
NEEDS_TRAEFIK_UPGRADE=0

# Kontrollera systemuppdateringar
UPDATES=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
if [ "$UPDATES" -gt 0 ]; then
    echo "UPDATE_SYSTEM=1"
    NEEDS_UPDATE=1
else
    echo "UPDATE_SYSTEM=0"
fi

# Kontrollera Traefik
DOCKER_VERSION=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [[ "$DOCKER_VERSION" == "29."* ]] && [ -n "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_IMAGE=$(docker inspect "$TRAEFIK_CONTAINER" --format '{{.Config.Image}}' 2>/dev/null || echo "")
    
    if [[ ! "$TRAEFIK_IMAGE" == *"v3.6"* ]] && [[ ! "$TRAEFIK_IMAGE" == *"v3.7"* ]] && [[ ! "$TRAEFIK_IMAGE" == *"v3.8"* ]] && [[ ! "$TRAEFIK_IMAGE" == *"v2.11.31"* ]]; then
        echo "UPGRADE_TRAEFIK=1"
        NEEDS_TRAEFIK_UPGRADE=1
    else
        echo "UPGRADE_TRAEFIK=0"
    fi
else
    echo "UPGRADE_TRAEFIK=0"
fi
REMOTE

if grep -q "UPDATE_SYSTEM=1" /tmp/upgrade-status.txt 2>/dev/null; then
    echo "1. Uppdatera systempaket:"
    echo "   ./scripts/update-server.sh"
    echo ""
fi

if grep -q "UPGRADE_TRAEFIK=1" /tmp/upgrade-status.txt 2>/dev/null; then
    echo "2. Uppgradera Traefik (för Docker 29.x kompatibilitet):"
    echo "   ./scripts/upgrade-traefik.sh"
    echo ""
fi

echo "3. Verifiera allt efter uppdatering:"
echo "   ./scripts/verify-all.sh"
echo ""

rm -f /tmp/upgrade-status.txt

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📋 Sammanfattning"

echo ""
info "Uppgraderingskontroll klar!"
echo ""
echo "📚 Officiell dokumentation:"
echo "  • Coolify: https://coolify.io/docs"
echo "  • Traefik: https://doc.traefik.io/traefik/"
echo "  • Docker: https://docs.docker.com/"
echo ""
echo "🔧 Relevanta scripts:"
echo "  • Kontrollera versioner: ./scripts/verify-and-fix-versions.sh"
echo "  • Uppdatera system: ./scripts/update-server.sh"
echo "  • Uppgradera Traefik: ./scripts/upgrade-traefik.sh"
echo "  • Verifiera allt: ./scripts/verify-all.sh"
echo ""


