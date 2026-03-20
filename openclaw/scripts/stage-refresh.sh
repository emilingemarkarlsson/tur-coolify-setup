#!/usr/bin/env bash
# Kopierar en befintlig artikel från ett klonat repo till /data/.openclaw/drafts/ för redigering.
# Agenten läser drafts/{slug}.md, modifierar (t.ex. lägger till FAQ-block, uppdaterar dateModified),
# sedan kör publish-draft.sh {slug} för att commit:a och pusha tillbaka.
# Kräver att clone-site.sh har körts först.
#
# Användning: stage-refresh.sh <umamiName> <slug>
# Exempel:    stage-refresh.sh theunnamedroads ai-agent-workflow-automation

set -euo pipefail

SITE_REPOS="/data/.openclaw/site-repos.json"
REPOS_DIR="/data/.openclaw/repos"
DRAFTS_DIR="/data/.openclaw/drafts"

UMAMI_NAME="${1:-}"
SLUG="${2:-}"

if [[ -z "$UMAMI_NAME" || -z "$SLUG" ]]; then
  echo "Usage: $0 <umamiName> <slug>" >&2
  exit 1
fi

if [[ ! -f "$SITE_REPOS" ]]; then
  echo "site-repos.json not found: $SITE_REPOS" >&2
  exit 1
fi

CONTENT_PATH=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
for s in data['sites']:
    if s.get('umamiName') == sys.argv[2]:
        print(s.get('contentPath', ''))
        break
" "$SITE_REPOS" "$UMAMI_NAME")

if [[ -z "$CONTENT_PATH" ]]; then
  echo "Site not found in site-repos.json: $UMAMI_NAME" >&2
  exit 1
fi

REPO_DIR="$REPOS_DIR/$UMAMI_NAME"

if [[ ! -d "$REPO_DIR/.git" ]]; then
  echo "Repo not cloned: $REPO_DIR" >&2
  echo "Run: clone-site.sh $UMAMI_NAME" >&2
  exit 1
fi

# Hitta artikel-filen (.md eller .mdx)
ARTICLE_FILE=""
for ext in md mdx; do
  candidate="$REPO_DIR/$CONTENT_PATH/$SLUG.$ext"
  if [[ -f "$candidate" ]]; then
    ARTICLE_FILE="$candidate"
    break
  fi
done

if [[ -z "$ARTICLE_FILE" ]]; then
  echo "Article not found: $REPO_DIR/$CONTENT_PATH/$SLUG.{md,mdx}" >&2
  exit 1
fi

mkdir -p "$DRAFTS_DIR"
cp "$ARTICLE_FILE" "$DRAFTS_DIR/$SLUG.md"
echo "umamiName=$UMAMI_NAME" > "$DRAFTS_DIR/$SLUG.meta"

echo "Staged för refresh:"
echo "  Draft:  $DRAFTS_DIR/$SLUG.md"
echo "  Meta:   $DRAFTS_DIR/$SLUG.meta"
echo "  Källa:  $ARTICLE_FILE"
echo ""
echo "Redigera $DRAFTS_DIR/$SLUG.md (lägg till FAQ-block, uppdatera dateModified)."
echo "Sedan kör: publish-draft.sh $SLUG"
