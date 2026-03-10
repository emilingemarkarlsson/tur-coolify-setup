#!/usr/bin/env bash
set -euo pipefail

# fix-coolify-dashboard.sh - Fixar Coolify dashboard routing

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

echo "🔧 Fixar Coolify Dashboard Routing"
echo "=================================="

# ============================================================================
# STEG 1: Kontrollera Coolify Containers
# ============================================================================
section "STEG 1: Kontrollerar Coolify Containers"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Coolify Containers:"
echo ""

COOLIFY_CONTAINERS=$(docker ps --filter "name=coolify" --format '{{.Names}}' 2>/dev/null | grep -v "proxy" | grep -v "db" || true)

if [ -n "$COOLIFY_CONTAINERS" ]; then
    echo "  Coolify-containers:"
    while IFS= read -r container; do
        if [ -n "$container" ]; then
            STATUS=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
            echo "    • $container: $STATUS"
        fi
    done <<< "$COOLIFY_CONTAINERS"
else
    echo "  ⚠️  Inga Coolify-containers hittades"
fi

echo ""
echo "  📋 Alla Coolify-relaterade containers:"
docker ps --filter "name=coolify" --format "    • {{.Names}} ({{.Status}})" 2>/dev/null
REMOTE

# ============================================================================
# STEG 2: Kontrollera Coolify på Network
# ============================================================================
section "STEG 2: Kontrollerar Coolify på coolify Network"

ssh "$HOST" bash <<'REMOTE'
echo "🌐 Coolify Network:"
echo ""

COOLIFY_NETWORK=$(docker network ls --filter "name=coolify" --format '{{.Name}}' 2>/dev/null | head -1)

if [ -n "$COOLIFY_NETWORK" ]; then
    echo "  Network: $COOLIFY_NETWORK"
    echo ""
    echo "  Coolify-containers på network:"
    COOLIFY_ON_NETWORK=$(docker network inspect "$COOLIFY_NETWORK" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | tr ' ' '\n' | grep "coolify" | grep -v "proxy" | grep -v "db" || true)
    
    if [ -n "$COOLIFY_ON_NETWORK" ]; then
        echo "$COOLIFY_ON_NETWORK" | while read -r container; do
            if [ -n "$container" ]; then
                echo "    ✅ $container"
            fi
        done
    else
        echo "    ⚠️  Inga Coolify-containers på network!"
        echo "    Detta kan orsaka att dashboard inte når"
    fi
else
    echo "  ❌ Coolify network saknas!"
fi
REMOTE

# ============================================================================
# STEG 3: Kontrollera Traefik Labels på Coolify
# ============================================================================
section "STEG 3: Kontrollerar Traefik Labels på Coolify"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Traefik Labels på Coolify-containers:"
echo ""

# Hitta huvudcontainern (coolify, inte coolify-sentinel)
COOLIFY_CONTAINER=$(docker ps --filter "name=^coolify$" --format '{{.Names}}' 2>/dev/null | head -1)
if [ -z "$COOLIFY_CONTAINER" ]; then
    # Fallback: hitta coolify-containern (inte sentinel)
    COOLIFY_CONTAINER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E "^coolify$" | head -1)
fi

if [ -n "$COOLIFY_CONTAINER" ]; then
    echo "  Container: $COOLIFY_CONTAINER"
    echo ""
    
    # Hämta Traefik labels
    TRAEFIK_ENABLED=$(docker inspect "$COOLIFY_CONTAINER" --format '{{index .Config.Labels "traefik.enable"}}' 2>/dev/null || echo "")
    
    if [ "$TRAEFIK_ENABLED" = "true" ]; then
        echo "  ✅ traefik.enable=true"
        
        # Hitta router rule
        ROUTER_RULE=$(docker inspect "$COOLIFY_CONTAINER" --format '{{range $k, $v := .Config.Labels}}{{if match $k "traefik.http.routers.*.rule"}}{{$k}}={{$v}}{{println}}{{end}}{{end}}' 2>/dev/null | head -1)
        
        if [ -n "$ROUTER_RULE" ]; then
            echo "  ✅ Router konfigurerad: $ROUTER_RULE"
        else
            echo "  ❌ Router saknas - detta orsakar att dashboard inte når!"
        fi
        
        # Visa alla Traefik labels
        echo ""
        echo "  📋 Alla Traefik labels:"
        docker inspect "$COOLIFY_CONTAINER" --format '{{range $k, $v := .Config.Labels}}{{if match $k "traefik.*"}}{{$k}}={{$v}}{{println}}{{end}}{{end}}' 2>/dev/null | head -10
    else
        echo "  ❌ traefik.enable saknas eller är false"
        echo "  Detta orsakar att dashboard inte når!"
    fi
else
    echo "  ❌ Coolify container hittades inte"
fi
REMOTE

# ============================================================================
# STEG 4: Anslut Coolify till Network om nödvändigt
# ============================================================================
section "STEG 4: Säkerställer att Coolify är på Network"

ssh "$HOST" bash <<'REMOTE'
echo "🌐 Ansluter Coolify till network om nödvändigt..."
echo ""

