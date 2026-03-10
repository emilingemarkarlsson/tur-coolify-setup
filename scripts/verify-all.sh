#!/usr/bin/env bash
set -euo pipefail

# verify-all.sh - Komplett verifiering av Coolify och Hetzner-plattformen
# Verifierar att allt är uppdaterat och fungerar korrekt

HOST="${1:-tha}"
SERVER_IP="46.62.206.47"

# Färger
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
section() { echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${BLUE}$1${NC}"; }

echo "🔍 Komplett verifiering av Coolify & Hetzner-plattformen"
echo "=========================================================="

# ============================================================================
# STEG 1: Serveranslutning
# ============================================================================
section "1️⃣  Serveranslutning"

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

# ============================================================================
# STEG 2: Serveruppdateringar
# ============================================================================
section "2️⃣  Serveruppdateringar"

ssh "$HOST" bash <<'REMOTE'
echo "📦 Systemuppdateringar:"
UPDATES=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l)
if [ "$UPDATES" -eq 0 ]; then
    echo "  ✅ Alla paket är uppdaterade (0 uppdateringar tillgängliga)"
else
    echo "  ⚠️  $UPDATES paket kan uppdateras"
    echo "     Kör: ./scripts/update-server.sh"
fi

echo ""
echo "🔄 Systemversion:"
echo "  OS: $(lsb_release -d | cut -f2)"
echo "  Kernel: $(uname -r)"
echo "  Uptime: $(uptime -p)"

echo ""
echo "💾 Resurser:"
echo "  Disk: $(df -h / | awk 'NR==2 {print $5 " used (" $3 "/" $2 ")"}')"
echo "  Memory: $(free -h | awk 'NR==2 {print $3 "/" $2}')"
echo "  Swap: $(free -h | awk 'NR==3 {print $3 "/" $2}')"
echo "  Load: $(uptime | awk -F'load average:' '{print $2}')"
REMOTE

# ============================================================================
# STEG 3: Docker Status
# ============================================================================
section "3️⃣  Docker Status"

ssh "$HOST" bash <<'REMOTE'
echo "🐳 Docker:"
if systemctl is-active docker >/dev/null 2>&1; then
    echo "  ✅ Docker-tjänst körs"
    echo "  Version: $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
else
    echo "  ❌ Docker-tjänst körs INTE"
    exit 1
fi

echo ""
echo "📦 Containers:"
RUNNING=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)
TOTAL=$(docker ps -a --format '{{.Names}}' 2>/dev/null | wc -l)
echo "  Körs: $RUNNING / $TOTAL totalt"

if [ "$RUNNING" -gt 0 ]; then
    echo ""
    echo "  Aktiva containers:"
    docker ps --format "    • {{.Names}} ({{.Status}})" 2>/dev/null | head -10
fi
REMOTE

# ============================================================================
# STEG 4: Coolify Status
# ============================================================================
section "4️⃣  Coolify Status"

ssh "$HOST" bash <<'REMOTE'
echo "🔧 Coolify Installation:"
if [ -d "/data/coolify/source" ]; then
    echo "  ✅ Hittad i /data/coolify/source"
    cd /data/coolify/source
    
    echo ""
    echo "📋 Coolify Containers:"
    if command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1; then
        docker compose ps 2>/dev/null || docker-compose ps 2>/dev/null | head -20
    else
        echo "  ⚠️  Docker Compose ej tillgängligt"
    fi
    
    echo ""
    echo "🌐 Coolify Services:"
    COOLIFY_CONTAINERS=$(docker ps --filter "name=coolify" --format '{{.Names}}' 2>/dev/null | wc -l)
    echo "  Coolify-containers körs: $COOLIFY_CONTAINERS"
    
    if [ "$COOLIFY_CONTAINERS" -gt 0 ]; then
        echo ""
        docker ps --filter "name=coolify" --format "    • {{.Names}} ({{.Status}})" 2>/dev/null
    fi
else
    echo "  ❌ Coolify installation ej hittad i /data/coolify/source"
    echo "     Sök efter: find / -name '*coolify*' -type d 2>/dev/null"
fi
REMOTE

# ============================================================================
# STEG 5: Externa Endpoints
# ============================================================================
section "5️⃣  Externa Endpoints"

echo "🌐 DNS & HTTPS-tester:"

domains=(
    "analytics.thehockeyanalytics.com"
    "coolify.theunnamedroads.com"
)

for domain in "${domains[@]}"; do
    echo -n "  $domain: "
    
    # DNS
    if nslookup "$domain" >/dev/null 2>&1; then
        echo -n "DNS✅ "
    else
        echo -n "DNS❌ "
    fi
    
    # HTTPS
    if curl -I -s --max-time 10 "https://$domain" >/dev/null 2>&1; then
        echo "HTTPS✅"
    else
        echo "HTTPS❌"
    fi
done

# ============================================================================
# STEG 6: Coolify Dashboard
# ============================================================================
section "6️⃣  Coolify Dashboard"

echo -n "  https://coolify.theunnamedroads.com: "
if curl -I -s --max-time 10 "https://coolify.theunnamedroads.com" >/dev/null 2>&1; then
    info "Nåbar"
    echo "     Öppna i webbläsare för att logga in"
else
    error "Ej nåbar"
    echo "     Kontrollera att Coolify-containers körs"
fi

# ============================================================================
# STEG 7: Systemhälsa
# ============================================================================
section "7️⃣  Systemhälsa"

ssh "$HOST" bash <<'REMOTE'
echo "🔍 Systemhälsa:"

# Zombie processes
ZOMBIES=$(ps aux | awk '$8 ~ /^Z/ {print $2}' | wc -l)
if [ "$ZOMBIES" -gt 0 ]; then
    echo "  ⚠️  $ZOMBIES zombie processes (normalt efter uppdateringar)"
else
    echo "  ✅ Inga zombie processes"
fi

# Disk space
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "  ⚠️  Disk usage: ${DISK_USAGE}% (högt!)"
elif [ "$DISK_USAGE" -gt 70 ]; then
    echo "  ⚠️  Disk usage: ${DISK_USAGE}% (övervaka)"
else
    echo "  ✅ Disk usage: ${DISK_USAGE}%"
fi

# Memory
MEM_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
if [ "$MEM_USAGE" -gt 90 ]; then
    echo "  ⚠️  Memory usage: ${MEM_USAGE}% (högt!)"
else
    echo "  ✅ Memory usage: ${MEM_USAGE}%"
fi

# Swap
SWAP_USAGE=$(free | awk 'NR==3{printf "%.0f", ($3*100)/$2}' 2>/dev/null || echo "0")
if [ "$SWAP_USAGE" -gt 50 ]; then
    echo "  ⚠️  Swap usage: ${SWAP_USAGE}% (högt - överväg mer RAM)"
else
    echo "  ✅ Swap usage: ${SWAP_USAGE}%"
fi
REMOTE

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning"

echo ""
echo "✅ Verifiering klar!"
echo ""
echo "💡 Nästa steg:"
echo "  • Lista alla Coolify-resurser: ./scripts/list-coolify-resources.sh"
echo "  • Öppna Coolify: https://coolify.theunnamedroads.com"
echo "  • Kontrollera services i Coolify dashboard"
echo "  • Om uppdateringar behövs: ./scripts/update-server.sh"
echo ""
echo "🔧 Ytterligare kommandon:"
echo "  • Lista resurser: ./scripts/list-coolify-resources.sh"
echo "  • Snabb status: ./scripts/quick-ssh.sh"
echo "  • Full diagnostik: ./scripts/diagnose.sh"
echo "  • SSH direkt: ssh $HOST"
echo ""

