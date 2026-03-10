#!/usr/bin/env bash
set -euo pipefail

# diagnose-404.sh - Systematisk felsökning av 404-fel efter serveromstart

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

echo "🔍 Systematisk Felsökning: 404-fel efter Serveromstart"
echo "======================================================"

# ============================================================================
# STEG 1: Server Status (Efter Omstart)
# ============================================================================
section "STEG 1: Server Status (Efter Omstart)"

echo "Kontrollerar serveranslutning..."

if ! ping -c 1 -W 2 "$SERVER_IP" &>/dev/null; then
    error "Servern svarar inte på ping"
    exit 1
fi
info "Server svarar på ping"

if ! ssh -o ConnectTimeout=5 "$HOST" 'echo "SSH OK"' &>/dev/null; then
    error "SSH-anslutning misslyckades"
    exit 1
fi
info "SSH-anslutning fungerar"

ssh "$HOST" bash <<'REMOTE'
echo ""
echo "📊 Server Status:"
echo "  OS: $(lsb_release -d | cut -f2)"
echo "  Kernel: $(uname -r)"
echo "  Uptime: $(uptime -p)"
echo "  Disk: $(df -h / | awk 'NR==2 {print $5 " used"}')"
echo "  Memory: $(free -h | awk 'NR==2 {print $3 "/" $2}')"
echo "  Load: $(uptime | awk -F'load average:' '{print $2}')"
REMOTE

# ============================================================================
# STEG 2: Docker Status
# ============================================================================
section "STEG 2: Docker Status"

ssh "$HOST" bash <<'REMOTE'
echo "🐳 Docker:"
echo ""

# Docker service
if systemctl is-active docker >/dev/null 2>&1; then
    echo "  ✅ Docker-tjänst körs"
    echo "  Version: $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
else
    echo "  ❌ Docker-tjänst körs INTE"
    echo "  Försöker starta..."
    systemctl start docker
    sleep 3
    if systemctl is-active docker >/dev/null 2>&1; then
        echo "  ✅ Docker startad"
    else
        echo "  ❌ Kunde inte starta Docker"
        exit 1
    fi
fi

echo ""
echo "📦 Containers:"
RUNNING=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)
STOPPED=$(docker ps -a --filter "status=exited" --format '{{.Names}}' 2>/dev/null | wc -l)
TOTAL=$(docker ps -a --format '{{.Names}}' 2>/dev/null | wc -l)
echo "  Körs: $RUNNING"
echo "  Stoppade: $STOPPED"
echo "  Totalt: $TOTAL"

if [ "$STOPPED" -gt 0 ]; then
    echo ""
    echo "  ⚠️  Stoppade containers:"
    docker ps -a --filter "status=exited" --format "    • {{.Names}}" 2>/dev/null | head -10
fi
REMOTE

# ============================================================================
# STEG 3: Coolify Status
# ============================================================================
section "STEG 3: Coolify Status"

ssh "$HOST" bash <<'REMOTE'
echo "🔧 Coolify Installation:"
echo ""

if [ -d "/data/coolify/source" ]; then
    echo "  ✅ Hittad i /data/coolify/source"
    cd /data/coolify/source
    
    echo ""
    echo "📋 Coolify Containers:"
    if docker compose version >/dev/null 2>&1; then
        docker compose ps 2>/dev/null || echo "  ⚠️  Kunde inte lista"
    else
        docker-compose ps 2>/dev/null || echo "  ⚠️  Kunde inte lista"
    fi
    
    echo ""
    echo "🔍 Coolify Container Status:"
    COOLIFY_CONTAINERS=$(docker ps -a --filter "name=coolify" --format '{{.Names}}' 2>/dev/null)
    if [ -n "$COOLIFY_CONTAINERS" ]; then
        while IFS= read -r container; do
            STATUS=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
            if [ "$STATUS" = "running" ]; then
                echo "  ✅ $container: körs"
            else
                echo "  ❌ $container: $STATUS"
            fi
        done <<< "$COOLIFY_CONTAINERS"
    else
        echo "  ⚠️  Inga Coolify-containers hittades"
    fi
