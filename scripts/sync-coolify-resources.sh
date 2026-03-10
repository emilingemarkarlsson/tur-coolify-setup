#!/usr/bin/env bash
set -euo pipefail

# sync-coolify-resources.sh - Synkar Coolify-resurser och skapar dokumentation

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

echo "📋 Synkar Coolify Resurser & Skapar Dokumentation"
echo "=================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ============================================================================
# STEG 1: Identifiera Aktiva Resurser i Coolify
# ============================================================================
section "STEG 1: Identifierar Aktiva Resurser i Coolify"

echo "🔍 Analyserar Coolify-services..."
echo ""

# Hämta lista över aktiva services
ACTIVE_SERVICES=$(ssh "$HOST" bash <<'REMOTE'
if [ -d "/data/coolify/services" ]; then
    for service_dir in /data/coolify/services/*; do
        if [ -d "$service_dir" ] && [ -f "$service_dir/docker-compose.yml" ]; then
            SERVICE_ID=$(basename "$service_dir")
            
            # Hitta container-namn från docker-compose.yml
            CONTAINER_NAME=$(grep -E "^\s+container_name:" "$service_dir/docker-compose.yml" 2>/dev/null | sed 's/.*container_name:[[:space:]]*//' | tr -d "'\"" || echo "")
            
            # Hitta image från docker-compose.yml
            # Först: Hitta första service (inte postgres/redis)
            FIRST_SERVICE=$(grep -A 30 "^services:" "$service_dir/docker-compose.yml" 2>/dev/null | grep -E "^\s+[a-zA-Z0-9_-]+:" | head -1 | sed 's/://' | tr -d ' ' || echo "")
            
            if [ -n "$FIRST_SERVICE" ]; then
                # Hämta image från första service
                IMAGE=$(sed -n "/^services:/,/^[a-z]/ { /^\s*${FIRST_SERVICE}:/,/^\s*[a-z]/ { /^\s*image:/p } }" "$service_dir/docker-compose.yml" 2>/dev/null | head -1 | sed 's/.*image:[[:space:]]*//' | tr -d "'\"" || echo "")
            fi
            
            # Fallback: Hitta första image som inte är postgres/redis
            if [ -z "$IMAGE" ]; then
                IMAGE=$(grep -E "^\s+image:" "$service_dir/docker-compose.yml" 2>/dev/null | grep -v "postgres" | grep -v "redis" | grep -v "postgresql" | head -1 | sed 's/.*image:[[:space:]]*//' | tr -d "'\"" || echo "")
            fi
            
            # Hitta domain från Traefik labels
            DOMAIN=$(grep -E "traefik.http.routers.*.rule=Host" "$service_dir/docker-compose.yml" 2>/dev/null | sed 's/.*Host(`\([^`]*\)`).*/\1/' || echo "")
            
            # Kontrollera om container körs
            if [ -n "$CONTAINER_NAME" ]; then
                STATUS=$(docker ps --filter "name=$CONTAINER_NAME" --format '{{.State.Status}}' 2>/dev/null || echo "not_found")
            else
                STATUS="unknown"
            fi
            
            # Output: SERVICE_ID|CONTAINER_NAME|IMAGE|DOMAIN|STATUS
            echo "$SERVICE_ID|$CONTAINER_NAME|$IMAGE|$DOMAIN|$STATUS"
        fi
    done
fi
REMOTE
)

if [ -z "$ACTIVE_SERVICES" ]; then
    warn "Inga services hittades i Coolify"
    exit 0
fi

echo "  Hittade $(echo "$ACTIVE_SERVICES" | wc -l | tr -d ' ') service(s)"
echo ""

# ============================================================================
# STEG 2: Skapa/Uppdatera Dokumentation för Varje Service
# ============================================================================
section "STEG 2: Skapar/Uppdaterar Dokumentation"

