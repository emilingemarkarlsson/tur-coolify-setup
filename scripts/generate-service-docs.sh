#!/usr/bin/env bash
set -euo pipefail

# generate-service-docs.sh - Genererar UPGRADE.md för en service baserat på image och best practices

HOST="${1:-}"
SERVICE_ID="${2:-}"
SERVICE_TYPE="${3:-}"
IMAGE="${4:-}"
DOMAIN="${5:-}"

if [ -z "$SERVICE_TYPE" ]; then
    echo "Usage: $0 <host> <service-id> <service-type> <image> [domain]"
    exit 1
fi

# Om image saknas, försök hämta från docker-compose.yml
if [ -z "$IMAGE" ] && [ -n "$HOST" ] && [ -n "$SERVICE_ID" ]; then
    IMAGE=$(ssh "$HOST" "grep -E '^\s+image:' /data/coolify/services/$SERVICE_ID/docker-compose.yml 2>/dev/null | grep -v postgres | grep -v redis | head -1 | sed 's/.*image:[[:space:]]*//' | tr -d \"'\" || echo \"\"")
fi

# Om fortfarande ingen image, använd placeholder
if [ -z "$IMAGE" ]; then
    IMAGE="<image-saknas>"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Identifiera image repository och tag
if [ "$IMAGE" != "<image-saknas>" ]; then
    REPO=$(echo "$IMAGE" | cut -d: -f1)
    TAG=$(echo "$IMAGE" | cut -d: -f2)
    if [ "$TAG" = "$IMAGE" ]; then
        TAG="latest"
    fi
    
    # Extrahera repo-namn utan registry
    REPO_NAME=$(echo "$REPO" | sed 's|^[^/]*/||')
else
    REPO=""
    TAG="latest"
    REPO_NAME=""
fi

# Hämta senaste version från Docker Hub API (om möjligt)
get_latest_version() {
    local repo_name=$1
    local current_tag=$2
    
    # Försök hämta från Docker Hub/GitHub Container Registry API
    case "$repo_name" in
        "n8n")
            curl -s "https://hub.docker.com/v2/repositories/n8nio/n8n/tags?page_size=5" 2>/dev/null | \
                grep -oE '"name":"[0-9]+\.[0-9]+\.[0-9]+"' | head -1 | cut -d'"' -f4 || echo "$current_tag"
            ;;
        "minio")
            curl -s "https://quay.io/api/v1/repository/minio/minio/tag" 2>/dev/null | \
                grep -oE '"name":"RELEASE\.[^"]+"' | head -1 | cut -d'"' -f4 || echo "$current_tag"
            ;;
        "open-webui")
            # GitHub Container Registry
            curl -s "https://api.github.com/repos/open-webui/open-webui/releases/latest" 2>/dev/null | \
                grep -oE '"tag_name":"[^"]+"' | head -1 | cut -d'"' -f4 || echo "$current_tag"
            ;;
        "umami")
            # GitHub Container Registry
            curl -s "https://api.github.com/repos/umami-software/umami/releases/latest" 2>/dev/null | \
                grep -oE '"tag_name":"[^"]+"' | head -1 | cut -d'"' -f4 || echo "$current_tag"
            ;;
        "langflow")
            # Docker Hub
            curl -s "https://hub.docker.com/v2/repositories/langflowai/langflow/tags?page_size=5" 2>/dev/null | \
                grep -oE '"name":"[^"]+"' | head -1 | cut -d'"' -f4 | grep -v "latest" || echo "$current_tag"
            ;;
        *)
            echo "$current_tag"
            ;;
    esac
}

if [ -n "$REPO_NAME" ]; then
    LATEST_VERSION=$(get_latest_version "$REPO_NAME" "$TAG")
else
    LATEST_VERSION=""
fi

# Konvertera till stor första bokstav (bash-kompatibel)
SERVICE_NAME=$(echo "$SERVICE_TYPE" | sed 's/^./\U&/')

