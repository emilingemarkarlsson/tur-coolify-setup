#!/usr/bin/env bash
set -euo pipefail

# coolify-update.sh - Triggar uppdateringar via Coolify API
#
# Användning:
#   ./scripts/coolify-update.sh                    # Interaktiv meny
#   ./scripts/coolify-update.sh list               # Lista alla resurser
#   ./scripts/coolify-update.sh deploy all         # Deploya alla services
#   ./scripts/coolify-update.sh deploy <uuid>      # Deploya specifik resurs
#   ./scripts/coolify-update.sh restart <uuid>     # Starta om specifik service
#   ./scripts/coolify-update.sh status             # Visa pågående deployments
#
# API Token:
#   Sätt COOLIFY_TOKEN i miljön, eller skapa ~/.coolify-token
#   Skapa token: https://coolify.theunnamedroads.com → Profile → API Tokens

COOLIFY_URL="${COOLIFY_URL:-https://coolify.theunnamedroads.com}"
API="$COOLIFY_URL/api/v1"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${GREEN}✅ $1${NC}"; }
warn()    { echo -e "${YELLOW}⚠️  $1${NC}"; }
error()   { echo -e "${RED}❌ $1${NC}"; exit 1; }
section() { echo -e "\n${BLUE}${BOLD}$1${NC}"; echo -e "${BLUE}$(printf '─%.0s' {1..60})${NC}"; }

# ============================================================================
# Hämta API token
# ============================================================================
get_token() {
    if [ -n "${COOLIFY_TOKEN:-}" ]; then
        echo "$COOLIFY_TOKEN"
        return
    fi
    if [ -f "$HOME/.coolify-token" ]; then
        cat "$HOME/.coolify-token"
        return
    fi
    echo ""
}

TOKEN=$(get_token)

if [ -z "$TOKEN" ]; then
    warn "Ingen API token hittad."
    echo ""
    echo "Skapa en token:"
    echo "  1. Gå till: $COOLIFY_URL"
    echo "  2. Profile (uppe till höger) → API Tokens"
    echo "  3. Skapa token med 'read' + 'write' + 'deploy' rättigheter"
    echo ""
    read -rp "Klistra in din API token: " TOKEN
    if [ -z "$TOKEN" ]; then
        error "Ingen token angiven"
    fi
    read -rp "Spara token till ~/.coolify-token för framtida bruk? (ja/nej): " SAVE
    if [[ $SAVE =~ ^[Jj]a$ ]]; then
        echo "$TOKEN" > "$HOME/.coolify-token"
        chmod 600 "$HOME/.coolify-token"
        info "Token sparad till ~/.coolify-token"
    fi
    echo ""
fi

# ============================================================================
# API-anropsfunktioner
# ============================================================================
api_get() {
    local endpoint="$1"
    curl -sf \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/json" \
        "$API$endpoint" 2>/dev/null
}

api_post() {
    local endpoint="$1"
    curl -sf \
        -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        "$API$endpoint" 2>/dev/null
}

api_post_data() {
    local endpoint="$1"
    local data="$2"
    curl -sf \
        -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -d "$data" \
        "$API$endpoint" 2>/dev/null
}

