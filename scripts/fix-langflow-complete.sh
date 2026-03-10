#!/usr/bin/env bash
set -euo pipefail

# fix-langflow-complete.sh - Komplett fix för Langflow 404

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

echo "🔧 Komplett Fix för Langflow"
echo "============================"
echo ""

ssh "$HOST" bash <<REMOTE
set -e

CONTAINER="langflow-rog04sw8kcc0g848cs4cocso"
SERVICE_DIR="/data/coolify/services/rog04sw8kcc0g848cs4cocso"
DOMAIN="$DOMAIN"

echo "📦 Steg 1: Startar container..."
docker start "$CONTAINER" 2>/dev/null || docker-compose -f "$SERVICE_DIR/docker-compose.yml" up -d 2>/dev/null || true
sleep 2

echo ""
echo "🏷️  Steg 2: Lägger till Traefik labels..."

cd "$SERVICE_DIR"

# Backup
cp docker-compose.yml docker-compose.yml.backup.$(date +%s) 2>/dev/null || true

# Skapa komplett docker-compose.yml med alla labels
cat > docker-compose.yml <<EOF
services:
  langflow:
    image: 'langflowai/langflow:latest'
    environment:
      - SERVICE_URL_LANGFLOW_7860
      - LANGFLOW_HOST=0.0.0.0
      - LANGFLOW_PORT=7860
      - LANGFLOW_LOG_LEVEL=INFO
    volumes:
      - 'langflow_data:/app/data'
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.langflow.rule=Host(\`$DOMAIN\`)"
      - "traefik.http.routers.langflow.entrypoints=https"
      - "traefik.http.routers.langflow.tls=true"
      - "traefik.http.routers.langflow.tls.certresolver=letsencrypt"
      - "traefik.http.services.langflow.loadbalancer.server.port=7860"
      - "traefik.http.routers.langflow.service=langflow"
      - "traefik.http.routers.langflow-http.entrypoints=http"
      - "traefik.http.routers.langflow-http.rule=Host(\`$DOMAIN\`)"
      - "traefik.http.routers.langflow-http.middlewares=redirect-to-https"
      - "traefik.http.routers.langflow-http.service=langflow"
      - "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https"
      - "traefik.http.middlewares.redirect-to-https.redirectscheme.permanent=true"
    healthcheck:
      test:
        - CMD
        - curl
        - '-f'
        - 'http://127.0.0.1:7860'
      interval: 5s
      timeout: 30s
      retries: 10
    networks:
      - coolify
    restart: unless-stopped

volumes:
  langflow_data: null

networks:
  coolify:
    external: true
EOF

echo "✅ docker-compose.yml uppdaterad"
echo ""

echo "🔄 Steg 3: Startar om service..."
docker-compose down 2>/dev/null || true
docker-compose up -d

echo ""
echo "🌐 Steg 4: Ansluter till coolify-nätverket..."
# Vänta lite för att containern ska starta
sleep 3

# Anslut till coolify-nätverket om det inte redan är gjort
if docker network inspect coolify >/dev/null 2>&1; then
    if ! docker inspect "$CONTAINER" --format '{{range \$net, \$conf := .NetworkSettings.Networks}}{{\$net}}{{println}}{{end}}' 2>/dev/null | grep -q "coolify"; then
        docker network connect coolify "$CONTAINER" 2>/dev/null || echo "Kunde inte ansluta (kan redan vara ansluten)"
    else
        echo "  ✅ Redan ansluten till coolify-nätverket"
    fi
else
    echo "  ⚠️  coolify-nätverket finns inte - skapas automatiskt av Coolify"
fi

echo ""
echo "📊 Steg 5: Verifierar..."
sleep 2

# Kontrollera status
if docker ps --filter "name=$CONTAINER" --format '{{.State.Status}}' | grep -q "running"; then
    echo "  ✅ Container körs"
else
    echo "  ⚠️  Container körs inte - kontrollera logs:"
    docker logs "$CONTAINER" --tail 10 2>/dev/null || true
fi

# Kontrollera labels
if docker inspect "$CONTAINER" --format '{{index .Config.Labels "traefik.http.routers.langflow.rule"}}' 2>/dev/null | grep -q "$DOMAIN"; then
    echo "  ✅ Traefik labels korrekta"
else
    echo "  ⚠️  Traefik labels kan saknas"
fi

# Kontrollera network
if docker inspect "$CONTAINER" --format '{{range \$net, \$conf := .NetworkSettings.Networks}}{{\$net}}{{println}}{{end}}' 2>/dev/null | grep -q "coolify"; then
    echo "  ✅ Ansluten till coolify-nätverket"
else
    echo "  ⚠️  Inte ansluten till coolify-nätverket"
fi

echo ""
echo "✅ Fix klar!"
echo ""
echo "💡 Vänta 1-2 minuter och testa:"
echo "   http://$DOMAIN"
echo ""
REMOTE

echo ""
info "Komplett fix genomförd!"
echo ""
echo "📋 Nästa steg:"
echo "   1. Vänta 1-2 minuter för Traefik att uppdatera"
echo "   2. Testa: http://$DOMAIN"
echo "   3. Om det fortfarande inte fungerar, kontrollera Traefik logs:"
echo "      ssh $HOST 'docker logs traefik --tail 50'"
echo ""


