#!/usr/bin/env bash
set -euo pipefail

# add-coolify-domain.sh - Lägger till Traefik labels för Coolify dashboard

HOST="${1:-tha}"
DOMAIN="${2:-coolify.theunnamedroads.com}"

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

echo "🔧 Lägger till Traefik Labels för Coolify Dashboard"
echo "====================================================="
echo ""
warn "Domain: $DOMAIN"
echo ""

# ============================================================================
# STEG 1: Kontrollera Coolify docker-compose.yml
# ============================================================================
section "STEG 1: Kontrollerar Coolify docker-compose.yml"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Kontrollerar Coolify-konfiguration..."
echo ""

if [ -d "/data/coolify/source" ]; then
    cd /data/coolify/source
    
    if [ -f "docker-compose.yml" ]; then
        echo "  ✅ docker-compose.yml finns"
        
        # Kolla om det redan finns Traefik labels
        if grep -q "traefik.enable" docker-compose.yml; then
            echo "  ⚠️  Traefik labels finns redan i docker-compose.yml"
            echo ""
            echo "  📋 Nuvarande Traefik labels:"
            grep -A 10 "traefik" docker-compose.yml | head -15
        else
            echo "  ⚠️  Inga Traefik labels hittades"
        fi
    else
        echo "  ❌ docker-compose.yml saknas"
    fi
else
    echo "  ❌ /data/coolify/source directory saknas"
fi
REMOTE

# ============================================================================
# STEG 2: Lägg till Traefik labels
# ============================================================================
section "STEG 2: Lägger till Traefik labels för Coolify"

echo "🔄 Lägger till Traefik labels..."
echo ""
warn "Detta kommer att:"
echo "  • Lägga till Traefik labels i Coolify's docker-compose.yml"
echo "  • Starta om Coolify-containern"
echo "  • Göra Coolify tillgänglig via: https://$DOMAIN"
echo ""

read -p "Vill du fortsätta? (ja/nej): " -r
if [[ ! $REPLY =~ ^[Jj]a$ ]]; then
    info "Avbruten av användaren"
    exit 0
fi

ssh "$HOST" bash <<REMOTE
if [ -d "/data/coolify/source" ]; then
    cd /data/coolify/source
    
    if [ -f "docker-compose.yml" ]; then
        # Backup
        cp docker-compose.yml docker-compose.yml.backup.\$(date +%Y%m%d-%H%M%S)
        echo "  💾 Backup skapad"
        
        # Hitta coolify service
        if grep -q "^  coolify:" docker-compose.yml; then
            echo "  🔄 Lägger till Traefik labels..."
            
            # Kolla om labels redan finns
            if ! grep -q "traefik.enable" docker-compose.yml; then
                # Hitta var coolify service slutar (nästa service eller volumes/networks)
                # Lägg till labels efter environment eller volumes
                if grep -A 20 "^  coolify:" docker-compose.yml | grep -q "volumes:"; then
                    # Lägg till labels efter volumes
                    sed -i '/^  coolify:/,/^  [a-z]/ { /volumes:/a\    labels:\n      - "traefik.enable=true"\n      - "traefik.http.routers.coolify.rule=Host(\\`'"$DOMAIN"'\\`)"\n      - "traefik.http.routers.coolify.entrypoints=https"\n      - "traefik.http.routers.coolify.tls=true"\n      - "traefik.http.routers.coolify.tls.certresolver=letsencrypt"\n      - "traefik.http.services.coolify.loadbalancer.server.port=8080"' docker-compose.yml
                elif grep -A 20 "^  coolify:" docker-compose.yml | grep -q "environment:"; then
                    # Lägg till labels efter environment
                    sed -i '/^  coolify:/,/^  [a-z]/ { /environment:/a\    labels:\n      - "traefik.enable=true"\n      - "traefik.http.routers.coolify.rule=Host(\\`'"$DOMAIN"'\\`)"\n      - "traefik.http.routers.coolify.entrypoints=https"\n      - "traefik.http.routers.coolify.tls=true"\n      - "traefik.http.routers.coolify.tls.certresolver=letsencrypt"\n      - "traefik.http.services.coolify.loadbalancer.server.port=8080"' docker-compose.yml
                else
                    # Lägg till labels direkt efter coolify:
                    sed -i '/^  coolify:/a\    labels:\n      - "traefik.enable=true"\n      - "traefik.http.routers.coolify.rule=Host(\\`'"$DOMAIN"'\\`)"\n      - "traefik.http.routers.coolify.entrypoints=https"\n      - "traefik.http.routers.coolify.tls=true"\n      - "traefik.http.routers.coolify.tls.certresolver=letsencrypt"\n      - "traefik.http.services.coolify.loadbalancer.server.port=8080"' docker-compose.yml
                fi
                
                echo "  ✅ Traefik labels tillagda"
            else
                echo "  ⚠️  Traefik labels finns redan"
            fi
            
            # Säkerställ att coolify network finns
            if ! grep -q "coolify:" docker-compose.yml | grep -q "networks:"; then
                if ! grep -q "^networks:" docker-compose.yml; then
                    echo "" >> docker-compose.yml
                    echo "networks:" >> docker-compose.yml
                    echo "  coolify:" >> docker-compose.yml
                    echo "    external: true" >> docker-compose.yml
                fi
            fi
            
            echo ""
            echo "  📋 Uppdaterad konfiguration:"
            grep -A 15 "^  coolify:" docker-compose.yml | head -20
            
            echo ""
            echo "  🔄 Startar om Coolify..."
            if docker compose version >/dev/null 2>&1; then
                docker compose up -d coolify
            else
                docker-compose up -d coolify
            fi
            
            echo "  ✅ Coolify omstartad"
            echo "  Väntar 15 sekunder..."
            sleep 15
        else
            echo "  ❌ coolify service hittades inte i docker-compose.yml"
        fi
    else
        echo "  ❌ docker-compose.yml saknas"
    fi
else
    echo "  ❌ /data/coolify/source directory saknas"
fi
REMOTE

# ============================================================================
# STEG 3: Verifiera
# ============================================================================
section "STEG 3: Verifierar Coolify Dashboard"

echo "🔍 Testar Coolify dashboard..."
echo ""

COOLIFY_URL="https://$DOMAIN"
HTTP_CODE=$(curl -I -s --max-time 10 "$COOLIFY_URL" 2>/dev/null | head -1 | awk '{print $2}' || echo "000")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
    info "Coolify dashboard nåbar ($HTTP_CODE)"
    echo "  Öppna: $COOLIFY_URL"
else
    warn "Coolify dashboard når inte ännu ($HTTP_CODE)"
    echo "  Vänta 1-2 minuter för SSL-certifikat och testa igen"
fi

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning"

echo ""
info "Traefik labels tillagda för Coolify!"
echo ""
echo "💡 Nästa steg:"
echo ""
echo "1. Vänta 1-2 minuter för SSL-certifikat"
echo "2. Testa: https://$DOMAIN"
echo "3. Om det inte fungerar, kontrollera:"
echo "   ./scripts/check-coolify-traefik.sh"
echo ""


