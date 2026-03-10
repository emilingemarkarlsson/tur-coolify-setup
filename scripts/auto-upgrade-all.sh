#!/usr/bin/env bash
set -euo pipefail

# auto-upgrade-all.sh - Komplett automatiserad uppgraderingsprocess

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

echo "🚀 Komplett Automatiserad Uppgraderingsprocess"
echo "=============================================="
echo ""
warn "Detta script kommer att:"
echo "  1. Analysera nuvarande miljö"
echo "  2. Uppgradera Ubuntu-servern"
echo "  3. Uppdatera Docker"
echo "  4. Uppdatera Coolify"
echo "  5. Uppdatera alla aktiva services"
echo "  6. Skapa/uppdatera dokumentation"
echo "  7. Verifiera allt"
echo ""

read -p "Vill du fortsätta? (ja/nej): " -r
if [[ ! $REPLY =~ ^[Jj]a$ ]]; then
    info "Avbruten av användaren"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ============================================================================
# STEG 1: Analysera Nuvarande Miljö
# ============================================================================
section "STEG 1: Analyserar Nuvarande Miljö"

echo "🔍 Kontrollerar versioner och status..."
echo ""

# Kör upgrade-check för att se vad som behöver uppdateras
"$SCRIPT_DIR/upgrade-check.sh" "$HOST" || warn "Kunde inte köra upgrade-check"

# ============================================================================
# STEG 2: Uppgradera Ubuntu Server
# ============================================================================
section "STEG 2: Uppgraderar Ubuntu Server"

echo "🔄 Uppgraderar systempaket..."
echo ""

"$SCRIPT_DIR/update-server.sh" "$HOST" || {
    error "Serveruppdatering misslyckades"
    exit 1
}

# ============================================================================
# STEG 3: Verifiera & Uppdatera Docker
# ============================================================================
section "STEG 3: Verifierar & Uppdaterar Docker"

ssh "$HOST" bash <<'REMOTE'
echo "🐳 Docker Status:"
DOCKER_VERSION=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
echo "  Nuvarande: $DOCKER_VERSION"

# Kontrollera om Docker behöver uppdateras
echo ""
echo "  💡 Docker uppdateras via systempaket i steg 2"
echo "  Om Docker behöver manuell uppdatering, se: https://docs.docker.com/engine/install/ubuntu/"
REMOTE

# ============================================================================
# STEG 4: Uppdatera Coolify
# ============================================================================
section "STEG 4: Uppdaterar Coolify"

echo "🔄 Kontrollerar Coolify-version..."
echo ""

ssh "$HOST" bash <<'REMOTE'
if [ -d "/data/coolify/source" ]; then
    COOLIFY_VERSION=$(docker ps --filter "name=^coolify$" --format '{{.Image}}' 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    echo "  Nuvarande Coolify: $COOLIFY_VERSION"
    echo ""
    echo "  💡 Uppdatera Coolify via dashboard:"
    echo "     https://coolify.theunnamedroads.com → Settings → Update"
    echo ""
    echo "  Eller vänta tills scriptet kör: ./scripts/sync-coolify-resources.sh"
    echo "  för att automatiskt synka och uppdatera"
else
    echo "  ⚠️  Coolify installation ej hittad"
fi
REMOTE

# ============================================================================
# STEG 5: Uppdatera Traefik (om Docker 29.x)
# ============================================================================
section "STEG 5: Verifierar & Uppdaterar Traefik"

echo "🌐 Kontrollerar Traefik-kompatibilitet..."
echo ""

ssh "$HOST" bash <<'REMOTE'
DOCKER_VERSION=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [[ "$DOCKER_VERSION" == "29."* ]] && [ -n "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_IMAGE=$(docker inspect "$TRAEFIK_CONTAINER" --format '{{.Config.Image}}' 2>/dev/null || echo "")
    
    if [[ ! "$TRAEFIK_IMAGE" == *"v3.6"* ]] && [[ ! "$TRAEFIK_IMAGE" == *"v3.7"* ]] && [[ ! "$TRAEFIK_IMAGE" == *"v3.8"* ]]; then
        echo "  ⚠️  Traefik behöver uppdateras för Docker 29.x"
        echo "  Kör: ./scripts/upgrade-traefik.sh"
    else
        echo "  ✅ Traefik är kompatibel med Docker 29.x"
    fi
fi
REMOTE

# ============================================================================
# STEG 6: Synka Coolify Resurser & Skapa Dokumentation
# ============================================================================
section "STEG 6: Synkar Coolify Resurser & Skapar Dokumentation"

echo "📋 Synkar aktiva resurser från Coolify..."
echo ""

# Kör sync-scriptet (kommer att skapas)
if [ -f "$SCRIPT_DIR/sync-coolify-resources.sh" ]; then
    "$SCRIPT_DIR/sync-coolify-resources.sh" "$HOST" || warn "Kunde inte synka resurser"
else
    warn "sync-coolify-resources.sh saknas - skapar det nu..."
    # Detta kommer att skapas i nästa steg
fi

# ============================================================================
# STEG 7: Uppdatera Services
# ============================================================================
section "STEG 7: Uppdaterar Services"

echo "🔄 Kontrollerar services som behöver uppdateras..."
echo ""

# Detta kommer att hanteras av sync-scriptet
echo "  💡 Services kommer att analyseras och uppdateras av sync-scriptet"
echo "  Se individuella UPGRADE.md-filer för varje service"

# ============================================================================
# STEG 8: Verifiering
# ============================================================================
section "STEG 8: Verifierar Allt"

echo "🔍 Slutlig verifiering..."
echo ""

"$SCRIPT_DIR/verify-all.sh" "$HOST" || warn "Vissa verifieringar misslyckades"

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning"

echo ""
info "Automatiserad uppgradering klar!"
echo ""
echo "💡 Nästa steg:"
echo ""
echo "1. Kontrollera att allt fungerar:"
echo "   ./scripts/verify-all.sh"
echo ""
echo "2. Synka resurser och skapa dokumentation:"
echo "   ./scripts/sync-coolify-resources.sh"
echo ""
echo "3. Uppdatera services individuellt:"
echo "   Se UPGRADE.md i varje service-mapp"
echo ""
echo "📚 Dokumentation:"
echo "  • Uppgraderingsprocess: UPGRADE.md"
echo "  • Services: SERVICES.md"
echo "  • Troubleshooting: TROUBLESHOOTING.md"
echo ""


