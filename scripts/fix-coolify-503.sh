#!/usr/bin/env bash
set -euo pipefail

# fix-coolify-503.sh - Fixar 503 på Coolify via Traefik dynamisk config
# Coolify-containern saknar Traefik labels, så Traefik fångar trafik med catchall
# som pekar på tom server → 503. Detta script lägger till en explicit route.

HOST="${1:-tha}"
DOMAIN="${2:-coolify.theunnamedroads.com}"

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

echo "🔧 Fixar Coolify 503 – Traefik Dynamisk Config"
echo "==============================================="
echo ""
info "Domain: $DOMAIN"
echo ""

# ============================================================================
# STEG 1: Skapa dynamisk Traefik-config för Coolify
# ============================================================================
section "STEG 1: Lägger till Traefik-routing för Coolify"

CONFIG_CONTENT="# Coolify dashboard route - fix för 503
# Skapad av fix-coolify-503.sh
http:
  routers:
    coolify-dashboard-https:
      rule: \"Host(\`${DOMAIN}\`)\"
      entryPoints:
        - https
      service: coolify-dashboard
      tls:
        certResolver: letsencrypt
      priority: 100
    coolify-dashboard-http:
      rule: \"Host(\`${DOMAIN}\`)\"
      entryPoints:
        - http
      service: coolify-dashboard
      priority: 100
  services:
    coolify-dashboard:
      loadBalancer:
        servers:
          - url: \"http://coolify:8080\"
        passHostHeader: true
"

echo "📝 Skapar Traefik dynamisk config..."

echo "$CONFIG_CONTENT" | ssh "$HOST" 'mkdir -p /data/coolify/proxy/dynamic && cat > /data/coolify/proxy/dynamic/coolify-dashboard-route.yaml'

ssh "$HOST" 'echo "  ✅ Config skapad: /data/coolify/proxy/dynamic/coolify-dashboard-route.yaml" && echo "" && echo "  📋 Innehåll:" && cat /data/coolify/proxy/dynamic/coolify-dashboard-route.yaml'

# ============================================================================
# STEG 2: Traefik laddar om automatiskt (file watch)
# ============================================================================
section "STEG 2: Traefik laddar om"

echo "Traefik har providers.file.watch=true – config laddas automatiskt."
echo "Väntar 5 sekunder..."
sleep 5
echo ""

# ============================================================================
# STEG 3: Verifiera
# ============================================================================
section "STEG 3: Verifierar Coolify Dashboard"

echo "🔍 Testar $DOMAIN..."
echo ""

HTTP_CODE=$(curl -I -s --max-time 15 "https://$DOMAIN" 2>/dev/null | head -1 | awk '{print $2}' || echo "000")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
    info "Coolify dashboard nåbar! (HTTP $HTTP_CODE)"
    echo ""
    echo "  🌐 Öppna: https://$DOMAIN"
else
    warn "Dashboard svarar ännu med HTTP $HTTP_CODE"
    echo ""
    echo "  💡 Vänta 30–60 sek för SSL-certifikat (Let's Encrypt)"
    echo "  Testa igen: curl -I https://$DOMAIN"
    echo ""
    echo "  Om 503 kvarstår:"
    echo "  • Kontrollera att coolify-containern körs: ssh $HOST 'docker ps | grep coolify'"
    echo "  • Kontrollera Traefik logs: ssh $HOST 'docker logs coolify-proxy --tail 20'"
fi

# ============================================================================
# SAMMANFATTNING
# ============================================================================
section "📊 Sammanfattning"

echo ""
info "Fix klar!"
echo ""
echo "  Config: /data/coolify/proxy/dynamic/coolify-dashboard-route.yaml"
echo "  Dashboard: https://$DOMAIN"
echo ""
echo "  Om du konfigurerar domän i Coolify UI (Settings → Proxy) kan du"
echo "  ta bort denna fil – Coolify hanterar då routingen själv."
echo ""
