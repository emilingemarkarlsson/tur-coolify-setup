#!/usr/bin/env bash
# Open WebUI – återställ lösenord (kör på servern där Docker kör).
# Användning: ./openwebui-reset-password.sh "din@epost.com" "NyttLösenord"

set -euo pipefail
EMAIL="${1:-}"
PASS="${2:-}"
VOLUME="${OPENWEBUI_VOLUME:-open-webui}"

if [[ -z "$EMAIL" || -z "$PASS" ]]; then
  echo "Användning: $0 \"din@epost.com\" \"NyttLösenord\""
  exit 1
fi

echo "Uppdaterar lösenord..."
docker run --rm -e "OW_EMAIL=$EMAIL" -e "OW_PASS=$PASS" -v "${VOLUME}:/data" alpine sh -c '
  apk add apache2-utils sqlite --no-cache -q >/dev/null
  HASH=$(htpasswd -bnBC 10 "" "$OW_PASS" | tr -d ":\n")
  sqlite3 /data/webui.db "UPDATE auth SET password='"'"'$HASH'"'"' WHERE email='"'"'$OW_EMAIL'"'"';"'
echo "Klart. Logga in på https://webui.theunnamedroads.com med det nya lösenordet."
