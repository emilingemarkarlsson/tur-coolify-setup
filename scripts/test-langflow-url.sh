#!/usr/bin/env bash
set -euo pipefail

# test-langflow-url.sh - Testar Langflow URL

HOST="${1:-tha}"
DOMAIN="${2:-langflow-rog04sw8kcc0g848cs4cocso.46.62.206.47.sslip.io}"

# Färger
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

echo "🔍 Testar Langflow URL"
echo "====================="
echo ""

echo "📋 Rätt URL (utan port):"
echo "   http://$DOMAIN"
echo ""
echo "❌ Fel URL (med port):"
echo "   http://$DOMAIN:7860"
echo ""
warn "Traefik hanterar port-forwarding automatiskt - använd INTE port i URL:en!"
echo ""

# Testa från servern
echo "🌐 Testar från servern..."
ssh "$HOST" bash <<REMOTE
DOMAIN="$DOMAIN"

echo "1️⃣  Testar direkt mot container (port 7860):"
if docker exec langflow-rog04sw8kcc0g848cs4cocso curl -sf http://127.0.0.1:7860 >/dev/null 2>&1; then
    echo "  ✅ Container svarar på port 7860"
else
    echo "  ❌ Container svarar inte på port 7860"
    echo "  📋 Container logs:"
    docker logs langflow-rog04sw8kcc0g848cs4cocso --tail 10 2>/dev/null | sed 's/^/    /'
fi

echo ""
echo "2️⃣  Testar via Traefik (HTTP, port 80):"
if curl -sf -H "Host: $DOMAIN" http://localhost >/dev/null 2>&1; then
    echo "  ✅ Traefik svarar på HTTP"
else
    echo "  ⚠️  Traefik svarar inte på HTTP (kan vara normalt om bara HTTPS är aktiverat)"
fi

echo ""
echo "3️⃣  Testar via Traefik (HTTPS, port 443):"
if curl -sfk -H "Host: $DOMAIN" https://localhost >/dev/null 2>&1; then
    echo "  ✅ Traefik svarar på HTTPS"
else
    echo "  ⚠️  Traefik svarar inte på HTTPS"
fi

echo ""
echo "4️⃣  Kontrollerar Traefik routing:"
TRAEFIK_CONTAINER="coolify-proxy"
if docker ps --filter "name=$TRAEFIK_CONTAINER" --format '{{.State.Status}}' | grep -q "running"; then
    echo "  ✅ Traefik körs"
    echo ""
    echo "  📋 Traefik logs (senaste 10 raderna med langflow):"
    docker logs "$TRAEFIK_CONTAINER" --tail 50 2>/dev/null | grep -i langflow | tail -5 | sed 's/^/    /' || echo "    Inga langflow-referenser"
else
    echo "  ❌ Traefik körs inte!"
fi
REMOTE

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 INSTRUKTIONER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Använd denna URL (utan port):"
echo "   http://$DOMAIN"
echo ""
echo "2. Om det fortfarande inte fungerar:"
echo "   - Kontrollera att Traefik körs: ssh $HOST 'docker ps | grep traefik'"
echo "   - Kontrollera att Langflow körs: ssh $HOST 'docker ps | grep langflow'"
echo "   - Vänta 1-2 minuter efter start för Traefik att uppdatera routing"
echo ""
echo "3. För sslip.io-domäner, använd HTTP (inte HTTPS):"
echo "   http://$DOMAIN"
echo ""


