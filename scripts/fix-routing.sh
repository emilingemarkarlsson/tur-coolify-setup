#!/usr/bin/env bash
set -euo pipefail

# fix-routing.sh - Fixar routing-problem (404, not available) efter serveromstart

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

echo "🔧 Fixar Routing-problem (404, Not Available)"
echo "=============================================="

# ============================================================================
# STEG 1: Kontrollera IP-adresser
# ============================================================================
section "STEG 1: Kontrollerar IP-adresser"

echo "🔍 Kontrollerar server IP-adresser..."
echo ""

ssh "$HOST" bash <<'REMOTE'
echo "📡 Server IP-adresser:"
echo "  IPv4:"
ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | while read ip; do
    echo "    • $ip"
done

echo ""
echo "  IPv6:"
ip -6 addr show | grep -oP '(?<=inet6\s)[0-9a-f:]+' | grep -v "::1" | head -3 | while read ip; do
    echo "    • $ip"
done

echo ""
echo "🌐 Publik IP (via externt API):"
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "kunde inte hämta")
echo "  $PUBLIC_IP"
REMOTE

echo ""
echo "📋 Förväntad IP: $SERVER_IP"
echo ""

# ============================================================================
# STEG 2: Kontrollera DNS
# ============================================================================
section "STEG 2: Kontrollerar DNS"

echo "🔍 Kontrollerar DNS för alla domäner..."
echo ""

domains=(
    "analytics.thehockeyanalytics.com"
    "coolify.theunnamedroads.com"
)

for domain in "${domains[@]}"; do
    echo "  $domain:"
    DNS_IP=$(nslookup "$domain" 2>/dev/null | grep -A 1 "Name:" | tail -1 | awk '{print $2}' || echo "")
    if [ -n "$DNS_IP" ]; then
        if [ "$DNS_IP" = "$SERVER_IP" ]; then
            info "    DNS pekar på rätt IP: $DNS_IP"
        else
            warn "    DNS pekar på fel IP: $DNS_IP (förväntat: $SERVER_IP)"
            echo "    ⚠️  Uppdatera DNS i Cloudflare!"
        fi
    else
        error "    Kunde inte hämta DNS"
    fi
done

# ============================================================================
# STEG 3: Kontrollera Traefik Status & Routing
# ============================================================================
section "STEG 3: Kontrollerar Traefik Routing"

ssh "$HOST" bash <<'REMOTE'
echo "🌐 Traefik Status:"
echo ""

TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    STATUS=$(docker inspect --format='{{.State.Status}}' "$TRAEFIK_CONTAINER" 2>/dev/null || echo "unknown")
    echo "  Container: $TRAEFIK_CONTAINER"
    echo "  Status: $STATUS"
    
    if [ "$STATUS" != "running" ]; then
        echo ""
        echo "  ❌ Traefik körs inte - startar..."
        docker start "$TRAEFIK_CONTAINER"
        sleep 5
    fi
    
    echo ""
    echo "  📋 Traefik Logs (söker efter routing/containers):"
    docker logs "$TRAEFIK_CONTAINER" --tail 30 2>/dev/null | grep -iE "routing|container|service|backend" | tail -5 || echo "  Inga routing-meddelanden"
    
    echo ""
    echo "  🔍 API-fel:"
    API_ERROR=$(docker logs "$TRAEFIK_CONTAINER" 2>/dev/null | grep -i "client version.*too old" | tail -1 || echo "")
    if [ -n "$API_ERROR" ]; then
        echo "    ❌ API-fel kvarstår - Traefik kan inte se containers"
        echo "    Detta är huvudorsaken till 404-fel!"
    else
        echo "    ✅ Inga API-fel"
    fi
else
    echo "  ❌ Traefik container hittades inte"
fi
REMOTE

# ============================================================================
# STEG 4: Kontrollera Services på Network
# ============================================================================
section "STEG 4: Kontrollerar Services på Coolify Network"

ssh "$HOST" bash <<'REMOTE'
echo "🌐 Coolify Network:"
echo ""

COOLIFY_NETWORK=$(docker network ls --filter "name=coolify" --format '{{.Name}}' 2>/dev/null | head -1)

if [ -n "$COOLIFY_NETWORK" ]; then
    echo "  ✅ Network finns: $COOLIFY_NETWORK"
    echo ""
    echo "  Containers på network:"
    docker network inspect "$COOLIFY_NETWORK" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | tr ' ' '\n' | grep -v '^$' | sort
    
    echo ""
    echo "  🔍 Service-containers på network:"
    SERVICE_CONTAINERS=$(docker network inspect "$COOLIFY_NETWORK" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | tr ' ' '\n' | grep -v "coolify" | grep -v "traefik" | grep -v "postgres" | grep -v '^$')
    
    if [ -n "$SERVICE_CONTAINERS" ]; then
        echo "$SERVICE_CONTAINERS" | while read -r container; do
            if [ -n "$container" ]; then
                echo "    ✅ $container"
            fi
        done
    else
        echo "    ⚠️  Inga service-containers på network!"
        echo "    Detta kan orsaka 404-fel"
    fi
