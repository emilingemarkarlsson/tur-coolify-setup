#!/usr/bin/env bash
set -euo pipefail

# configure-coolify-domain.sh - Visar hur man konfigurerar Coolify domain

HOST="${1:-tha}"
SERVER_IP="46.62.206.47"

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

echo "🔧 Konfigurera Coolify Domain"
echo "============================="

# ============================================================================
# STEG 1: Kontrollera Coolify Port
# ============================================================================
section "STEG 1: Kontrollerar Coolify Port"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Coolify Port:"
echo ""

COOLIFY_PORT=$(docker ps --filter "name=^coolify$" --format '{{.Ports}}' 2>/dev/null | grep -oE '0\.0\.0\.0:([0-9]+)->8080' | cut -d: -f2 | cut -d- -f1 || echo "8000")

if [ -n "$COOLIFY_PORT" ]; then
    echo "  ✅ Coolify körs på port: $COOLIFY_PORT"
    echo ""
    echo "  🌐 Du kan nå Coolify via:"
    echo "     http://$(curl -s ifconfig.me 2>/dev/null || echo "SERVER_IP"):$COOLIFY_PORT"
else
    echo "  ⚠️  Kunde inte hitta Coolify port"
fi
REMOTE

# ============================================================================
# INSTRUKTIONER
# ============================================================================
section "📋 Instruktioner för att konfigurera Coolify Domain"

echo ""
info "Steg 1: Öppna Coolify Dashboard"
echo ""
echo "  Öppna i webbläsaren:"
echo "    http://$SERVER_IP:8000"
echo ""
echo "  (Om port 8000 inte fungerar, testa: http://$SERVER_IP:8080)"
echo ""

warn "Steg 2: Konfigurera Domain i Coolify"
echo ""
echo "  1. Logga in i Coolify dashboard"
echo "  2. Gå till: Settings (⚙️) → Server → Proxy"
echo "  3. Under 'Domains' eller 'Proxy Configuration':"
echo "     • Lägg till domän: coolify.theunnamedroads.com"
echo "     • Välj 'HTTPS' (Let's Encrypt)"
echo "  4. Spara konfigurationen"
echo "  5. Klicka 'Redeploy' eller 'Restart Proxy'"
echo ""

info "Steg 3: Vänta på SSL-certifikat"
echo ""
echo "  • Vänta 1-2 minuter för att Let's Encrypt ska generera certifikat"
echo "  • Testa sedan: https://coolify.theunnamedroads.com"
echo ""

# ============================================================================
# ALTERNATIV: Kontrollera om Domain redan är konfigurerad
# ============================================================================
section "🔍 Kontrollerar om Domain redan är konfigurerad"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Kontrollerar Coolify-konfiguration..."
echo ""

if [ -d "/data/coolify" ]; then
    echo "  📁 Coolify data directory: /data/coolify"
    
    # Kolla om det finns domain-konfiguration
    if [ -f "/data/coolify/.env" ]; then
        echo "  ✅ .env fil finns"
        
        # Kolla efter domain
        DOMAIN=$(grep -i "DOMAIN\|FQDN" /data/coolify/.env 2>/dev/null | head -1 || echo "")
        if [ -n "$DOMAIN" ]; then
            echo "  📋 Domain-konfiguration:"
            echo "    $DOMAIN"
        else
            echo "  ⚠️  Ingen domain hittades i .env"
        fi
    else
        echo "  ⚠️  .env fil saknas"
    fi
    
    # Kolla docker-compose.yml för Coolify
    if [ -f "/data/coolify/source/docker-compose.yml" ]; then
        echo ""
        echo "  📋 Traefik labels i docker-compose.yml:"
        TRAEFIK_LABELS=$(grep -i "traefik" /data/coolify/source/docker-compose.yml 2>/dev/null | head -5 || echo "")
        if [ -n "$TRAEFIK_LABELS" ]; then
            echo "$TRAEFIK_LABELS" | sed 's/^/    /'
        else
            echo "    ⚠️  Inga Traefik labels hittades"
        fi
    fi
fi
REMOTE

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning"

echo ""
info "Följ dessa steg för att fixa Coolify dashboard:"
echo ""
echo "1. Öppna Coolify dashboard:"
echo "   http://$SERVER_IP:8000"
echo ""
echo "2. Gå till: Settings → Server → Proxy"
echo ""
echo "3. Lägg till domän: coolify.theunnamedroads.com"
echo ""
echo "4. Spara och klicka 'Redeploy'"
echo ""
echo "5. Vänta 1-2 minuter och testa:"
echo "   https://coolify.theunnamedroads.com"
echo ""
echo "💡 Om du inte kan nå Coolify via IP:"
echo "   • Kontrollera brandvägg: ssh tha 'ufw status'"
echo "   • Kontrollera att port 8000 är öppen"
echo ""


