#!/usr/bin/env bash
set -euo pipefail

# list-coolify-project.sh - Listar alla resurser i ett Coolify-projekt direkt från filsystemet

HOST="${1:-tha}"
PROJECT_NAME="${2:-theunnamedroads platform}"

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

echo "🔍 Listar Resurser i Coolify Projekt"
echo "====================================="
echo ""
warn "Projekt: $PROJECT_NAME"
echo ""

# ============================================================================
# STEG 1: Hitta Projekt Directory
# ============================================================================
section "STEG 1: Hittar Projekt Directory"

PROJECT_DIR=$(ssh "$HOST" bash <<REMOTE
set +u  # Tillåt odefinierade variabler i remote script
PROJECT_NAME="${PROJECT_NAME}"

# Sök i /data/coolify/projects
if [ -d "/data/coolify/projects" ]; then
    for project_dir in /data/coolify/projects/*; do
        if [ -n "$project_dir" ] && [ -d "$project_dir" ]; then
            DIR_NAME=$(basename "$project_dir")
            if [[ "$DIR_NAME" == *"$PROJECT_NAME"* ]] || [[ "$PROJECT_NAME" == *"$DIR_NAME"* ]] || \
               [[ "$DIR_NAME" == *"theunnamedroads"* ]] || [[ "$DIR_NAME" == *"unnamedroads"* ]]; then
                echo "$project_dir"
                exit 0
            fi
        fi
    done
fi

# Sök även i /data/coolify (root level)
if [ -d "/data/coolify" ]; then
    # Kolla om det finns projekt-filer
    find /data/coolify -maxdepth 2 -type d -name "*$PROJECT_NAME*" 2>/dev/null | head -1
fi
REMOTE
)

if [ -n "$PROJECT_DIR" ]; then
    info "Projekt directory: $PROJECT_DIR"
else
    warn "Projekt directory hittades inte"
    echo ""
    echo "💡 Tillgängliga projekt:"
    ssh "$HOST" 'ls -la /data/coolify/projects/ 2>/dev/null | grep "^d" | tail -n +4 | awk "{print \$NF}"' || echo "  Kunde inte lista projekt"
    echo ""
    PROJECT_DIR="/data/coolify/services"  # Fallback till services
fi

# ============================================================================
# STEG 2: Lista Alla Services/Applications
# ============================================================================
section "STEG 2: Listar Alla Services/Applications"

echo "📦 Hämtar alla services..."
echo ""

# Hämta alla services från projektet eller alla services
ALL_SERVICES=$(ssh "$HOST" bash <<REMOTE
set +u  # Tillåt odefinierade variabler i remote script
PROJECT_DIR="${PROJECT_DIR}"

# Metod 1: Från projekt directory
if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR/services" ]; then
    for service_dir in "$PROJECT_DIR/services"/*; do
        if [ -n "$service_dir" ] && [ -d "$service_dir" ] && [ -f "$service_dir/docker-compose.yml" ]; then
            SERVICE_ID=$(basename "$service_dir")
            echo "$SERVICE_ID|$service_dir"
        fi
    done
fi

# Metod 2: Från /data/coolify/services (alla services)
if [ -d "/data/coolify/services" ]; then
    for service_dir in /data/coolify/services/*; do
        if [ -n "$service_dir" ] && [ -d "$service_dir" ] && [ -f "$service_dir/docker-compose.yml" ]; then
            SERVICE_ID=$(basename "$service_dir")
            
            # Extrahera information
            CONTAINER_NAME=$(grep -E "^\s+container_name:" "$service_dir/docker-compose.yml" 2>/dev/null | sed 's/.*container_name:[[:space:]]*//' | tr -d "'\"" | head -1 || echo "")
            IMAGE=$(grep -E "^\s+image:" "$service_dir/docker-compose.yml" 2>/dev/null | grep -v postgres | grep -v redis | grep -v "postgresql" | head -1 | sed 's/.*image:[[:space:]]*//' | tr -d "'\"" || echo "")
            DOMAIN=$(grep -E "traefik.http.routers.*.rule=Host" "$service_dir/docker-compose.yml" 2>/dev/null | sed 's/.*Host(`\([^`]*\)`).*/\1/' | head -1 || echo "")
            
            # Hoppa över dependencies
            if [[ "$CONTAINER_NAME" == *"postgres"* ]] || [[ "$CONTAINER_NAME" == *"redis"* ]] || \
               [[ "$SERVICE_ID" == *"postgres"* ]] || [[ "$SERVICE_ID" == *"redis"* ]] || \
               [[ "$IMAGE" == *"postgres"* ]] || [[ "$IMAGE" == *"redis"* ]]; then
                continue
            fi
            
            # Hoppa över tomma services
            if [ -z "$CONTAINER_NAME" ] && [ -z "$IMAGE" ]; then
                continue
            fi
            
            # Output: SERVICE_ID|CONTAINER_NAME|IMAGE|DOMAIN|SERVICE_DIR
            echo "$SERVICE_ID|$CONTAINER_NAME|$IMAGE|$DOMAIN|$service_dir"
        fi
    done