else
    echo "  ❌ Coolify installation ej hittad i /data/coolify/source"
    echo "  Söker på andra platser..."
    find /opt /data -name "*coolify*" -type d 2>/dev/null | head -5 || echo "  Inga andra installationer hittades"
fi
REMOTE

# ============================================================================
# STEG 4: Traefik Proxy Status (KRITISKT)
# ============================================================================
section "STEG 4: Traefik Proxy Status (KRITISKT för 404-fel)"

ssh "$HOST" bash <<'REMOTE'
echo "🌐 Traefik Proxy:"
echo ""

# Hitta Traefik container
TRAEFIK_CONTAINER=$(docker ps -a --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)

if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps -a --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -z "$TRAEFIK_CONTAINER" ]; then
    # Sök efter traefik i image name
    TRAEFIK_CONTAINER=$(docker ps -a --filter "ancestor=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    STATUS=$(docker inspect --format='{{.State.Status}}' "$TRAEFIK_CONTAINER" 2>/dev/null || echo "unknown")
    echo "  Container: $TRAEFIK_CONTAINER"
    echo "  Status: $STATUS"
    
    if [ "$STATUS" != "running" ]; then
        echo ""
        echo "  ❌ Traefik körs INTE - detta orsakar 404-fel!"
        echo "  Försöker starta..."
        docker start "$TRAEFIK_CONTAINER" 2>/dev/null && echo "  ✅ Startad" || echo "  ❌ Kunde inte starta"
    else
        echo "  ✅ Traefik körs"
    fi
    
    echo ""
    echo "  📋 Traefik Logs (senaste 10 raderna):"
    docker logs "$TRAEFIK_CONTAINER" --tail 10 2>/dev/null | tail -10 || echo "  Kunde inte läsa logs"
else
    echo "  ❌ Traefik container hittades INTE!"
    echo "  Detta är troligen huvudorsaken till 404-fel!"
    echo ""
    echo "  Söker i /data/coolify/proxy..."
    if [ -d "/data/coolify/proxy" ]; then
        echo "  ✅ Hittade proxy directory"
        cd /data/coolify/proxy
        echo "  Försöker starta Traefik..."
        if docker compose version >/dev/null 2>&1; then
            docker compose up -d 2>/dev/null && echo "  ✅ Traefik startad" || echo "  ❌ Kunde inte starta"
        else
            docker-compose up -d 2>/dev/null && echo "  ✅ Traefik startad" || echo "  ❌ Kunde inte starta"
        fi
    else
        echo "  ❌ Proxy directory saknas"
    fi
fi
REMOTE

# ============================================================================
# STEG 5: Docker Network (Coolify)
# ============================================================================
section "STEG 5: Docker Network (Coolify)"

ssh "$HOST" bash <<'REMOTE'
echo "🌐 Docker Networks:"
echo ""

COOLIFY_NETWORK=$(docker network ls --filter "name=coolify" --format '{{.Name}}' 2>/dev/null | head -1)

if [ -n "$COOLIFY_NETWORK" ]; then
    echo "  ✅ Coolify network finns: $COOLIFY_NETWORK"
    echo ""
    echo "  Containers på network:"
    docker network inspect "$COOLIFY_NETWORK" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | tr ' ' '\n' | grep -v '^$' | head -10 || echo "  Inga containers"
else
    echo "  ❌ Coolify network saknas!"
    echo "  Detta kan orsaka att services inte kan nås"
    echo ""
    echo "  Alla networks:"
    docker network ls 2>/dev/null
fi
REMOTE

# ============================================================================
# STEG 6: Service Containers Status
# ============================================================================
section "STEG 6: Service Containers Status"

ssh "$HOST" bash <<'REMOTE'
echo "📦 Service Containers (utom Coolify core):"
echo ""

SERVICE_CONTAINERS=$(docker ps -a --format '{{.Names}}' 2>/dev/null | grep -v "coolify" | grep -v "traefik" | grep -v "postgres" || true)

if [ -n "$SERVICE_CONTAINERS" ]; then
    echo "Hittade service-containers:"
    echo ""
    while IFS= read -r container; do
        if [ -n "$container" ]; then
            STATUS=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
            IMAGE=$(docker inspect --format='{{.Config.Image}}' "$container" 2>/dev/null || echo "unknown")
            
            if [ "$STATUS" = "running" ]; then
                echo "  ✅ $container"
            else
                echo "  ❌ $container (Status: $STATUS)"
            fi
            echo "      Image: $IMAGE"
            echo ""
        fi
    done <<< "$SERVICE_CONTAINERS"
else
    echo "  ⚠️  Inga service-containers hittades"
fi
REMOTE

# ============================================================================
# STEG 7: Traefik Labels på Services
# ============================================================================
section "STEG 7: Traefik Labels på Services (Routing-konfiguration)"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Kontrollerar Traefik labels på services..."
echo ""

SERVICE_CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -v "coolify" | grep -v "traefik" | grep -v "postgres" | head -5)

