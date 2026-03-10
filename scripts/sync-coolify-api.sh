#!/usr/bin/env bash
set -euo pipefail

# sync-coolify-api.sh - Synkar Coolify-resurser via API

HOST="${1:-tha}"
COOLIFY_URL="${2:-https://coolify.theunnamedroads.com}"
PROJECT_NAME="${3:-theunnamedroads platform}"

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

echo "📋 Synkar Coolify Resurser via API"
echo "==================================="
echo ""
warn "Coolify URL: $COOLIFY_URL"
warn "Projekt: $PROJECT_NAME"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ============================================================================
# STEG 1: Hämta Coolify API Token
# ============================================================================
section "STEG 1: Hämtar Coolify API Token"

echo "🔑 Hämtar API token från Coolify..."
echo ""

API_TOKEN=$(ssh "$HOST" bash <<'REMOTE'
if [ -f "/data/coolify/.env" ]; then
    grep -E "^COOLIFY_API_KEY=" /data/coolify/.env 2>/dev/null | cut -d= -f2 | tr -d '"' || echo ""
else
    echo ""
fi
REMOTE
)

if [ -z "$API_TOKEN" ]; then
    warn "API token hittades inte i .env"
    echo ""
    echo "💡 Alternativ metod: Använd Coolify Dashboard"
    echo "   1. Gå till: $COOLIFY_URL"
    echo "   2. Settings → API"
    echo "   3. Skapa API token"
    echo "   4. Använd token i scriptet"
    echo ""
    read -p "Har du en API token? (ja/nej): " -r
    if [[ $REPLY =~ ^[Jj]a$ ]]; then
        read -p "Ange API token: " -r API_TOKEN
    else
        error "Kan inte fortsätta utan API token"
        exit 1
    fi
else
    info "API token hittad"
fi

# ============================================================================
# STEG 2: Hitta Projektet
# ============================================================================
section "STEG 2: Hittar Projektet"

echo "🔍 Söker efter projekt '$PROJECT_NAME'..."
echo ""

