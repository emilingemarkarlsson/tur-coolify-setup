#!/usr/bin/env bash
set -euo pipefail

# quick-test-langflow.sh - Snabb test av Langflow

HOST="${1:-tha}"

echo "🔍 Snabb Test av Langflow"
echo "========================="
echo ""

ssh "$HOST" bash <<'REMOTE'
CONTAINER="langflow-rog04sw8kcc0g848cs4cocso"
DOMAIN="langflow-rog04sw8kcc0g848cs4cocso.46.62.206.47.sslip.io"

echo "1. Container status:"
docker ps --filter "name=$CONTAINER" --format '  {{.Names}}: {{.State.Status}}' || echo "  ❌ Container körs inte"

echo ""
echo "2. Testar port 7860 direkt:"
if docker exec "$CONTAINER" curl -sf http://127.0.0.1:7860 >/dev/null 2>&1; then
    echo "  ✅ Port 7860 svarar"
else
    echo "  ❌ Port 7860 svarar inte"
    echo "  📋 Logs:"
    docker logs "$CONTAINER" --tail 5 2>/dev/null | sed 's/^/    /'
fi

echo ""
echo "3. Traefik status:"
TRAEFIK=$(docker ps --filter "name=traefik" --format '{{.Names}}' 2>/dev/null | head -1 || docker ps --filter "name=coolify-proxy" --format '{{.Names}}' 2>/dev/null | head -1 || echo "")
if [ -n "$TRAEFIK" ]; then
    echo "  ✅ Traefik körs: $TRAEFIK"
else
    echo "  ❌ Traefik körs inte"
fi

echo ""
echo "4. Testar via Traefik (localhost med Host header):"
if curl -sf --max-time 5 -H "Host: $DOMAIN" http://localhost >/dev/null 2>&1; then
    echo "  ✅ Traefik routar korrekt"
else
    echo "  ❌ Traefik routar INTE"
    echo "  📋 Traefik logs (senaste med langflow):"
    if [ -n "$TRAEFIK" ]; then
        docker logs "$TRAEFIK" --tail 30 2>/dev/null | grep -i langflow | tail -5 | sed 's/^/    /' || echo "    Inga langflow-referenser"
    fi
fi

echo ""
echo "5. Traefik labels på container:"
RULE=$(docker inspect "$CONTAINER" --format '{{index .Config.Labels "traefik.http.routers.langflow-http.rule"}}' 2>/dev/null || echo "")
if [ -n "$RULE" ]; then
    echo "  ✅ HTTP Router rule: $RULE"
else
    echo "  ❌ HTTP Router rule saknas"
fi

SERVICE=$(docker inspect "$CONTAINER" --format '{{index .Config.Labels "traefik.http.services.langflow-svc.loadbalancer.server.port"}}' 2>/dev/null || echo "")
if [ -n "$SERVICE" ]; then
    echo "  ✅ Service port: $SERVICE"
else
    echo "  ❌ Service port saknas"
fi
REMOTE

echo ""
echo "💡 Om Traefik routar korrekt men du fortfarande får 404:"
echo "   - Vänta 1-2 minuter efter deployment"
echo "   - Starta om Traefik: Settings → Proxy → Restart"
echo ""
echo "💡 Cloudflare subdomän är bättre lösning - se instruktioner nedan"
echo ""