# Generera UPGRADE.md
{
cat <<EOF
# 🔄 ${SERVICE_NAME} - Uppdateringsguide

## Nuvarande Konfiguration

EOF

if [ "$IMAGE" != "<image-saknas>" ]; then
    echo "- **Image:** \`${IMAGE}\`"
else
    echo "- **Image:** *Saknas - kontrollera docker-compose.yml i Coolify*"
fi

echo "- **Directory:** \`${SERVICE_TYPE}/\`"

if [ -n "$DOMAIN" ]; then
    echo "- **Domain:** \`${DOMAIN}\`"
fi

echo "- **Status:** Aktiv i Coolify"

if [ -n "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "$TAG" ] && [ "$IMAGE" != "<image-saknas>" ]; then
    echo "- **Senaste tillgänglig version:** \`${LATEST_VERSION}\` (kontrollera Docker Hub/Quay.io för bekräftelse)"
fi

cat <<EOF

## Uppdatera ${SERVICE_NAME}

### Metod 1: Via Coolify Dashboard (Rekommenderat)

1. **Öppna Coolify Dashboard**
   - Gå till: https://coolify.theunnamedroads.com
   - Logga in

2. **Välj ${SERVICE_NAME} Service**
   - Klicka på ${SERVICE_NAME} service

3. **Uppdatera Image**
   - Klicka på "Edit Compose"
EOF

if [ "$IMAGE" != "<image-saknas>" ]; then
    echo "   - Ändra image från \`${IMAGE}\` till senaste version"
    if [ -n "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "$TAG" ]; then
        echo "   - Rekommenderat: \`${REPO}:${LATEST_VERSION}\`"
    fi
else
    echo "   - Kontrollera vilken image som används i docker-compose.yml"
    echo "   - Uppdatera till senaste version"
fi

cat <<EOF
   - Klicka "Deploy"

### Metod 2: Via SSH (Manuellt)

\`\`\`bash
# 1. SSH till servern
ssh tha

# 2. Hitta ${SERVICE_NAME} service directory
ls -la /data/coolify/services/ | grep ${SERVICE_ID}

# 3. Gå till ${SERVICE_NAME} service
cd /data/coolify/services/${SERVICE_ID}

# 4. Redigera docker-compose.yml
nano docker-compose.yml

# 5. Uppdatera image-tag
EOF

if [ "$IMAGE" != "<image-saknas>" ]; then
    echo "# Ändra från: image: ${IMAGE}"
    if [ -n "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "$TAG" ]; then
        echo "# Till: image: ${REPO}:${LATEST_VERSION}"
    fi
else
    echo "# Kontrollera vilken image som används"
    echo "# Uppdatera till senaste version"
fi

cat <<EOF

# 6. Uppdatera och starta om
docker compose pull
docker compose up -d

# 7. Verifiera
docker compose ps
docker logs <${SERVICE_TYPE}-container-name> --tail 20
\`\`\`

## Hitta Senaste Version

EOF

if [ "$IMAGE" != "<image-saknas>" ]; then
    echo "**Docker Hub/Quay.io:**"
    echo ""
    
    # Lägg till specifika länkar baserat på service-typ
    case "$SERVICE_TYPE" in
        "n8n")
            echo "- https://hub.docker.com/r/n8nio/n8n/tags"
            echo "- https://github.com/n8n-io/n8n/releases"
            ;;
        "minio")
            echo "- https://quay.io/repository/minio/minio?tab=tags"
            echo "- https://github.com/minio/minio/releases"
            ;;
        "open-webui")
            echo "- https://github.com/open-webui/open-webui/releases"
            echo "- https://hub.docker.com/r/openwebui/open-webui/tags"
            ;;
        "umami")
            echo "- https://github.com/umami-software/umami/releases"
            echo "- https://hub.docker.com/r/ghcr.io/umami-software/umami/tags"
            ;;
        "langflow")
            echo "- https://github.com/langflow-ai/langflow/releases"
            echo "- https://hub.docker.com/r/langflowai/langflow/tags"
            ;;
        *)
            # Försök extrahera repo från image
            if [[ "$REPO" == *"/"* ]]; then
                # GitHub Container Registry
                if [[ "$REPO" == "ghcr.io"* ]]; then
                    GITHUB_REPO=$(echo "$REPO" | sed 's|ghcr.io/||')
                    echo "- https://github.com/${GITHUB_REPO}/releases"
                else
                    echo "- https://hub.docker.com/r/${REPO_NAME}/tags"
                fi
            fi
            ;;
    esac
else
    echo "**⚠️ Image saknas - kontrollera docker-compose.yml i Coolify för att se vilken image som används.**"
fi

cat <<EOF

**Rekommendation:**
- Använd specifika versioner istället för \`:latest\`
- Format varierar per service (se Docker Hub/Quay.io)
- Undvik beta/alpha-versioner i produktion

## Breaking Changes

**Viktigt:** Kontrollera alltid release notes för breaking changes:
- GitHub Releases för ${SERVICE_NAME}
- Docker Hub/Quay.io release notes

**Vanliga breaking changes:**
- Major version-uppgraderingar
- API-ändringar
- Konfigurationsändringar

## Verifiera Uppdatering

Efter uppdatering, kontrollera:

\`\`\`bash
# Kontrollera container status
ssh tha 'docker ps | grep ${SERVICE_TYPE}'

# Kontrollera logs
ssh tha 'docker logs <${SERVICE_TYPE}-container-name> --tail 50'
EOF

if [ -n "$DOMAIN" ]; then
    cat <<EOF
# Testa ${SERVICE_NAME} dashboard
curl -I https://${DOMAIN}
EOF
fi

cat <<EOF
\`\`\`

## Backup innan Uppdatering

**Viktigt:** Säkerhetskopiera data innan större uppdateringar:

\`\`\`bash
# Backup ${SERVICE_NAME} data volume
ssh tha 'docker run --rm -v ${SERVICE_TYPE}_data:/data -v \$(pwd):/backup alpine tar czf /backup/${SERVICE_TYPE}-backup-\$(date +%Y%m%d).tar.gz /data'
\`\`\`

## Best Practices

1. **Använd specifika versioner** istället för \`:latest\`
2. **Testa i staging** först (om möjligt)
3. **Säkerhetskopiera data** innan större uppdateringar
4. **Läs release notes** för breaking changes
5. **Uppdatera regelbundet** för säkerhetsuppdateringar

## Troubleshooting

### Service startar inte efter uppdatering

\`\`\`bash
# Kolla logs
ssh tha 'docker logs <${SERVICE_TYPE}-container-name>'

# Starta om service
ssh tha 'cd /data/coolify/services/${SERVICE_ID} && docker compose restart'
\`\`\`

## Ytterligare Resurser

- **Coolify Dashboard:** https://coolify.theunnamedroads.com
- **Service Directory:** \`${SERVICE_TYPE}/\`
EOF

} > "$PROJECT_ROOT/$SERVICE_TYPE/UPGRADE.md"

echo "✅ Skapade UPGRADE.md för $SERVICE_TYPE"