# Hämta projekt via API eller direkt från Coolify
PROJECT_INFO=$(ssh "$HOST" bash <<REMOTE
# Metod 1: Via Coolify API (om tillgänglig)
if command -v curl >/dev/null 2>&1; then
    # Försök hämta projekt via API
    curl -s -H "Authorization: Bearer ${API_TOKEN}" "${COOLIFY_URL}/api/v1/projects" 2>/dev/null | \
        grep -i "theunnamedroads\|theunnamedroads platform\|the unnamed roads" || echo ""
fi

# Metod 2: Direkt från filsystem
if [ -d "/data/coolify/projects" ]; then
    for project_dir in /data/coolify/projects/*; do
        if [ -d "$project_dir" ]; then
            PROJECT_NAME=$(basename "$project_dir")
            if [[ "$PROJECT_NAME" == *"unnamed"* ]] || [[ "$PROJECT_NAME" == *"unnamedroads"* ]] || \
               [[ "$PROJECT_NAME" == *"theunnamedroads"* ]] || [[ "$DIR_NAME" == *"theunnamedroads"* ]] || \
               [[ "$DIR_NAME" == *"unnamedroads"* ]]; then
                echo "$PROJECT_NAME|$project_dir"
            fi
        fi
    done
fi
REMOTE
)

if [ -z "$PROJECT_INFO" ]; then
    warn "Projekt '$PROJECT_NAME' hittades inte"
    echo ""
    echo "💡 Lista alla projekt:"
    ssh "$HOST" 'ls -la /data/coolify/projects/ 2>/dev/null | grep "^d" | tail -n +4' || echo "  Kunde inte lista projekt"
    echo ""
    read -p "Ange projekt-namn eller ID: " -r PROJECT_NAME
else
    PROJECT_NAME=$(echo "$PROJECT_INFO" | cut -d'|' -f1 | head -1)
    info "Projekt hittat: $PROJECT_NAME"
fi

# ============================================================================
# STEG 3: Lista Alla Resurser i Projektet
# ============================================================================
section "STEG 3: Listar Alla Resurser i Projektet"

echo "📦 Hämtar alla resurser från projektet..."
echo ""

# Hämta alla services/applications från projektet
RESOURCES=$(ssh "$HOST" bash <<REMOTE
set +u  # Tillåt odefinierade variabler i remote script
PROJECT_NAME="${PROJECT_NAME}"

# Hitta projekt directory
PROJECT_DIR=""
if [ -d "/data/coolify/projects" ]; then
    for project_dir in /data/coolify/projects/*; do
        if [ -n "$project_dir" ] && [ -d "$project_dir" ]; then
            DIR_NAME=$(basename "$project_dir")
            if [[ "$DIR_NAME" == *"$PROJECT_NAME"* ]] || [[ "$PROJECT_NAME" == *"$DIR_NAME"* ]] || \
               [[ "$DIR_NAME" == *"theunnamedroads"* ]] || [[ "$DIR_NAME" == *"unnamedroads"* ]]; then
                PROJECT_DIR="$project_dir"
                break
            fi
        fi
    done
fi

if [ -z "$PROJECT_DIR" ]; then
    # Försök hitta via services directory
    if [ -d "/data/coolify/services" ]; then
        for service_dir in /data/coolify/services/*; do
            if [ -n "$service_dir" ] && [ -d "$service_dir" ] && [ -f "$service_dir/docker-compose.yml" ]; then
                SERVICE_ID=$(basename "$service_dir")
                
                # Kolla om det finns projekt-referens i compose-filen
                if grep -q "$PROJECT_NAME" "$service_dir/docker-compose.yml" 2>/dev/null; then
                    echo "$SERVICE_ID|$service_dir"
                fi
            fi
        done
    fi
else
    # Lista alla services i projektet
    if [ -d "$PROJECT_DIR/services" ]; then
        for service_dir in "$PROJECT_DIR/services"/*; do
            if [ -n "$service_dir" ] && [ -d "$service_dir" ]; then
                SERVICE_ID=$(basename "$service_dir")
                echo "$SERVICE_ID|$service_dir"
            fi
        done
    fi
    
    # Lista även från /data/coolify/services om de länkar till projektet
    if [ -d "/data/coolify/services" ]; then
        for service_dir in /data/coolify/services/*; do
            if [ -n "$service_dir" ] && [ -d "$service_dir" ] && [ -f "$service_dir/docker-compose.yml" ]; then
                SERVICE_ID=$(basename "$service_dir")
                
                # Extrahera information från docker-compose.yml
                CONTAINER_NAME=$(grep -E "^\s+container_name:" "$service_dir/docker-compose.yml" 2>/dev/null | sed 's/.*container_name:[[:space:]]*//' | tr -d "'\"" | head -1 || echo "")
                IMAGE=$(grep -E "^\s+image:" "$service_dir/docker-compose.yml" 2>/dev/null | grep -v postgres | grep -v redis | head -1 | sed 's/.*image:[[:space:]]*//' | tr -d "'\"" || echo "")
                DOMAIN=$(grep -E "traefik.http.routers.*.rule=Host" "$service_dir/docker-compose.yml" 2>/dev/null | sed 's/.*Host(`\([^`]*\)`).*/\1/' | head -1 || echo "")
                
                # Output: SERVICE_ID|CONTAINER_NAME|IMAGE|DOMAIN|SERVICE_DIR
                echo "$SERVICE_ID|$CONTAINER_NAME|$IMAGE|$DOMAIN|$service_dir"
            fi
        done
    fi
fi
REMOTE
)