else
    echo "  ❌ Coolify network saknas!"
fi
REMOTE

# ============================================================================
# STEG 5: Kontrollera Traefik Labels på Services
# ============================================================================
section "STEG 5: Kontrollerar Traefik Labels (Routing-konfiguration)"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Detaljerad kontroll av Traefik labels..."
echo ""

SERVICE_CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -v "coolify" | grep -v "traefik" | grep -v "postgres" | head -5)

if [ -n "$SERVICE_CONTAINERS" ]; then
    while IFS= read -r container; do
        if [ -n "$container" ]; then
            echo "📦 $container:"
            
            # Hämta alla Traefik labels
            TRAEFIK_LABELS=$(docker inspect "$container" --format '{{range $k, $v := .Config.Labels}}{{if match $k "traefik.*"}}{{$k}}={{$v}}{{println}}{{end}}{{end}}' 2>/dev/null)
            
            if [ -n "$TRAEFIK_LABELS" ]; then
                echo "$TRAEFIK_LABELS" | while IFS='=' read -r key value; do
                    if [ -n "$key" ]; then
                        echo "    • $key = $value"
                    fi
                done
            else
                echo "    ❌ Inga Traefik labels hittades!"
                echo "    Detta orsakar 404-fel"
            fi
            echo ""
        fi
    done <<< "$SERVICE_CONTAINERS"
else
    echo "  ⚠️  Inga service-containers hittades"
fi
REMOTE

# ============================================================================
# STEG 6: Starta om Traefik för att ladda om routing
# ============================================================================
section "STEG 6: Startar om Traefik för att ladda om routing"

ssh "$HOST" bash <<'REMOTE'
echo "🔄 Startar om Traefik för att ladda om routing-konfiguration..."
echo ""

TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    echo "  Startar om $TRAEFIK_CONTAINER..."
    docker restart "$TRAEFIK_CONTAINER"
    echo "  ✅ Traefik omstartad"
    echo "  Väntar 15 sekunder för att Traefik ska ladda om routing..."
    sleep 15
    
    echo ""
    echo "  📋 Traefik logs efter omstart:"
    docker logs "$TRAEFIK_CONTAINER" --tail 10 2>/dev/null | tail -10
else
    echo "  ⚠️  Traefik container hittades inte"
fi
REMOTE

# ============================================================================
# STEG 7: Starta om Services för att säkerställa anslutning
# ============================================================================
section "STEG 7: Startar om Services"

ssh "$HOST" bash <<'REMOTE'
echo "🔄 Startar om services för att säkerställa anslutning till Traefik..."
echo ""

if [ -d "/data/coolify/services" ]; then
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
# STEG 8: Verifiering
# ============================================================================
section "STEG 8: Verifiering"

echo "🔍 Testar externa endpoints..."
echo ""

for domain in "${domains[@]}"; do
    echo -n "  $domain: "
    HTTP_CODE=$(curl -I -s --max-time 10 "https://$domain" 2>/dev/null | head -1 | awk '{print $2}' || echo "000")
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
        info "Fungerar ($HTTP_CODE)"
    elif [ "$HTTP_CODE" = "404" ]; then
        error "404 Not Found"
    elif [ "$HTTP_CODE" = "503" ]; then
        warn "503 Service Unavailable"
    else
        warn "HTTP $HTTP_CODE"
    fi
done

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning & Nästa Steg"

echo ""
info "Routing-fix klar!"
echo ""
echo "💡 Om fortfarande 404-fel:"
echo ""
echo "1. Kontrollera DNS i Cloudflare:"
echo "   • Gå till Cloudflare Dashboard"
echo "   • Kontrollera att A-records pekar på: $SERVER_IP"
echo "   • Vänta 5-10 minuter för DNS-propagation"
echo ""
echo "2. Om Traefik API-fel kvarstår:"
echo "   ./scripts/fix-traefik-api.sh"
echo ""
echo "3. Om services saknar Traefik labels:"
echo "   • Öppna Coolify dashboard"
echo "   • Gå till varje service"
echo "   • Kontrollera att 'Domain' är konfigurerad"
echo "   • Klicka 'Redeploy'"
echo ""
echo "4. Starta om allt:"
echo "   ./scripts/restart-coolify.sh"
echo ""
echo "🔧 Ytterligare diagnostik:"
echo "  • Diagnostik: ./scripts/diagnose-404.sh"
echo "  • Verifiera allt: ./scripts/verify-all.sh"
echo ""


