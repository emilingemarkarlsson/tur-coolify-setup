#!/usr/bin/env bash
set -euo pipefail

# fix-404.sh - Fixar 404-fel när services körs men inte nårs via Traefik

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

echo "🔧 Felsökning: 404-fel på services"
echo "=================================="

# ============================================================================
# STEG 1: Kontrollera Traefik Status
# ============================================================================
section "1️⃣  Traefik Proxy Status"

ssh "$HOST" bash <<'REMOTE'
echo "🌐 Traefik (Coolify Proxy):"
echo ""

# Hitta Traefik container
TRAEFIK_CONTAINER=$(docker ps -a --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)

if [ -z "$TRAEFIK_CONTAINER" ]; then
    # Prova coolify-proxy
    TRAEFIK_CONTAINER=$(docker ps -a --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -z "$TRAEFIK_CONTAINER" ]; then
    # Prova att söka efter traefik i image name
    TRAEFIK_CONTAINER=$(docker ps -a --filter "ancestor=traefik" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    STATUS=$(docker inspect --format='{{.State.Status}}' "$TRAEFIK_CONTAINER" 2>/dev/null || echo "unknown")
    echo "  Container: $TRAEFIK_CONTAINER"
    echo "  Status: $STATUS"
    
    if [ "$STATUS" != "running" ]; then
        echo ""
        echo "  ⚠️  Traefik körs INTE - startar..."
        docker start "$TRAEFIK_CONTAINER" 2>/dev/null && echo "  ✅ Startad" || echo "  ❌ Kunde inte starta"
        sleep 2
    else
        echo "  ✅ Traefik körs"
    fi
else
    echo "  ❌ Traefik container hittades inte!"
    echo "  Söker i /data/coolify/proxy..."
    
    if [ -d "/data/coolify/proxy" ]; then
        echo "  Hittade proxy directory - startar om..."
        cd /data/coolify/proxy
        docker compose up -d 2>/dev/null && echo "  ✅ Startad" || echo "  ❌ Kunde inte starta"
    fi
fi
REMOTE

# ============================================================================
# STEG 2: Kontrollera Traefik Logs
# ============================================================================
section "2️⃣  Traefik Logs (senaste 20 raderna)"

ssh "$HOST" bash <<'REMOTE'
TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)

if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    echo "Logs för $TRAEFIK_CONTAINER:"
    docker logs "$TRAEFIK_CONTAINER" --tail 20 2>/dev/null | tail -20
else
    echo "⚠️  Traefik container hittades inte för loggning"
fi
REMOTE

# ============================================================================
# STEG 3: Kontrollera Docker Network
# ============================================================================
section "3️⃣  Docker Network (Coolify)"

ssh "$HOST" bash <<'REMOTE'
echo "🌐 Coolify Network:"
echo ""

COOLIFY_NETWORK=$(docker network ls --filter "name=coolify" --format '{{.Name}}' 2>/dev/null | head -1)

if [ -n "$COOLIFY_NETWORK" ]; then
    echo "  ✅ Network finns: $COOLIFY_NETWORK"
    echo ""
    echo "  Containers på network:"
    docker network inspect "$COOLIFY_NETWORK" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | tr ' ' '\n' | grep -v '^$' | head -10
else
    echo "  ❌ Coolify network saknas!"
    echo "  Detta är troligen problemet - services kan inte nås"
fi
REMOTE

# ============================================================================
# STEG 4: Kontrollera Service Labels (Traefik routing)
# ============================================================================
section "4️⃣  Service Labels (Traefik Routing)"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Kontrollerar Traefik labels på services..."
echo ""

# Hitta service containers (inte coolify core)
SERVICE_CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -v "coolify" | grep -v "traefik" | grep -v "postgres" | head -5)

if [ -n "$SERVICE_CONTAINERS" ]; then
    while IFS= read -r container; do
        if [ -n "$container" ]; then
            echo "📦 $container:"
            
            # Kolla Traefik labels
            TRAEFIK_ENABLED=$(docker inspect "$container" --format '{{index .Config.Labels "traefik.enable"}}' 2>/dev/null || echo "")
            ROUTER_RULE=$(docker inspect "$container" --format '{{index .Config.Labels "traefik.http.routers"}}' 2>/dev/null || echo "")
            
            if [ "$TRAEFIK_ENABLED" = "true" ]; then
                echo "  ✅ traefik.enable=true"
                
                # Hitta router name
                ROUTER_NAME=$(docker inspect "$container" --format '{{range $k, $v := .Config.Labels}}{{if eq $k "traefik.http.routers"}}{{$v}}{{end}}{{end}}' 2>/dev/null | head -1)
                
                if [ -n "$ROUTER_NAME" ]; then
                    echo "  ✅ Router konfigurerad"
                else
                    echo "  ⚠️  Router saknas eller felaktig"
                fi
            else
                echo "  ⚠️  traefik.enable saknas eller är false"
                echo "  Detta kan orsaka 404-fel!"
            fi
            echo ""
        fi
    done <<< "$SERVICE_CONTAINERS"
