#!/usr/bin/env bash
set -euo pipefail

# diagnose-langflow-complete.sh - Komplett diagnostik av Langflow

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

echo "🔍 Komplett Diagnostik av Langflow"
echo "==================================="
echo ""

ssh "$HOST" bash <<'REMOTE'
CONTAINER="langflow-rog04sw8kcc0g848cs4cocso"
DOMAIN="langflow-rog04sw8kcc0g848cs4cocso.46.62.206.47.sslip.io"
SERVICE_DIR="/data/coolify/services/rog04sw8kcc0g848cs4cocso"

section "1️⃣  CONTAINER STATUS"
echo ""

if docker ps --filter "name=$CONTAINER" --format '{{.Names}}' | grep -q "$CONTAINER"; then
    STATUS=$(docker ps --filter "name=$CONTAINER" --format '{{.State.Status}}')
    HEALTH=$(docker inspect "$CONTAINER" --format '{{.State.Health.Status}}' 2>/dev/null || echo "no-healthcheck")
    
    echo "Container: $CONTAINER"
    echo "Status: $STATUS"
    echo "Health: $HEALTH"
    
    if [ "$STATUS" = "running" ]; then
        echo "✅ Container körs"
    else
        echo "❌ Container körs inte"
    fi
    
    if [ "$HEALTH" = "healthy" ]; then
        echo "✅ Container är healthy"
    elif [ "$HEALTH" = "no-healthcheck" ]; then
        echo "⚠️  Ingen healthcheck konfigurerad"
    else
        echo "⚠️  Health status: $HEALTH"
    fi
else
    echo "❌ Container hittades inte: $CONTAINER"
    echo ""
    echo "💡 Lista alla langflow-containers:"
    docker ps -a | grep langflow | sed 's/^/  /'
fi

section "2️⃣  PORT 7860 - INTERN TEST"
echo ""

