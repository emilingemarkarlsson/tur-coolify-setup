#!/usr/bin/env bash
set -euo pipefail

# list-coolify-resources.sh - Listar alla Coolify-resurser och kontrollerar uppdateringar

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

echo "📋 Coolify Resurser & Uppdateringar"
echo "===================================="

# ============================================================================
# STEG 1: Lista alla Coolify Services
# ============================================================================
section "1️⃣  Coolify Services"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Söker efter Coolify services..."

# Coolify lagrar services i /data/coolify/services/
if [ -d "/data/coolify/services" ]; then
    SERVICE_COUNT=$(find /data/coolify/services -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    echo "  Hittade $SERVICE_COUNT service(s) i /data/coolify/services/"
    echo ""
    
    if [ "$SERVICE_COUNT" -gt 0 ]; then
        echo "📦 Services:"
        for service_dir in /data/coolify/services/*; do
            if [ -d "$service_dir" ]; then
                SERVICE_NAME=$(basename "$service_dir")
                echo ""
                echo "  📁 $SERVICE_NAME"
                
                # Kolla om det finns docker-compose.yml
                if [ -f "$service_dir/docker-compose.yml" ]; then
                    echo "    ✅ docker-compose.yml finns"
                    
                    # Extrahera image names från compose file
                    echo "    🐳 Images:"
                    grep -E "^\s+image:" "$service_dir/docker-compose.yml" 2>/dev/null | sed 's/^[[:space:]]*image:[[:space:]]*//' | sed 's/^[[:space:]]*/      • /' || echo "      (ingen image hittad)"
                else
                    echo "    ⚠️  docker-compose.yml saknas"
                fi
            fi
        done
    else
        echo "  ℹ️  Inga services hittades i /data/coolify/services/"
    fi
else
    echo "  ⚠️  /data/coolify/services/ katalog finns inte"
fi
REMOTE

# ============================================================================
# STEG 2: Lista alla Docker Containers (Coolify och Services)
# ============================================================================
section "2️⃣  Docker Containers Status"

ssh "$HOST" bash <<'REMOTE'
echo "🐳 Alla containers:"
echo ""

# Lista alla containers med detaljerad info
docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | head -20

echo ""
echo "📊 Sammanfattning:"
RUNNING=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)
STOPPED=$(docker ps -a --filter "status=exited" --format '{{.Names}}' 2>/dev/null | wc -l)
TOTAL=$(docker ps -a --format '{{.Names}}' 2>/dev/null | wc -l)

echo "  Körs: $RUNNING"
echo "  Stoppade: $STOPPED"
echo "  Totalt: $TOTAL"
REMOTE

# ============================================================================
# STEG 3: Coolify Services med Container Status
# ============================================================================
section "3️⃣  Service Containers (Coolify-deployerade)"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Coolify-deployerade services:"
echo ""

# Lista containers som inte är coolify-core containers
# Coolify core containers har vanligtvis "coolify" i namnet
SERVICE_CONTAINERS=$(docker ps -a --format '{{.Names}}' 2>/dev/null | grep -v "coolify" | grep -v "traefik" | grep -v "postgres" || true)

if [ -n "$SERVICE_CONTAINERS" ]; then
    echo "📦 Service containers:"
    while IFS= read -r container; do
        if [ -n "$container" ]; then
            STATUS=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
            IMAGE=$(docker inspect --format='{{.Config.Image}}' "$container" 2>/dev/null || echo "unknown")
            
            if [ "$STATUS" = "running" ]; then
                echo "  ✅ $container"
            else
                echo "  ⚠️  $container (Status: $STATUS)"
            fi
            echo "      Image: $IMAGE"
        fi
    done <<< "$SERVICE_CONTAINERS"
else
    echo "  ℹ️  Inga service containers hittades (utom Coolify core)"
fi
REMOTE

# ============================================================================
# STEG 4: Docker Images och Versioner
# ============================================================================
section "4️⃣  Docker Images & Versioner"

ssh "$HOST" bash <<'REMOTE'
echo "📦 Installerade Docker images:"
echo ""

docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" 2>/dev/null | head -20

echo ""
echo "💡 Tips:"
echo "  • ':latest' tag betyder att image kan vara gammal"
echo "  • Specifika versioner (t.ex. 'v1.2.3') är mer stabila"
echo "  • Kontrollera senaste versioner på Docker Hub eller projektets GitHub"
REMOTE

# ============================================================================
# STEG 5: Förväntade Services (från projektstruktur)
# ============================================================================
section "5️⃣  Förväntade Services (från projekt)"

echo "📋 Services som borde finnas enligt projektstruktur:"
echo ""
echo "  • Grafana (grafana/)"
echo "  • N8N (n8n/)"
echo "  • MinIO (minio/)"
echo "  • Mage AI (mage-ai/)"
echo "  • Crawlab (crawlab/)"
echo "  • Appsmith (appsmith/)"
echo ""
echo "💡 Jämför ovanstående med faktiska containers ovan"
echo ""

# ============================================================================
# STEG 6: Uppdateringsrekommendationer
# ============================================================================
section "6️⃣  Uppdateringsrekommendationer"

ssh "$HOST" bash <<'REMOTE'
echo "🔄 Uppdateringscheck:"
echo ""

# Kolla efter :latest tags
LATEST_IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep ":latest" || true)

if [ -n "$LATEST_IMAGES" ]; then
    echo "⚠️  Images med ':latest' tag (kan behöva uppdateras):"
    echo "$LATEST_IMAGES" | sed 's/^/  • /'
    echo ""
    echo "💡 För att uppdatera:"
    echo "  1. Gå till Coolify dashboard"
    echo "  2. Välj service"
    echo "  3. Klicka 'Redeploy' eller uppdatera image-tag i compose-filen"
else
    echo "✅ Inga ':latest' tags hittades (bra!)"
fi

echo ""
echo "📝 Manuell uppdatering:"
echo "  1. SSH till servern: ssh tha"
echo "  2. Gå till service: cd /data/coolify/services/<service-id>"
echo "  3. Redigera docker-compose.yml: nano docker-compose.yml"
echo "  4. Uppdatera image-tag (t.ex. från 'v1.0.0' till 'v1.1.0')"
echo "  5. Uppdatera: docker compose pull && docker compose up -d"
REMOTE

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning"

echo ""
echo "✅ Resurslista klar!"
echo ""
echo "💡 Nästa steg:"
echo "  • Öppna Coolify dashboard: https://coolify.theunnamedroads.com"
echo "  • Jämför listan ovan med services i Coolify UI"
echo "  • Uppdatera services via Coolify UI eller manuellt via SSH"
echo ""
echo "🔧 Ytterligare kommandon:"
echo "  • SSH direkt: ssh $HOST"
echo "  • Lista alla containers: ssh $HOST 'docker ps -a'"
echo "  • Lista alla images: ssh $HOST 'docker images'"
echo ""