else
    echo "  ℹ️  Inga service-containers hittades"
fi
REMOTE

# ============================================================================
# STEG 5: Starta Om Traefik
# ============================================================================
section "5️⃣  Starta Om Traefik"

echo "🔄 Startar om Traefik för att ladda om routing-konfiguration..."
echo ""

ssh "$HOST" bash <<'REMOTE'
TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)

if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    echo "Startar om $TRAEFIK_CONTAINER..."
    docker restart "$TRAEFIK_CONTAINER" 2>/dev/null && echo "✅ Traefik omstartad" || echo "❌ Kunde inte starta om"
    sleep 3
else
    echo "⚠️  Traefik container hittades inte"
    
    # Prova att starta från proxy directory
    if [ -d "/data/coolify/proxy" ]; then
        echo "Försöker starta från /data/coolify/proxy..."
        cd /data/coolify/proxy
        docker compose down 2>/dev/null
        docker compose up -d 2>/dev/null && echo "✅ Traefik startad" || echo "❌ Kunde inte starta"
    fi
fi
REMOTE

# ============================================================================
# STEG 6: Kontrollera Service Ports
# ============================================================================
section "6️⃣  Service Ports & Connectivity"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Kontrollerar service ports..."
echo ""

SERVICE_CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -v "coolify" | grep -v "traefik" | grep -v "postgres" | head -5)

if [ -n "$SERVICE_CONTAINERS" ]; then
    while IFS= read -r container; do
        if [ -n "$container" ]; then
            echo "📦 $container:"
            
            # Hitta port
            PORT=$(docker inspect "$container" --format '{{range $p, $conf := .NetworkSettings.Ports}}{{range $conf}}{{$p}}{{end}}{{end}}' 2>/dev/null | grep -oE '[0-9]+' | head -1)
            
            if [ -n "$PORT" ]; then
                echo "  Port: $PORT"
                
                # Testa om port är öppen internt
                if docker exec "$container" sh -c "nc -z localhost $PORT" 2>/dev/null; then
                    echo "  ✅ Port $PORT är öppen internt"
                else
                    echo "  ⚠️  Port $PORT svarar inte internt"
                fi
            else
                echo "  ⚠️  Ingen port hittad"
            fi
            echo ""
        fi
    done <<< "$SERVICE_CONTAINERS"
fi
REMOTE

# ============================================================================
# STEG 7: Verifiera Efter Fix
# ============================================================================
section "7️⃣  Verifiering"

ssh "$HOST" bash <<'REMOTE'
echo "📊 Status efter fix:"
echo ""

TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1)

if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps --filter "name=proxy" --format '{{.Names}}' 2>/dev/null | head -1)
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    STATUS=$(docker inspect --format='{{.State.Status}}' "$TRAEFIK_CONTAINER" 2>/dev/null || echo "unknown")
    if [ "$STATUS" = "running" ]; then
        echo "  ✅ Traefik körs: $TRAEFIK_CONTAINER"
    else
        echo "  ⚠️  Traefik status: $STATUS"
    fi
else
    echo "  ❌ Traefik hittades inte"
fi

echo ""
echo "📦 Service-containers:"
SERVICE_COUNT=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -v "coolify" | grep -v "traefik" | grep -v "postgres" | wc -l)
echo "  Antal: $SERVICE_COUNT"
REMOTE

# ============================================================================
# SAMMANFATTNING & NÄSTA STEG
# ============================================================================
section "📊 Sammanfattning & Nästa Steg"

echo ""
info "Felsökning klar!"
echo ""
echo "💡 Nästa steg:"
echo "  1. Vänta 30 sekunder för att Traefik ska ladda om routing"
echo "  2. Testa att öppna services igen"
echo "  3. Om fortfarande 404, kontrollera:"
echo "     • DNS pekar på rätt IP (46.62.206.47)"
echo "     • Service har rätt Traefik labels i docker-compose.yml"
echo "     • Service är på 'coolify' network"
echo ""
echo "🔧 Ytterligare felsökning:"
echo "  • Traefik logs: ssh $HOST 'docker logs coolify-proxy --tail 50'"
echo "  • Service logs: ssh $HOST 'docker logs <container-name>'"
echo "  • Lista resurser: ./scripts/list-coolify-resources.sh"
echo "  • Testa endpoints: ./scripts/diagnose.sh"
echo ""
echo "📝 Kontrollera Traefik labels i docker-compose.yml:"
echo "  Services behöver ha:"
echo "    - traefik.enable=true"
echo "    - traefik.http.routers.<name>.rule=Host(\`domain.com\`)"
echo "    - traefik.http.routers.<name>.entrypoints=https"
echo "    - traefik.http.routers.<name>.tls=true"
echo "    - traefik.http.services.<name>.loadbalancer.server.port=<port>"
echo ""


