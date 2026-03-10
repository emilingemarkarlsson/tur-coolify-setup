#!/usr/bin/env bash
set -euo pipefail

# fix-all-routing.sh - Komplett fix av alla routing-problem

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

echo "🔧 Komplett Fix av Alla Routing-problem"
echo "======================================="
echo ""
warn "Detta script fixar:"
echo "  • Ansluter services till coolify network"
echo "  • Fixar Traefik Docker socket"
echo "  • Förbereder för redeploy"
echo ""
warn "VIKTIGT: Efter detta script måste du redeploya services i Coolify Dashboard"
echo "         för att få Traefik labels!"
echo ""
read -p "Vill du fortsätta? (ja/nej): " -r
if [[ ! $REPLY =~ ^[Jj]a$ ]]; then
    info "Avbruten av användaren"
    exit 0
fi

# ============================================================================
# STEG 1: Anslut Services till Coolify Network
# ============================================================================
section "STEG 1: Ansluter Services till Coolify Network"

ssh "$HOST" bash <<'REMOTE'
echo "🌐 Ansluter services till coolify network..."
echo ""

COOLIFY_NETWORK=$(docker network ls --filter "name=coolify" --format '{{.Name}}' 2>/dev/null | head -1)

if [ -n "$COOLIFY_NETWORK" ]; then
    echo "  Network: $COOLIFY_NETWORK"
    echo ""
    
    # Hitta alla service containers
    SERVICE_CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -v "coolify" | grep -v "traefik" | grep -v "postgres" || true)
    
    if [ -n "$SERVICE_CONTAINERS" ]; then
        FIXED=0
        while IFS= read -r container; do
            if [ -n "$container" ]; then
                # Kolla om container är på network
                ON_NETWORK=$(docker network inspect "$COOLIFY_NETWORK" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | grep -o "$container" || echo "")
                
                if [ -z "$ON_NETWORK" ]; then
                    echo "  📦 Ansluter $container till network..."
                    if docker network connect "$COOLIFY_NETWORK" "$container" 2>/dev/null; then
                        echo "    ✅ Ansluten"
                        FIXED=$((FIXED + 1))
                    else
                        echo "    ⚠️  Kunde inte ansluta (kan redan vara ansluten eller ha konflikt)"
                    fi
                else
                    echo "  ✅ $container är redan på network"
                fi
            fi
        done <<< "$SERVICE_CONTAINERS"
        
        echo ""
        if [ "$FIXED" -gt 0 ]; then
            echo "  ✅ $FIXED service(s) anslutna till network"
        else
            echo "  ℹ️  Alla services är redan på network"
        fi
    else
        echo "  ⚠️  Inga service-containers hittades"
    fi
else
    echo "  ❌ Coolify network saknas!"
fi
REMOTE

# ============================================================================
# STEG 2: Fixa Traefik Docker Socket
# ============================================================================
section "STEG 2: Fixar Traefik Docker Socket Mount"

ssh "$HOST" bash <<'REMOTE'
echo "🔧 Kontrollerar Traefik Docker socket..."
echo ""

if [ -d "/data/coolify/proxy" ]; then
    cd /data/coolify/proxy
    
    if [ -f "docker-compose.yml" ]; then
        echo "  ✅ docker-compose.yml finns"
        
        # Kolla om Docker socket mount finns
        if grep -q "/var/run/docker.sock" docker-compose.yml; then
            echo "  ✅ Docker socket mount finns"
        else
            echo "  ⚠️  Docker socket mount saknas - lägger till..."
            
            # Backup
            cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d-%H%M%S)
            
            # Lägg till volumes section om den saknas
            if ! grep -q "^volumes:" docker-compose.yml; then
                # Hitta var services: slutar och lägg till volumes
                sed -i '/^services:/a\volumes:\n  docker.sock:\n    external: false' docker-compose.yml
            fi
            
            # Lägg till socket mount i traefik service
            if grep -q "traefik:" docker-compose.yml; then
                # Kolla om volumes redan finns i traefik service
                if ! grep -A 20 "traefik:" docker-compose.yml | grep -q "volumes:"; then
                    # Lägg till volumes efter traefik service definition
                    sed -i '/traefik:/a\    volumes:\n      - /var/run/docker.sock:/var/run/docker.sock:ro' docker-compose.yml
                elif ! grep -A 20 "traefik:" docker-compose.yml | grep -q "/var/run/docker.sock"; then
                    # Lägg till socket i befintlig volumes section
                    sed -i '/traefik:/,/^[[:space:]]*[a-z]/ { /volumes:/a\      - /var/run/docker.sock:/var/run/docker.sock:ro' docker-compose.yml
                fi
            fi
            
            echo "  ✅ Docker socket mount tillagt"
            echo "  🔄 Startar om Traefik..."
            
            if docker compose version >/dev/null 2>&1; then
                docker compose down
                sleep 2
                docker compose up -d
            else
                docker-compose down
                sleep 2
                docker-compose up -d
            fi
            
            echo "  ✅ Traefik omstartad"
            sleep 10
        fi
    else
        echo "  ⚠️  docker-compose.yml saknas"
    fi
