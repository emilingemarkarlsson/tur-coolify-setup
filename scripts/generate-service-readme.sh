#!/usr/bin/env bash
set -euo pipefail

# generate-service-readme.sh - Genererar README.md för en service

SERVICE_TYPE="${1:-}"
IMAGE="${2:-}"
DOMAIN="${3:-}"

if [ -z "$SERVICE_TYPE" ]; then
    echo "Usage: $0 <service-type> <image> [domain]"
    exit 1
fi

# Om image saknas, använd placeholder
if [ -z "$IMAGE" ]; then
    IMAGE="<image-saknas>"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Service-beskrivningar
case "$SERVICE_TYPE" in
    "n8n")
        DESCRIPTION="Workflow automation platform"
        DOCS_URL="https://docs.n8n.io/"
        GITHUB_URL="https://github.com/n8n-io/n8n"
        ;;
    "minio")
        DESCRIPTION="S3-compatible object storage"
        DOCS_URL="https://min.io/docs/"
        GITHUB_URL="https://github.com/minio/minio"
        ;;
    "open-webui"|*"open-webui"*)
        DESCRIPTION="Open WebUI - ChatGPT-like interface"
        DOCS_URL="https://docs.openwebui.com/"
        GITHUB_URL="https://github.com/open-webui/open-webui"
        ;;
    "umami")
        DESCRIPTION="Umami - Web analytics platform"
        DOCS_URL="https://umami.is/docs"
        GITHUB_URL="https://github.com/umami-software/umami"
        ;;
    "langflow")
        DESCRIPTION="Langflow - Visual editor for building LLM applications"
        DOCS_URL="https://docs.langflow.org/"
        GITHUB_URL="https://github.com/langflow-ai/langflow"
        ;;
    *)
        DESCRIPTION="Service deployed via Coolify"
        DOCS_URL=""
        GITHUB_URL=""
        ;;
esac

# Konvertera till stor första bokstav (bash-kompatibel)
SERVICE_NAME=$(echo "$SERVICE_TYPE" | sed 's/^./\U&/')

{
cat <<EOF
# ${SERVICE_NAME}

${DESCRIPTION}

## Konfiguration

EOF

if [ "$IMAGE" != "<image-saknas>" ]; then
    echo "- **Image:** \`${IMAGE}\`"
else
    echo "- **Image:** *Saknas - kontrollera docker-compose.yml*"
fi

if [ -n "$DOMAIN" ]; then
    echo "- **Domain:** \`${DOMAIN}\`"
fi

cat <<EOF
- **Status:** Aktiv i Coolify

## Uppdateringar

EOF

if [ "$IMAGE" != "<image-saknas>" ]; then
    cat <<EOF
Se [UPGRADE.md](UPGRADE.md) för detaljerad uppdateringsguide.

## Snabbuppdatering

\`\`\`bash
# Via Coolify Dashboard (rekommenderat)
# Gå till: https://coolify.theunnamedroads.com
# Välj service → Edit Compose → Uppdatera image → Deploy
\`\`\`
EOF
else
    cat <<EOF
**⚠️ Image saknas i konfigurationen**

Kontrollera docker-compose.yml för att se vilken image som används.

## Snabbuppdatering

\`\`\`bash
# Via Coolify Dashboard (rekommenderat)
# Gå till: https://coolify.theunnamedroads.com
# Välj service → Edit Compose → Kontrollera/uppdatera image → Deploy
\`\`\`
EOF
fi

cat <<EOF

## Dokumentation

EOF

if [ -n "$DOCS_URL" ]; then
    echo "- **Officiell dokumentation:** ${DOCS_URL}"
fi

if [ -n "$GITHUB_URL" ]; then
    echo "- **GitHub:** ${GITHUB_URL}"
fi

cat <<EOF
- **Uppdateringsguide:** [UPGRADE.md](UPGRADE.md) (om tillgänglig)
- **Coolify Dashboard:** https://coolify.theunnamedroads.com

## Troubleshooting

Se [UPGRADE.md](UPGRADE.md) för troubleshooting-instruktioner (om tillgänglig).

För allmän felsökning, se projektets [TROUBLESHOOTING.md](../TROUBLESHOOTING.md).
EOF

} > "$PROJECT_ROOT/$SERVICE_TYPE/README.md"

echo "✅ Skapade README.md för $SERVICE_TYPE"