check_auth() {
    local result
    result=$(curl -sf \
        -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $TOKEN" \
        "$API/version" 2>/dev/null || echo "000")
    if [ "$result" = "200" ]; then
        return 0
    else
        error "Autentisering misslyckades (HTTP $result). Kontrollera din token."
    fi
}

# ============================================================================
# Hämta resurser
# ============================================================================
get_services() {
    api_get "/services" 2>/dev/null || echo "[]"
}

get_applications() {
    api_get "/applications" 2>/dev/null || echo "[]"
}

get_deployments() {
    api_get "/deployments" 2>/dev/null || echo "[]"
}

# Extrahera fält med grep/sed (undviker jq-beroende)
extract_field() {
    local json="$1"
    local field="$2"
    echo "$json" | grep -o "\"$field\":\"[^\"]*\"" | sed "s/\"$field\":\"//;s/\"//" | head -1
}

# ============================================================================
# Kommandon
# ============================================================================
cmd_list() {
    section "Tjänster (Services)"
    local services
    services=$(get_services)

    if command -v jq &>/dev/null; then
        echo "$services" | jq -r '.[] | "  \(.uuid)  \(.name)  [\(.status // "unknown")]"' 2>/dev/null || \
            echo "  (inga services hittades)"
    else
        echo "$services" | grep -o '"uuid":"[^"]*"\|"name":"[^"]*"\|"status":"[^"]*"' | \
            paste - - - | sed 's/"uuid":"//g;s/"name":"//g;s/"status":"//g;s/"//g;s/\t/  /g' | \
            awk '{printf "  %-40s %-30s [%s]\n", $1, $2, $3}' || \
            echo "  (inga services hittades)"
    fi

    section "Applikationer (Applications)"
    local apps
    apps=$(get_applications)

    if command -v jq &>/dev/null; then
        echo "$apps" | jq -r '.[] | "  \(.uuid)  \(.name)  [\(.status // "unknown")]"' 2>/dev/null || \
            echo "  (inga applikationer hittades)"
    else
        echo "$apps" | grep -o '"uuid":"[^"]*"\|"name":"[^"]*"\|"status":"[^"]*"' | \
            paste - - - | sed 's/"uuid":"//g;s/"name":"//g;s/"status":"//g;s/"//g;s/\t/  /g' | \
            awk '{printf "  %-40s %-30s [%s]\n", $1, $2, $3}' || \
            echo "  (inga applikationer hittades)"
    fi
}

cmd_status() {
    section "Pågående Deployments"
    local deployments
    deployments=$(get_deployments)

    if command -v jq &>/dev/null; then
        local count
        count=$(echo "$deployments" | jq '. | length' 2>/dev/null || echo "0")
        if [ "$count" = "0" ]; then
            info "Inga pågående deployments"
        else
            echo "$deployments" | jq -r '.[] | "  \(.uuid)  \(.application_name // .name // "?")  [\(.status)]"' 2>/dev/null
        fi
    else
        echo "$deployments"
    fi
}

cmd_deploy_uuid() {
    local uuid="$1"
    echo -e "  Triggar deploy för: ${CYAN}$uuid${NC}"
    local result
    result=$(curl -sf \
        -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/json" \
        "$API/deploy?uuid=$uuid&force=false" 2>/dev/null || echo "{}")

    if command -v jq &>/dev/null; then
        local msg
        msg=$(echo "$result" | jq -r '.[0].message // .message // "OK"' 2>/dev/null || echo "OK")
        info "$msg"
    else
        info "Deploy triggas"
    fi
}

cmd_deploy_all() {
    section "Deployer Alla Services"

    local services
    services=$(get_services)

    local uuids
    if command -v jq &>/dev/null; then
        uuids=$(echo "$services" | jq -r '.[].uuid' 2>/dev/null || echo "")
    else
        uuids=$(echo "$services" | grep -o '"uuid":"[^"]*"' | sed 's/"uuid":"//;s/"//')
    fi

    if [ -z "$uuids" ]; then
        warn "Inga services hittades"
        return
    fi

    local count=0
    while IFS= read -r uuid; do
        [ -z "$uuid" ] && continue
        cmd_deploy_uuid "$uuid"
        count=$((count + 1))
        sleep 1
    done <<< "$uuids"

    echo ""
    info "Triggate deploy för $count service(s)"
    echo ""
    echo "Följ status med:"
    echo "  $0 status"
    echo "  $COOLIFY_URL/dashboard"
}

cmd_restart() {
    local uuid="$1"
    echo -e "  Startar om service: ${CYAN}$uuid${NC}"

    # Försök som service, sedan som application
    local result
    result=$(api_post "/services/$uuid/restart" 2>/dev/null || \
             api_post "/applications/$uuid/restart" 2>/dev/null || echo "{}")

    if command -v jq &>/dev/null; then
        local msg
        msg=$(echo "$result" | jq -r '.message // "OK"' 2>/dev/null || echo "OK")
        info "$msg"
    else
        info "Omstart triggas"
    fi
}

cmd_interactive() {
    echo -e "${BOLD}Coolify Update${NC} — $COOLIFY_URL"
    echo ""
    echo "  1) Lista alla resurser"
    echo "  2) Deploya alla services (pull ny image + restart)"
    echo "  3) Deploya specifik resurs (UUID)"
    echo "  4) Starta om specifik service (UUID)"
    echo "  5) Visa pågående deployments"
    echo "  q) Avsluta"
    echo ""
    read -rp "Val: " choice

    case "$choice" in
        1) cmd_list ;;
        2)
            warn "Detta kommer att deploya om ALLA services med senaste image."
            read -rp "Fortsätt? (ja/nej): " confirm
            [[ $confirm =~ ^[Jj]a$ ]] && cmd_deploy_all || echo "Avbrutet."
            ;;
        3)
            cmd_list
            echo ""
            read -rp "Ange UUID: " uuid
            [ -n "$uuid" ] && cmd_deploy_uuid "$uuid"
            ;;
        4)
            cmd_list
            echo ""
            read -rp "Ange UUID: " uuid
            [ -n "$uuid" ] && cmd_restart "$uuid"
            ;;
        5) cmd_status ;;
        q|Q) exit 0 ;;
        *) warn "Ogiltigt val" ;;
    esac
}

# ============================================================================
# Main
# ============================================================================
check_auth

CMD="${1:-interactive}"

case "$CMD" in
    list)
        cmd_list
        ;;
    deploy)
        TARGET="${2:-}"
        if [ -z "$TARGET" ]; then
            error "Ange 'all' eller ett UUID: $0 deploy <all|uuid>"
        fi
        if [ "$TARGET" = "all" ]; then
            warn "Detta deployas om ALLA services med senaste image."
            read -rp "Fortsätt? (ja/nej): " confirm
            [[ $confirm =~ ^[Jj]a$ ]] && cmd_deploy_all || echo "Avbrutet."
        else
            section "Deploy"
            cmd_deploy_uuid "$TARGET"
        fi
        ;;
    restart)
        UUID="${2:-}"
        [ -z "$UUID" ] && error "Ange ett UUID: $0 restart <uuid>"
        section "Omstart"
        cmd_restart "$UUID"
        ;;
    status)
        cmd_status
        ;;
    interactive)
        cmd_interactive
        ;;
    *)
        echo "Användning: $0 [list|deploy <all|uuid>|restart <uuid>|status]"
        exit 1
        ;;
esac

echo ""