if [ -n "$SERVICE_CONTAINERS" ]; then
    while IFS= read -r container; do
        if [ -n "$container" ]; then
            echo "📦 $container:"
            
            TRAEFIK_ENABLED=$(docker inspect "$container" --format '{{index .Config.Labels "traefik.enable"}}' 2>/dev/null || echo "")
            
            if [ "$TRAEFIK_ENABLED" = "true" ]; then
                echo "  ✅ traefik.enable=true"
                
                # Hitta router rule
                ROUTER_RULE=$(docker inspect "$container" --format '{{range $k, $v := .Config.Labels}}{{if or (eq $k "traefik.http.routers") (match $k "traefik.http.routers.*.rule")}}{{$k}}={{$v}}{{end}}{{end}}' 2>/dev/null | head -1)
                
                if [ -n "$ROUTER_RULE" ]; then
                    echo "  ✅ Router konfigurerad: $ROUTER_RULE"
                else
                    echo "  ⚠️  Router saknas eller felaktig"
                fi
                
                # Hitta port
                PORT=$(docker inspect "$container" --format '{{index .Config.Labels "traefik.http.services"}}' 2>/dev/null | grep -oE 'port=[0-9]+' | cut -d= -f2 || echo "")
                if [ -z "$PORT" ]; then
                    PORT=$(docker inspect "$container" --format '{{range $k, $v := .Config.Labels}}{{if match $k "traefik.http.services.*.loadbalancer.server.port"}}{{$v}}{{end}}{{end}}' 2>/dev/null | head -1)
                fi
                
                if [ -n "$PORT" ]; then
                    echo "  ✅ Port konfigurerad: $PORT"
                else
                    echo "  ⚠️  Port saknas"
                fi
            else
                echo "  ❌ traefik.enable saknas eller är false"
                echo "  Detta orsakar 404-fel!"
            fi
            echo ""
        fi
    done <<< "$SERVICE_CONTAINERS"
else
    echo "  ℹ️  Inga service-containers hittades"
fi
REMOTE

# ============================================================================
# STEG 8: DNS & Externa Endpoints
# ============================================================================
section "STEG 8: DNS & Externa Endpoints"

echo "🌐 DNS & HTTPS-tester:"
echo ""

domains=(
    "analytics.thehockeyanalytics.com"
    "coolify.theunnamedroads.com"
)

for domain in "${domains[@]}"; do
    echo -n "  $domain: "
    
    # DNS
    if nslookup "$domain" >/dev/null 2>&1; then
        DNS_IP=$(nslookup "$domain" 2>/dev/null | grep -A 1 "Name:" | tail -1 | awk '{print $2}' || echo "")
        if [ "$DNS_IP" = "$SERVER_IP" ]; then
            echo -n "DNS✅ "
        else
            echo -n "DNS⚠️ (pekar på $DNS_IP) "
        fi
    else
        echo -n "DNS❌ "
    fi
    
    # HTTPS
    if curl -I -s --max-time 10 "https://$domain" >/dev/null 2>&1; then
        HTTP_CODE=$(curl -I -s --max-time 10 "https://$domain" 2>/dev/null | head -1 | awk '{print $2}' || echo "")
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
            echo "HTTPS✅ ($HTTP_CODE)"
        else
            echo "HTTPS⚠️ ($HTTP_CODE)"
        fi
    else
        echo "HTTPS❌"
    fi