if docker ps --filter "name=$CONTAINER" --format '{{.Names}}' | grep -q "$CONTAINER"; then
    echo "Testar port 7860 direkt i containern..."
    if docker exec "$CONTAINER" curl -sf http://127.0.0.1:7860 >/dev/null 2>&1; then
        echo "✅ Port 7860 svarar i containern"
        
        # Hämta response
        RESPONSE=$(docker exec "$CONTAINER" curl -s http://127.0.0.1:7860 2>/dev/null | head -20 || echo "")
        if [ -n "$RESPONSE" ]; then
            echo "✅ Fick response från Langflow"
            echo "   (Första 100 tecknen: ${RESPONSE:0:100}...)"
        fi
    else
        echo "❌ Port 7860 svarar INTE i containern"
        echo ""
        echo "📋 Container logs (senaste 30 raderna):"
        docker logs "$CONTAINER" --tail 30 2>/dev/null | sed 's/^/  /' || echo "  Kunde inte hämta logs"
    fi
else
    echo "❌ Container körs inte - kan inte testa port"
fi

section "3️⃣  TRAEFIK LABELS"
echo ""

if docker ps -a --filter "name=$CONTAINER" --format '{{.Names}}' | grep -q "$CONTAINER"; then
    TRAEFIK_ENABLE=$(docker inspect "$CONTAINER" --format '{{index .Config.Labels "traefik.enable"}}' 2>/dev/null || echo "")
    RULE_HTTPS=$(docker inspect "$CONTAINER" --format '{{index .Config.Labels "traefik.http.routers.langflow.rule"}}' 2>/dev/null || echo "")
    RULE_HTTP=$(docker inspect "$CONTAINER" --format '{{index .Config.Labels "traefik.http.routers.langflow-http.rule"}}' 2>/dev/null || echo "")
    PORT=$(docker inspect "$CONTAINER" --format '{{index .Config.Labels "traefik.http.services.langflow.loadbalancer.server.port"}}' 2>/dev/null || echo "")
    ENTRYPOINT_HTTPS=$(docker inspect "$CONTAINER" --format '{{index .Config.Labels "traefik.http.routers.langflow.entrypoints"}}' 2>/dev/null || echo "")
    ENTRYPOINT_HTTP=$(docker inspect "$CONTAINER" --format '{{index .Config.Labels "traefik.http.routers.langflow-http.entrypoints"}}' 2>/dev/null || echo "")
    
    if [ "$TRAEFIK_ENABLE" = "true" ]; then
        echo "✅ traefik.enable=true"
    else
        echo "❌ traefik.enable saknas eller är false"
    fi
    
    if [ -n "$RULE_HTTPS" ]; then
        echo "✅ HTTPS Router rule: $RULE_HTTPS"
        if echo "$RULE_HTTPS" | grep -q "$DOMAIN"; then
            echo "   ✅ Domain matchar"
        else
            echo "   ⚠️  Domain matchar inte! Förväntad: $DOMAIN"
        fi
    else
        echo "❌ HTTPS Router rule saknas"
    fi
    
    if [ -n "$RULE_HTTP" ]; then
        echo "✅ HTTP Router rule: $RULE_HTTP"
    else
        echo "⚠️  HTTP Router rule saknas (behövs för sslip.io)"
    fi
    
    if [ -n "$ENTRYPOINT_HTTPS" ]; then
        echo "✅ HTTPS Entrypoint: $ENTRYPOINT_HTTPS"
    else
        echo "⚠️  HTTPS Entrypoint saknas"
    fi
    
    if [ -n "$ENTRYPOINT_HTTP" ]; then
        echo "✅ HTTP Entrypoint: $ENTRYPOINT_HTTP"
    else
        echo "⚠️  HTTP Entrypoint saknas (behövs för sslip.io)"
    fi
    
    if [ -n "$PORT" ]; then
        echo "✅ Port: $PORT"
        if [ "$PORT" = "7860" ]; then
            echo "   ✅ Port är korrekt"
        else
            echo "   ⚠️  Port är fel! Förväntad: 7860, Faktisk: $PORT"
        fi
    else
        echo "❌ Port saknas"
    fi
    
    echo ""
    echo "📋 Alla Traefik labels:"
    docker inspect "$CONTAINER" --format '{{range $k, $v := .Config.Labels}}{{if match $k "traefik.*"}}{{$k}}={{$v}}{{println}}{{end}}{{end}}' 2>/dev/null | sed 's/^/  /' || echo "  Inga Traefik labels"
else
    echo "❌ Kan inte kontrollera labels - container finns inte"
fi

section "4️⃣  NETWORK"
echo ""

if docker ps -a --filter "name=$CONTAINER" --format '{{.Names}}' | grep -q "$CONTAINER"; then
    NETWORKS=$(docker inspect "$CONTAINER" --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}' 2>/dev/null || echo "")
    
    echo "Container networks: $NETWORKS"
    echo ""
    
    if echo "$NETWORKS" | grep -q "coolify"; then
        echo "✅ Container är ansluten till coolify-nätverket"
        
        # Kontrollera IP
        COOLIFY_IP=$(docker inspect "$CONTAINER" --format '{{range $net, $conf := .NetworkSettings.Networks}}{{if eq $net "coolify"}}{{$conf.IPAddress}}{{end}}{{end}}' 2>/dev/null || echo "")
        if [ -n "$COOLIFY_IP" ]; then
            echo "   IP i coolify-nätverket: $COOLIFY_IP"
        fi
    else
        echo "❌ Container är INTE ansluten till coolify-nätverket"
        echo "   Nuvarande nätverk: $NETWORKS"
    fi
    
    # Kontrollera om coolify-nätverket finns
    if docker network inspect coolify >/dev/null 2>&1; then
        echo "✅ coolify-nätverket finns"
    else
        echo "❌ coolify-nätverket finns INTE"
    fi
else
    echo "❌ Kan inte kontrollera network - container finns inte"
fi

section "5️⃣  TRAEFIK STATUS"
echo ""

# Hitta Traefik container
TRAEFIK_CONTAINER=$(docker ps -a --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1 || echo "")

if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps -a --filter "name=coolify-proxy" --format '{{.Names}}' 2>/dev/null | head -1 || echo "")
fi