if [ -z "$RESOURCES" ]; then
    error "Inga resurser hittades i projektet"
    echo ""
    echo "💡 Alternativ: Lista alla services direkt"
    echo ""
    # Fallback: Lista alla services
    RESOURCES=$(ssh "$HOST" bash <<'REMOTE'
set +u  # Tillåt odefinierade variabler i remote script
if [ -d "/data/coolify/services" ]; then
    for service_dir in /data/coolify/services/*; do
        if [ -n "$service_dir" ] && [ -d "$service_dir" ] && [ -f "$service_dir/docker-compose.yml" ]; then
            SERVICE_ID=$(basename "$service_dir")
            
            CONTAINER_NAME=$(grep -E "^\s+container_name:" "$service_dir/docker-compose.yml" 2>/dev/null | sed 's/.*container_name:[[:space:]]*//' | tr -d "'\"" | head -1 || echo "")
            IMAGE=$(grep -E "^\s+image:" "$service_dir/docker-compose.yml" 2>/dev/null | grep -v postgres | grep -v redis | head -1 | sed 's/.*image:[[:space:]]*//' | tr -d "'\"" || echo "")
            DOMAIN=$(grep -E "traefik.http.routers.*.rule=Host" "$service_dir/docker-compose.yml" 2>/dev/null | sed 's/.*Host(`\([^`]*\)`).*/\1/' | head -1 || echo "")
            
            # Hoppa över postgres/redis
            if [[ "$CONTAINER_NAME" == *"postgres"* ]] || [[ "$CONTAINER_NAME" == *"redis"* ]] || [[ "$SERVICE_ID" == *"postgres"* ]] || [[ "$SERVICE_ID" == *"redis"* ]]; then
                continue
            fi
            
            echo "$SERVICE_ID|$CONTAINER_NAME|$IMAGE|$DOMAIN|$service_dir"
        fi
    done
fi
REMOTE
)
fi

RESOURCE_COUNT=$(echo "$RESOURCES" | grep -v "^$" | wc -l | tr -d ' ')
info "Hittade $RESOURCE_COUNT resurs(er)"
echo ""

# ============================================================================
# STEG 4: Skapa/Uppdatera Dokumentation
# ============================================================================
section "STEG 4: Skapar/Uppdaterar Dokumentation"