while IFS='|' read -r SERVICE_ID CONTAINER_NAME IMAGE DOMAIN STATUS; do
    if [ -z "$SERVICE_ID" ]; then
        continue
    fi
    
    # Hoppa över services med ogiltiga värden
    if [ "$CONTAINER_NAME" = "not_found" ] || [ "$CONTAINER_NAME" = "unknown" ]; then
        warn "  Hoppar över service med ogiltigt container-namn: $SERVICE_ID"
        continue
    fi
    
    # Hoppa över postgresql/redis/database services (dependencies)
    if [[ "$CONTAINER_NAME" == *"postgres"* ]] || [[ "$SERVICE_ID" == *"postgres"* ]] || [[ "$CONTAINER_NAME" == *"redis"* ]] || [[ "$SERVICE_ID" == *"redis"* ]]; then
        warn "  Hoppar över database/dependency service: $SERVICE_ID"
        continue
    fi
    
    # Om image saknas men container finns, försök hämta från docker-compose.yml
    if [ -z "$IMAGE" ] && [ -n "$CONTAINER_NAME" ]; then
        IMAGE=$(ssh "$HOST" "grep -E '^\s+image:' /data/coolify/services/$SERVICE_ID/docker-compose.yml 2>/dev/null | grep -v postgres | grep -v redis | head -1 | sed 's/.*image:[[:space:]]*//' | tr -d \"'\" || echo \"\"")
    fi
    
    if [ -z "$IMAGE" ] && [ -z "$CONTAINER_NAME" ]; then
        warn "  Hoppar över service utan container eller image: $SERVICE_ID"
        continue
    fi
    
    echo "📦 Processing: $SERVICE_ID"
    echo "  Container: $CONTAINER_NAME"
    echo "  Image: $IMAGE"
    echo "  Domain: ${DOMAIN:-N/A}"
    echo "  Status: $STATUS"
    echo ""
    
    # Identifiera service-typ från image eller container-namn
    SERVICE_TYPE=""
    SERVICE_DIR=""
    
    # Mappa container-namn eller image till service-typ
    if [[ "$CONTAINER_NAME" == *"n8n"* ]] || [[ "$IMAGE" == *"n8n"* ]]; then
        SERVICE_TYPE="n8n"
        SERVICE_DIR="$PROJECT_ROOT/n8n"
    elif [[ "$CONTAINER_NAME" == *"minio"* ]] || [[ "$IMAGE" == *"minio"* ]]; then
        SERVICE_TYPE="minio"
        SERVICE_DIR="$PROJECT_ROOT/minio"
    elif [[ "$CONTAINER_NAME" == *"open-webui"* ]] || [[ "$IMAGE" == *"open-webui"* ]] || [[ "$IMAGE" == *"openwebui"* ]]; then
        SERVICE_TYPE="open-webui"
        SERVICE_DIR="$PROJECT_ROOT/open-webui"
    elif [[ "$CONTAINER_NAME" == *"umami"* ]] || [[ "$IMAGE" == *"umami"* ]]; then
        SERVICE_TYPE="umami"
        SERVICE_DIR="$PROJECT_ROOT/umami"
    elif [[ "$CONTAINER_NAME" == *"langflow"* ]] || [[ "$IMAGE" == *"langflow"* ]]; then
        SERVICE_TYPE="langflow"
        SERVICE_DIR="$PROJECT_ROOT/langflow"
    elif [[ "$CONTAINER_NAME" == *"grafana"* ]] || [[ "$IMAGE" == *"grafana"* ]]; then
        SERVICE_TYPE="grafana"
        SERVICE_DIR="$PROJECT_ROOT/archive/services/grafana"  # Arkiverad men behåll dokumentation
    elif [[ "$CONTAINER_NAME" == *"mage"* ]] || [[ "$IMAGE" == *"mage"* ]]; then
        SERVICE_TYPE="mage-ai"
        SERVICE_DIR="$PROJECT_ROOT/archive/services/mage-ai"  # الأرشيف men behåll dokumentation
    else
        # Okänd service - extrahera från container-namn eller image
        if [ -n "$CONTAINER_NAME" ] && [ "$CONTAINER_NAME" != "not_found" ] && [ "$CONTAINER_NAME" != "unknown" ]; then
            # Extrahera service-namn från container (t.ex. open-webui-cckckggw44s8gkkkw008k4cs -> open-webui)
            SERVICE_TYPE=$(echo "$CONTAINER_NAME" | sed 's/tha_//' | sed 's/-[a-z0-9]\{20,\}$//' | sed 's/_compose//' | tr '[:upper:]' '[:lower:]')
        elif [ -n "$IMAGE" ]; then
            # Extrahera från image (t.ex. ghcr.io/open-webui/open-webui:main -> open-webui)
            SERVICE_TYPE=$(echo "$IMAGE" | sed 's|.*/||' | cut -d: -f1 | sed 's/_/-/g')
        else
            warn "  Hoppar över service utan giltigt container-namn eller image: $SERVICE_ID"
            continue
        fi
        
        # Säkerställ att service-typ är rimlig
        if [ -z "$SERVICE_TYPE" ] || [ "$SERVICE_TYPE" = "unknown" ] || [ "$SERVICE_TYPE" = "not_found" ] || [ ${#SERVICE_TYPE} -gt 30 ] || [[ "$SERVICE_TYPE" =~ [0-9]{10,} ]]; then
            warn "  Hoppar över service med ogiltigt namn: $SERVICE_ID (identifierad som: $SERVICE_TYPE)"
            continue
        fi
        
        SERVICE_DIR="$PROJECT_ROOT/$SERVICE_TYPE"
        info "  Ny service identifierad: $SERVICE_TYPE"
    fi
    
    # Skapa service-mapp om den inte finns
    if [ -n "$SERVICE_DIR" ] && [ ! -d "$SERVICE_DIR" ] && [[ ! "$SERVICE_DIR" == *"archive"* ]]; then
        echo "  📁 Skapar mapp: $SERVICE_DIR"
        mkdir -p "$SERVICE_DIR"
    fi
    
    # Om service-mappen finns, uppdatera dokumentation
    if [ -n "$SERVICE_DIR" ] && [ -d "$SERVICE_DIR" ]; then
        echo "  📝 Uppdaterar dokumentation i $SERVICE_DIR"
        
        # Uppdatera docker-compose.yml om den finns
        if [ -f "$SERVICE_DIR/docker-compose.yml" ]; then
            echo "    ✅ docker-compose.yml finns"
        else
            # Hämta docker-compose.yml från Coolify
            echo "    📥 Hämtar docker-compose.yml från Coolify..."
            ssh "$HOST" "cat /data/coolify/services/$SERVICE_ID/docker-compose.yml" > "$SERVICE_DIR/docker-compose.yml" 2>/dev/null || warn "    Kunde inte hämta docker-compose.yml"
        fi
        
        # Skapa/uppdatera UPGRADE.md
        if [ ! -f "$SERVICE_DIR/UPGRADE.md" ]; then
            echo "    📝 Skapar UPGRADE.md..."
            if [ -n "$IMAGE" ] && [ "$IMAGE" != "<image-saknas>" ]; then
                "$SCRIPT_DIR/generate-service-docs.sh" "$HOST" "$SERVICE_ID" "$SERVICE_TYPE" "$IMAGE" "$DOMAIN" || warn "    Kunde inte skapa UPGRADE.md"
            else
                warn "    Hoppar över UPGRADE.md - image saknas"
            fi
        else
            echo "    ✅ UPGRADE.md finns redan"
        fi
        
        # Skapa/uppdatera README.md
        if [ ! -f "$SERVICE_DIR/README.md" ]; then
            echo "    📝 Skapar README.md..."
            "$SCRIPT_DIR/generate-service-readme.sh" "$SERVICE_TYPE" "${IMAGE:-<image-saknas>}" "$DOMAIN" || warn "    Kunde inte skapa README.md"
        fi
    fi
    
    echo ""
done <<< "$ACTIVE_SERVICES"

# ============================================================================
# STEG 3: Uppdatera SERVICES.md
# ============================================================================
section "STEG 3: Uppdaterar SERVICES.md"

echo "📝 Uppdaterar SERVICES.md med aktiva services..."
echo ""

# Detta kommer att hanteras av ett separat script
"$SCRIPT_DIR/update-services-doc.sh" "$HOST" || warn "Kunde inte uppdatera SERVICES.md"

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning"

echo ""
info "Resurs-synkning klar!"
echo ""
echo "💡 Nästa steg:"
echo ""
echo "1. Granska skapad/uppdaterad dokumentation"
echo "2. Uppdatera services enligt UPGRADE.md i varje mapp"
echo "3. Verifiera allt: ./scripts/verify-all.sh"
echo ""