if [ -z "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_CONTAINER=$(docker ps -a --filter "ancestor=traefik" --format '{{.Names}}' 2>/dev/null | head -1 || echo "")
fi

if [ -n "$TRAEFIK_CONTAINER" ]; then
    TRAEFIK_STATUS=$(docker ps --filter "name=$TRAEFIK_CONTAINER" --format '{{.State.Status}}' 2>/dev/null || echo "stopped")
    
    echo "Traefik container: $TRAEFIK_CONTAINER"
    echo "Status: $TRAEFIK_STATUS"
    echo ""
    
    if [ "$TRAEFIK_STATUS" = "running" ]; then
        echo "✅ Traefik körs"
        
        # Testa om Traefik kan nå containern
        echo ""
        echo "Testar om Traefik kan nå Langflow container..."
        CONTAINER_IP=$(docker inspect "$CONTAINER" --format '{{range $net, $conf := .NetworkSettings.Networks}}{{if eq $net "coolify"}}{{$conf.IPAddress}}{{end}}{{end}}' 2>/dev/null || echo "")
        
        if [ -n "$CONTAINER_IP" ]; then
            echo "Container IP: $CONTAINER_IP"
            if docker exec "$TRAEFIK_CONTAINER" wget -qO- --timeout=2 "http://$CONTAINER_IP:7860" >/dev/null 2>&1; then
                echo "✅ Traefik kan nå containern på $CONTAINER_IP:7860"
            else
                echo "❌ Traefik kan INTE nå containern på $CONTAINER_IP:7860"
            fi
        else
            echo "⚠️  Kunde inte hitta container IP i coolify-nätverket"
        fi
        
        echo ""
        echo "📋 Traefik logs (senaste 30 raderna med langflow eller $DOMAIN):"
        docker logs "$TRAEFIK_CONTAINER" --tail 100 2>/dev/null | grep -iE "langflow|$DOMAIN|rog04sw8kcc0g848cs4cocso" | tail -10 | sed 's/^/  /' || echo "  Inga relevanta loggmeddelanden"
        
        echo ""
        echo "📋 Traefik routing table (letar efter langflow):"
        docker exec "$TRAEFIK_CONTAINER" wget -qO- http://localhost:8080/api/http/routers 2>/dev/null | grep -i langflow | head -5 | sed 's/^/  /' || echo "  Kunde inte hämta routing table (Traefik API kan vara inaktiverad)"
    else
        echo "❌ Traefik körs INTE (status: $TRAEFIK_STATUS)"
        echo ""
        echo "📋 Traefik logs (senaste 20 raderna):"
        docker logs "$TRAEFIK_CONTAINER" --tail 20 2>/dev/null | sed 's/^/  /' || echo "  Kunde inte hämta logs"
    fi
else
    echo "❌ Traefik container hittades inte"
    echo ""
    echo "💡 Lista alla containers:"
    docker ps -a | head -10 | sed 's/^/  /'
fi

section "6️⃣  DOCKER-COMPOSE.YML"
echo ""

if [ -f "$SERVICE_DIR/docker-compose.yml" ]; then
    echo "✅ docker-compose.yml finns"
    echo ""
    echo "📋 Traefik labels i filen:"
    grep -A 15 "labels:" "$SERVICE_DIR/docker-compose.yml" 2>/dev/null | sed 's/^/  /' || echo "  Inga labels hittades"
    echo ""
    echo "📋 Networks i filen:"
    grep -A 5 "networks:" "$SERVICE_DIR/docker-compose.yml" 2>/dev/null | sed 's/^/  /' || echo "  Inga networks hittades"
else
    echo "❌ docker-compose.yml saknas: $SERVICE_DIR"
fi

section "7️⃣  TEST FRÅN SERVER"
echo ""

echo "Testar URL från servern..."
echo ""

# Testa HTTP direkt
echo "Test 1: HTTP direkt mot containern (via IP):"
CONTAINER_IP=$(docker inspect "$CONTAINER" --format '{{range $net, $conf := .NetworkSettings.Networks}}{{if eq $net "coolify"}}{{$conf.IPAddress}}{{end}}{{end}}' 2>/dev/null || echo "")
if [ -n "$CONTAINER_IP" ]; then
    if curl -sf --max-time 5 "http://$CONTAINER_IP:7860" >/dev/null 2>&1; then
        echo "✅ Container svarar på http://$CONTAINER_IP:7860"
    else
        echo "❌ Container svarar INTE på http://$CONTAINER_IP:7860"
    fi
else
    echo "⚠️  Kunde inte hitta container IP"
fi

echo ""
echo "Test 2: HTTP via Traefik (localhost med Host header):"
if curl -sf --max-time 5 -H "Host: $DOMAIN" http://localhost >/dev/null 2>&1; then
    echo "✅ Traefik routar korrekt till Langflow"
    echo ""
    echo "   Response (första 200 tecknen):"
    curl -s --max-time 5 -H "Host: $DOMAIN" http://localhost 2>/dev/null | head -c 200
    echo ""
else
    echo "❌ Traefik routar INTE korrekt"
    echo ""
    echo "   Testar med curl verbose:"
    curl -v --max-time 5 -H "Host: $DOMAIN" http://localhost 2>&1 | grep -E "HTTP|Host|Connection" | head -10 | sed 's/^/    /'
fi

section "📊 SAMMANFATTNING OCH REKOMMENDATIONER"
echo ""

echo "💡 Om container körs men Traefik inte routar:"
echo "   1. Kontrollera att HTTP entrypoint finns i Traefik labels"
echo "   2. Starta om Traefik: docker restart $TRAEFIK_CONTAINER"
echo "   3. Vänta 30-60 sekunder för Traefik att uppdatera"
echo ""
echo "💡 Om container inte svarar på port 7860:"
echo "   1. Kontrollera Langflow logs: docker logs $CONTAINER --tail 50"
echo "   2. Kontrollera att Langflow faktiskt startat korrekt"
echo ""
echo "💡 Om Traefik inte körs:"
echo "   1. Starta via Coolify Dashboard: Settings → Proxy → Start"
echo ""
REMOTE

echo ""
info "Diagnostik klar!"
echo ""