while IFS='|' read -r SERVICE_ID CONTAINER_NAME IMAGE DOMAIN SERVICE_DIR; do
    if [ -z "$SERVICE_ID" ]; then
        continue
    fi
    
    echo "📦 Processing: $SERVICE_ID"
    echo "  Container: ${CONTAINER_NAME:-N/A}"
    echo "  Image: ${IMAGE:-N/A}"
    echo "  Domain: ${DOMAIN:-N/A}"
    echo ""
    
    # Identifiera service-typ
    SERVICE_TYPE=""
    SERVICE_DIR_LOCAL=""
    
    if [[ "$CONTAINER_NAME" == *"n8n"* ]] || [[ "$IMAGE" == *"n8n"* ]]; then
        SERVICE_TYPE="n8n"
        SERVICE_DIR_LOCAL="$PROJECT_ROOT/n8n"
    elif [[ "$CONTAINER_NAME" == *"minio"* ]] || [[ "$IMAGE" == *"minio"* ]]; then
        SERVICE_TYPE="minio"
        SERVICE_DIR_LOCAL="$PROJECT_ROOT/minio"
    elif [[ "$CONTAINER_NAME" == *"open-webui"* ]] || [[ "$IMAGE" == *"open-webui"* ]] || [[ "$IMAGE" == *"openwebui"* ]]; then
        SERVICE_TYPE="open-webui"
        SERVICE_DIR_LOCAL="$PROJECT_ROOT/open-webui"
    elif [[ "$CONTAINER_NAME" == *"umami"* ]] || [[ "$IMAGE" == *"umami"* ]]; then
        SERVICE_TYPE="umami"
        SERVICE_DIR_LOCAL="$PROJECT_ROOT/umami"
    elif [ -n "$CONTAINER_NAME" ] && [ "$CONTAINER_NAME" != "not_found" ] && [ "$CONTAINER_NAME" != "unknown" ]; then
        # Extrahera service-namn från container
        SERVICE_TYPE=$(echo "$CONTAINER_NAME" | sed 's/tha_//' | sed 's/-[a-z0-9]\{20,\}$//' | sed 's/_compose//' | tr '[:upper:]' '[:lower:]')
        SERVICE_DIR_LOCAL="$PROJECT_ROOT/$SERVICE_TYPE"
    elif [ -n "$IMAGE" ]; then
        SERVICE_TYPE=$(echo "$IMAGE" | sed 's|.*/||' | cut -d: -f1 | sed 's/_/-/g')
        SERVICE_DIR_LOCAL="$PROJECT_ROOT/$SERVICE_TYPE"
    else
        warn "  Hoppar över - kan inte identifiera service-typ"
        continue
    fi
    
    # Validera service-typ
    if [ -z "$SERVICE_TYPE" ] || [ "$SERVICE_TYPE" = "unknown" ] || [ "$SERVICE_TYPE" = "not_found" ] || [ ${#SERVICE_TYPE} -gt 30 ]; then
        warn "  Hoppar över - ogiltigt service-namn: $SERVICE_TYPE"
        continue
    fi
    
    # Skapa mapp
    if [ ! -d "$SERVICE_DIR_LOCAL" ]; then
        echo "  📁 Skapar mapp: $SERVICE_DIR_LOCAL"
        mkdir -p "$SERVICE_DIR_LOCAL"
    fi
    
    # Uppdatera dokumentation
    echo "  📝 Uppdaterar dokumentation..."
    
    # Hämta docker-compose.yml
    if [ -n "$SERVICE_DIR" ] && [ -f "$SERVICE_DIR/docker-compose.yml" ]; then
        if [ ! -f "$SERVICE_DIR_LOCAL/docker-compose.yml" ]; then
            echo "    📥 Hämtar docker-compose.yml..."
            ssh "$HOST" "cat $SERVICE_DIR/docker-compose.yml" > "$SERVICE_DIR_LOCAL/docker-compose.yml" 2>/dev/null || warn "    Kunde inte hämta docker-compose.yml"
        fi
    fi
    
    # Skapa UPGRADE.md
    if [ ! -f "$SERVICE_DIR_LOCAL/UPGRADE.md" ] && [ -n "$IMAGE" ] && [ "$IMAGE" != "<image-saknas>" ]; then
        echo "    📝 Skapar UPGRADE.md..."
        "$SCRIPT_DIR/generate-service-docs.sh" "$HOST" "$SERVICE_ID" "$SERVICE_TYPE" "$IMAGE" "$DOMAIN" || warn "    Kunde inte skapa UPGRADE.md"
    fi
    
    # Skapa README.md
    if [ ! -f "$SERVICE_DIR_LOCAL/README.md" ]; then
        echo "    📝 Skapar README.md..."
        "$SCRIPT_DIR/generate-service-readme.sh" "$SERVICE_TYPE" "${IMAGE:-<image-saknas>}" "$DOMAIN" || warn "    Kunde inte skapa README.md"
    fi
    
    echo ""
done <<< "$RESOURCES"

# ============================================================================
# STEG 5: Uppdatera SERVICES.md
# ============================================================================
section "STEG 5: Uppdaterar SERVICES.md"

echo "📝 Uppdaterar SERVICES.md..."
echo ""

"$SCRIPT_DIR/update-services-doc.sh" "$HOST" || warn "Kunde inte uppdatera SERVICES.md"

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning"

echo ""
info "Resurs-synkning klar!"
echo ""
echo "💡 Identifierade resurser:"
echo "$RESOURCES" | while IFS='|' read -r SERVICE_ID CONTAINER_NAME IMAGE DOMAIN SERVICE_DIR; do
    if [ -n "$SERVICE_ID" ]; then
        echo "  • $SERVICE_ID (${CONTAINER_NAME:-N/A})"
    fi
done
echo ""
echo "📁 Dokumentation skapad/uppdaterad i:"
ls -d "$PROJECT_ROOT"/*/ 2>/dev/null | grep -v archive | grep -v docs | grep -v scripts | xargs -n1 basename | while read -r dir; do
    if [ -f "$PROJECT_ROOT/$dir/README.md" ] || [ -f "$PROJECT_ROOT/$dir/UPGRADE.md" ]; then
        echo "  • $dir/"
    fi
done
echo ""