COOLIFY_NETWORK=$(docker network ls --filter "name=coolify" --format '{{.Name}}' 2>/dev/null | head -1)

if [ -n "$COOLIFY_NETWORK" ]; then
    COOLIFY_CONTAINER=$(docker ps --filter "name=coolify" --format '{{.Names}}' 2>/dev/null | grep -v "proxy" | grep -v "db" | grep -v "realtime" | grep -v "redis" | head -1)
    
    if [ -n "$COOLIFY_CONTAINER" ]; then
        ON_NETWORK=$(docker network inspect "$COOLIFY_NETWORK" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | grep -o "$COOLIFY_CONTAINER" || echo "")
        
        if [ -z "$ON_NETWORK" ]; then
            echo "  📦 Ansluter $COOLIFY_CONTAINER till $COOLIFY_NETWORK..."
            docker network connect "$COOLIFY_NETWORK" "$COOLIFY_CONTAINER" 2>/dev/null && echo "    ✅ Ansluten" || echo "    ⚠️  Kunde inte ansluta"
        else
            echo "  ✅ $COOLIFY_CONTAINER är redan på network"
        fi
    fi
fi
REMOTE

# ============================================================================
# STEG 5: Starta om Coolify
# ============================================================================
section "STEG 5: Startar om Coolify"

ssh "$HOST" bash <<'REMOTE'
echo "🔄 Startar om Coolify..."
echo ""

if [ -d "/data/coolify/source" ]; then
    cd /data/coolify/source
    
    COOLIFY_CONTAINER=$(docker ps --filter "name=coolify" --format '{{.Names}}' 2>/dev/null | grep -v "proxy" | grep -v "db" | grep -v "realtime" | grep -v "redis" | head -1)
    
    if [ -n "$COOLIFY_CONTAINER" ]; then
        echo "  Startar om $COOLIFY_CONTAINER..."
        docker restart "$COOLIFY_CONTAINER" 2>/dev/null && echo "    ✅ Omstartad" || echo "    ⚠️  Kunde inte starta om"
    else
        echo "  ⚠️  Coolify container hittades inte"
        echo "  Försöker starta om via docker compose..."
        
        if docker compose version >/dev/null 2>&1; then
            docker compose restart coolify 2>/dev/null || docker compose restart 2>/dev/null
        else
            docker-compose restart coolify 2>/dev/null || docker-compose restart 2>/dev/null
        fi
    fi
    
    echo "  Väntar 15 sekunder..."
    sleep 15
else
    echo "  ⚠️  /data/coolify/source directory saknas"
fi
REMOTE

# ============================================================================
# STEG 6: Starta om Traefik för att ladda om routing
# ============================================================================
section "STEG 6: Startar om Traefik för att ladda om routing"

ssh "$HOST" bash <<'REMOTE'
echo "🔄 Startar om Traefik..."
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
else
    echo "  ⚠️  Traefik container hittades inte"
fi
REMOTE

# ============================================================================
# STEG 7: Verifiera Coolify Dashboard
# ============================================================================
section "STEG 7: Verifierar Coolify Dashboard"

echo "🔍 Testar Coolify dashboard..."
echo ""

COOLIFY_URL="https://coolify.theunnamedroads.com"
HTTP_CODE=$(curl -I -s --max-time 10 "$COOLIFY_URL" 2>/dev/null | head -1 | awk '{print $2}' || echo "000")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
    info "Coolify dashboard nåbar ($HTTP_CODE)"
    echo "  Öppna: $COOLIFY_URL"
else
    warn "Coolify dashboard når inte ännu ($HTTP_CODE)"
    echo ""
    echo "  💡 Möjliga orsaker:"
    echo "     • Coolify saknar Traefik labels"
    echo "     • Coolify är inte på coolify network"
    echo "     • Traefik routing har inte laddats om"
    echo ""
    echo "  🔧 Nästa steg:"
    echo "     1. Kontrollera Coolify i dashboard (om du kan nå den via IP)"
    echo "     2. Gå till Settings → Server → Proxy"
    echo "     3. Kontrollera att 'Domain' är konfigurerad"
    echo "     4. Klicka 'Redeploy' på Coolify"
fi

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning"

echo ""
info "Coolify dashboard-fix klar!"
echo ""
echo "💡 Om dashboard fortfarande inte når:"
echo ""
echo "1. Kontrollera Coolify via IP (om möjligt):"
echo "   ssh tha 'docker ps | grep coolify'"
echo ""
echo "2. Om du kan nå Coolify via IP men inte via domän:"
echo "   • Coolify saknar Traefik labels"
echo "   • Gå till Coolify dashboard (via IP om möjligt)"
echo "   • Settings → Server → Proxy"
echo "   • Kontrollera att 'Domain' är konfigurerad: coolify.theunnamedroads.com"
echo "   • Klicka 'Redeploy' på Coolify"
echo ""
echo "3. Om 503 kvarstår (Coolify saknar Traefik labels):"
echo "   ./scripts/fix-coolify-503.sh"
echo ""
echo "4. Om inget fungerar:"
echo "   • Starta om allt: ./scripts/restart-coolify.sh"
echo "   • Diagnostik: ./scripts/diagnose-404.sh"
echo ""