else
    echo "  ⚠️  /data/coolify/proxy directory saknas"
fi
REMOTE

# ============================================================================
# STEG 3: Verifiera Traefik API
# ============================================================================
section "STEG 3: Verifierar Traefik API efter fix"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Kontrollerar Traefik API-status..."
echo ""

TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    echo "  Container: $TRAEFIK_CONTAINER"
    echo ""
    echo "  📋 Senaste logs (väntar 5 sekunder för att Traefik ska starta)..."
    sleep 5
    
    API_ERROR=$(docker logs "$TRAEFIK_CONTAINER" --tail 10 2>/dev/null | grep -i "client version.*too old" | tail -1 || echo "")
    
    if [ -z "$API_ERROR" ]; then
        echo "    ✅ Inga API-fel!"
        echo ""
        echo "    📋 Routing-status:"
        docker logs "$TRAEFIK_CONTAINER" --tail 15 2>/dev/null | grep -iE "configuration|routing|backend|service" | tail -3 || echo "    Väntar på routing-meddelanden..."
    else
        echo "    ⚠️  API-fel kvarstår:"
        echo "    $API_ERROR"
        echo ""
        echo "    💡 Traefik behöver uppdateras via Coolify dashboard"
    fi
fi
REMOTE

# ============================================================================
# STEG 4: Förbereder Services för Redeploy
# ============================================================================
section "STEG 4: Förbereder Services för Redeploy (För Traefik Labels)"

ssh "$HOST" bash <<'REMOTE'
echo "📋 Listar services som behöver redeploy..."
echo ""

if [ -d "/data/coolify/services" ]; then
    echo "  Services i /data/coolify/services:"
    echo ""
    
    for service_dir in /data/coolify/services/*; do
        if [ -d "$service_dir" ]; then
            SERVICE_NAME=$(basename "$service_dir")
            echo "  📦 $SERVICE_NAME"
            
            # Kolla om docker-compose.yml finns
            if [ -f "$service_dir/docker-compose.yml" ]; then
                # Kolla om det finns Traefik labels i filen
                if grep -q "traefik.enable" "$service_dir/docker-compose.yml"; then
                    echo "    ✅ Traefik labels finns i compose-fil"
                else
                    echo "    ⚠️  Traefik labels saknas i compose-fil"
                fi
                
                # Kolla om service är på coolify network
                if grep -q "coolify:" "$service_dir/docker-compose.yml"; then
                    echo "    ✅ coolify network konfigurerad"
                else
                    echo "    ⚠️  coolify network saknas"
                fi
            else
                echo "    ⚠️  docker-compose.yml saknas"
            fi
            echo ""
        fi
    done
fi
REMOTE

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning & KRITISKA NÄSTA STEG"

echo ""
warn "VIKTIGT: Services saknar Traefik labels!"
echo ""
echo "Detta är huvudorsaken till 404-fel. Coolify måste redeploya services"
echo "för att lägga till Traefik labels automatiskt."
echo ""
echo "💡 KRITISKA STEG (Gör detta nu):"
echo ""
echo "1. Öppna Coolify Dashboard:"
echo "   https://coolify.theunnamedroads.com"
echo ""
echo "2. För VARJE service (minio, n8n, umami, open-webui, litellm):"
echo "   a. Klicka på service"
echo "   b. Gå till 'Domains' eller 'Settings'"
echo "   c. Kontrollera att domän är konfigurerad"
echo "   d. Om domän saknas, lägg till den"
echo "   e. Klicka 'Redeploy' eller 'Deploy'"
echo ""
echo "3. Efter redeploy av alla services:"
echo "   • Vänta 2-3 minuter"
echo "   • Kör: ./scripts/diagnose-404.sh"
echo "   • Testa dina services"
echo ""
echo "🔧 Om Traefik API-fel kvarstår efter redeploy:"
echo "   • Gå till Coolify → Settings → Proxy"
echo "   • Klicka 'Redeploy' på Traefik"
echo ""
echo "📝 Alternativ: Manuell redeploy via SSH"
echo "   ssh tha"
echo "   cd /data/coolify/services/<service-id>"
echo "   docker compose down && docker compose up -d"
echo ""