fi
REMOTE
)

SERVICE_COUNT=$(echo "$ALL_SERVICES" | grep -v "^$" | wc -l | tr -d ' ')
info "Hittade $SERVICE_COUNT service(s)"
echo ""

# ============================================================================
# STEG 3: Visa Detaljerad Information
# ============================================================================
section "STEG 3: Detaljerad Information"

echo "📋 Services:"
echo ""

COUNTER=1
while IFS='|' read -r SERVICE_ID CONTAINER_NAME IMAGE DOMAIN SERVICE_DIR; do
    if [ -z "$SERVICE_ID" ]; then
        continue
    fi
    
    echo "$COUNTER. $SERVICE_ID"
    echo "   Container: ${CONTAINER_NAME:-N/A}"
    echo "   Image: ${IMAGE:-N/A}"
    echo "   Domain: ${DOMAIN:-N/A}"
    echo "   Directory: $SERVICE_DIR"
    echo ""
    
    COUNTER=$((COUNTER + 1))
done <<< "$ALL_SERVICES"

# ============================================================================
# STEG 4: Identifiera Service-typer
# ============================================================================
section "STEG 4: Identifierade Service-typer"

echo "🔍 Identifierar service-typer..."
echo ""

declare -A SERVICE_TYPES

while IFS='|' read -r SERVICE_ID CONTAINER_NAME IMAGE DOMAIN SERVICE_DIR; do
    if [ -z "$SERVICE_ID" ]; then
        continue
    fi
    
    SERVICE_TYPE=""
    
    if [[ "$CONTAINER_NAME" == *"n8n"* ]] || [[ "$IMAGE" == *"n8n"* ]]; then
        SERVICE_TYPE="n8n"
    elif [[ "$CONTAINER_NAME" == *"minio"* ]] || [[ "$IMAGE" == *"minio"* ]]; then
        SERVICE_TYPE="minio"
    elif [[ "$CONTAINER_NAME" == *"open-webui"* ]] || [[ "$IMAGE" == *"open-webui"* ]] || [[ "$IMAGE" == *"openwebui"* ]]; then
        SERVICE_TYPE="open-webui"
    elif [[ "$CONTAINER_NAME" == *"umami"* ]] || [[ "$IMAGE" == *"umami"* ]]; then
        SERVICE_TYPE="umami"
    elif [ -n "$CONTAINER_NAME" ]; then
        SERVICE_TYPE=$(echo "$CONTAINER_NAME" | sed 's/tha_//' | sed 's/-[a-z0-9]\{20,\}$//' | sed 's/_compose//' | tr '[:upper:]' '[:lower:]')
    elif [ -n "$IMAGE" ]; then
        SERVICE_TYPE=$(echo "$IMAGE" | sed 's|.*/||' | cut -d: -f1 | sed 's/_/-/g')
    fi
    
    if [ -n "$SERVICE_TYPE" ] && [ "$SERVICE_TYPE" != "unknown" ] && [ ${#SERVICE_TYPE} -le 30 ]; then
        if [ -z "${SERVICE_TYPES[$SERVICE_TYPE]}" ]; then
            SERVICE_TYPES[$SERVICE_TYPE]="$SERVICE_ID"
            echo "  ✅ $SERVICE_TYPE: $SERVICE_ID"
        else
            SERVICE_TYPES[$SERVICE_TYPE]="${SERVICE_TYPES[$SERVICE_TYPE]},$SERVICE_ID"
            echo "  ✅ $SERVICE_TYPE: $SERVICE_ID (flera instanser)"
        fi
    else
        echo "  ⚠️  Okänd typ: $SERVICE_ID"
    fi
done <<< "$ALL_SERVICES"

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning"

echo ""
info "Totalt $SERVICE_COUNT service(s) identifierade"
echo ""
echo "💡 För att synka och skapa dokumentation:"
echo "   ./scripts/sync-coolify-resources.sh"
echo ""