done

# ============================================================================
# STEG 9: Portar & Connectivity
# ============================================================================
section "STEG 9: Portar & Connectivity"

ssh "$HOST" bash <<'REMOTE'
echo "🔌 Öppna portar:"
echo ""

# Kolla port 80 och 443
if netstat -tlnp 2>/dev/null | grep -q ":80 "; then
    echo "  ✅ Port 80 är öppen"
else
    echo "  ⚠️  Port 80 är inte öppen"
fi

if netstat -tlnp 2>/dev/null | grep -q ":443 "; then
    echo "  ✅ Port 443 är öppen"
else
    echo "  ⚠️  Port 443 är inte öppen"
fi

echo ""
echo "🌐 Traefik portar:"
TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_PORTS=$(docker port "$TRAEFIK_CONTAINER" 2>/dev/null || echo "")
    if [ -n "$TRAEFIK_PORTS" ]; then
        echo "$TRAEFIK_PORTS" | while read -r line; do
            echo "  $line"
        done
    else
        echo "  ⚠️  Inga portar exponerade"
    fi
fi
REMOTE

# ============================================================================
# SAMMANFATTNING & REKOMMENDATIONER
# ============================================================================
section "📊 SAMMANFATTNING & REKOMMENDATIONER"

echo ""
echo "🔍 Identifierade problem och lösningar:"
echo ""

ssh "$HOST" bash <<'REMOTE'
# Kolla Traefik
TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -z "$TRAEFIK_CONTAINER" ] || [ "$(docker inspect --format='{{.State.Status}}' "$TRAEFIK_CONTAINER" 2>/dev/null)" != "running" ]; then
    echo "❌ PROBLEM: Traefik körs inte"
    echo "   LÖSNING: ./scripts/fix-404.sh"
    echo ""
fi

# Kolla network
COOLIFY_NETWORK=$(docker network ls --filter "name=coolify" --format '{{.Name}}' 2>/dev/null | head -1)
if [ -z "$COOLIFY_NETWORK" ]; then
    echo "❌ PROBLEM: Coolify network saknas"
    echo "   LÖSNING: Starta om Coolify: ./scripts/restart-coolify.sh"
    echo ""
fi

# Kolla services
STOPPED_SERVICES=$(docker ps -a --filter "status=exited" --format '{{.Names}}' 2>/dev/null | grep -v "coolify" | grep -v "traefik" | grep -v "postgres" | wc -l)
if [ "$STOPPED_SERVICES" -gt 0 ]; then
    echo "⚠️  PROBLEM: $STOPPED_SERVICES service(s) är stoppade"
    echo "   LÖSNING: ./scripts/fix-services.sh"
    echo ""
fi
REMOTE

echo ""
echo "💡 Rekommenderade åtgärder (i ordning):"
echo ""

ssh "$HOST" bash <<'REMOTE'
# Kolla om det finns Traefik API-fel
TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    API_ERROR=$(docker logs "$TRAEFIK_CONTAINER" 2>/dev/null | grep -i "client version.*too old" | tail -1 || echo "")
    if [ -n "$API_ERROR" ]; then
        echo "1. ⚠️  KRITISKT: Traefik Docker API version mismatch"
        echo "   ./scripts/fix-traefik-api.sh"
        echo ""
    fi
fi
REMOTE

echo "2. Om Traefik inte körs:"
echo "   ./scripts/fix-404.sh"
echo ""
echo "3. Om services är stoppade:"
echo "   ./scripts/fix-services.sh"
echo ""
echo "4. Om allt är oklart, starta om allt:"
echo "   ./scripts/restart-coolify.sh"
echo ""
echo "5. Efter fix, verifiera:"
echo "   ./scripts/verify-all.sh"
echo ""

