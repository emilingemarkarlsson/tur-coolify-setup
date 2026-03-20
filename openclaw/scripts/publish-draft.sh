#!/usr/bin/env bash
# Publicerar en SEO-draft till GitHub: läser draft + metadata, klonar/pullar repo,
# skriver fil, commit, push. Används när användaren skriver "publicera {slug}" i Slack.
#
# Användning: publish-draft.sh <slug>
# Kräver: git, python3 (läser site-repos.json). GITHUB_TOKEN (env) eller /data/.openclaw/github-token. Ingen jq behövs.

set -euo pipefail

SLUG="${1:-}"
if [[ -z "$SLUG" ]]; then
  echo "Usage: $0 <slug>" >&2
  exit 1
fi

DRAFTS_DIR="/data/.openclaw/drafts"
REPOS_DIR="/data/.openclaw/repos"
SITE_REPOS="/data/.openclaw/site-repos.json"

DRAFT_FILE="${DRAFTS_DIR}/${SLUG}.md"
META_FILE="${DRAFTS_DIR}/${SLUG}.meta"

if [[ ! -f "$DRAFT_FILE" ]]; then
  echo "Draft not found: $DRAFT_FILE" >&2
  exit 1
fi
if [[ ! -f "$META_FILE" ]]; then
  echo "Metadata not found: $META_FILE" >&2
  exit 1
fi
if [[ ! -f "$SITE_REPOS" ]]; then
  echo "site-repos.json not found: $SITE_REPOS" >&2
  exit 1
fi

# Clean draft content: strip Slack "Nästa steg" / "Next steps" helper text if it was
# accidentally saved into the markdown file. Everything from the helper line and down
# is removed; the article content above is kept as-is. Matches Swedish and English.
CLEAN_DRAFT_FILE="${DRAFT_FILE}.clean"
trap 'rm -f "$CLEAN_DRAFT_FILE"' EXIT
awk '/^(Nästa steg|Next steps):.*(publicera|publish)/{exit} {print}' "$DRAFT_FILE" > "$CLEAN_DRAFT_FILE"

# umamiName from .meta (format: umamiName=emilingemarkarlsson)
UMAMI_NAME=$(grep -E '^umamiName=' "$META_FILE" | cut -d= -f2- | tr -d '\r\n')
if [[ -z "$UMAMI_NAME" ]]; then
  echo "Could not read umamiName from $META_FILE" >&2
  exit 1
fi

# GitHub token
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  TOKEN="$GITHUB_TOKEN"
elif [[ -f /data/.openclaw/github-token ]]; then
  TOKEN=$(cat /data/.openclaw/github-token | tr -d '\n\r')
else
  echo "GITHUB_TOKEN not set and /data/.openclaw/github-token not found." >&2
  exit 1
fi

if [[ -z "$TOKEN" ]]; then
  echo "GitHub token is empty." >&2
  exit 1
fi

# Repo, contentPath, domain and urlSegment from site-repos.json (python3 only – no jq required)
READOUT=$(python3 -c "
import json, sys
with open(sys.argv[2]) as f:
    data = json.load(f)
for s in data['sites']:
    if s.get('umamiName') == sys.argv[1]:
        print(s.get('githubRepo', ''))
        print(s.get('contentPath', ''))
        print(s.get('domain', ''))
        print(s.get('urlSegment', ''))
        break
" "$UMAMI_NAME" "$SITE_REPOS")
GITHUB_REPO=$(echo "$READOUT" | sed -n '1p')
CONTENT_PATH=$(echo "$READOUT" | sed -n '2p')
DOMAIN=$(echo "$READOUT" | sed -n '3p')
URL_SEGMENT_FROM_JSON=$(echo "$READOUT" | sed -n '4p')

if [[ -z "$GITHUB_REPO" || "$GITHUB_REPO" == "null" ]]; then
  echo "No repo found for umamiName=$UMAMI_NAME in site-repos.json" >&2
  exit 1
fi

# Inject token into HTTPS URL for clone/push (https://github.com/... -> https://TOKEN@github.com/...)
AUTH_REPO_URL="${GITHUB_REPO/https:\/\//https://${TOKEN}@}"

REPO_DIR="${REPOS_DIR}/${UMAMI_NAME}"
TARGET_FILE="${REPO_DIR}/${CONTENT_PATH}/${SLUG}.md"

mkdir -p "$REPOS_DIR"
if [[ ! -d "${REPO_DIR}/.git" ]]; then
  git clone --depth 1 "$AUTH_REPO_URL" "$REPO_DIR"
else
  git -C "$REPO_DIR" pull --rebase
fi

mkdir -p "$(dirname "$TARGET_FILE")"
cp "$CLEAN_DRAFT_FILE" "$TARGET_FILE"

git -C "$REPO_DIR" remote set-url origin "$AUTH_REPO_URL"
git -C "$REPO_DIR" add "$TARGET_FILE"
git -C "$REPO_DIR" -c user.name="OpenClaw SEO" -c user.email="seo@openclaw" commit -m "feat: add SEO article – ${SLUG}"
git -C "$REPO_DIR" push origin HEAD

# Clean up draft files
rm -f "$DRAFT_FILE" "$META_FILE" "$CLEAN_DRAFT_FILE"

# Output for Slack (agent can read this). Use urlSegment from site-repos.json if set,
# otherwise fall back to inferring from contentPath.
if [[ -n "$URL_SEGMENT_FROM_JSON" ]]; then
  URL_SEGMENT="$URL_SEGMENT_FROM_JSON"
elif [[ "$CONTENT_PATH" == *"posts"* ]]; then
  URL_SEGMENT="posts"
else
  URL_SEGMENT="blog"
fi
echo "Published: https://${DOMAIN}/${URL_SEGMENT}/${SLUG}"
echo "Repo: $GITHUB_REPO"
