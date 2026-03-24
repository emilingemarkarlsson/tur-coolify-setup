#!/usr/bin/env bash
# Publicerar en SEO-draft till thehockeybrain.com (Next.js).
#
# thehockeybrain använder lib/posts.ts (TypeScript-objekt med HTML-content),
# INTE markdown-filer i src/content/blog/. Detta script:
#   1. Konverterar markdown-draften till HTML med python3 (markdown-bibliotek)
#   2. Extraherar frontmatter-fält
#   3. Injicerar ett nytt BlogPost-objekt i lib/posts.ts
#   4. Committar och pushar
#
# Användning: publish-draft-thehockeybrain.sh <slug>
# Kräver: git, python3. GITHUB_TOKEN (env) eller /data/.openclaw/github-token.

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
  echo "Draft not found: $DRAFT_FILE" >&2; exit 1
fi
if [[ ! -f "$META_FILE" ]]; then
  echo "Metadata not found: $META_FILE" >&2; exit 1
fi

# GitHub token
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  TOKEN="$GITHUB_TOKEN"
elif [[ -f /data/.openclaw/github-token ]]; then
  TOKEN=$(cat /data/.openclaw/github-token | tr -d '\n\r')
else
  echo "GITHUB_TOKEN not set and /data/.openclaw/github-token not found." >&2; exit 1
fi

# Read repo info from site-repos.json
READOUT=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
for s in data['sites']:
    if s.get('umamiName') == 'thehockeybrain':
        print(s.get('githubRepo',''))
        print(s.get('domain',''))
        print(s.get('projectName',''))
        print(s.get('listUuid',''))
        break
" "$SITE_REPOS")
GITHUB_REPO=$(echo "$READOUT" | sed -n '1p')
DOMAIN=$(echo "$READOUT" | sed -n '2p')
PROJECT_NAME=$(echo "$READOUT" | sed -n '3p')
LIST_UUID=$(echo "$READOUT" | sed -n '4p')

AUTH_REPO_URL="${GITHUB_REPO/https:\/\//https://${TOKEN}@}"
REPO_DIR="${REPOS_DIR}/thehockeybrain"

# Clone or pull repo
mkdir -p "$REPOS_DIR"
if [[ ! -d "${REPO_DIR}/.git" ]]; then
  git clone --depth 1 "$AUTH_REPO_URL" "$REPO_DIR"
else
  git -C "$REPO_DIR" remote set-url origin "$AUTH_REPO_URL"
  git -C "$REPO_DIR" pull --rebase
fi

POSTS_FILE="${REPO_DIR}/lib/posts.ts"

# Convert markdown to HTML + extract frontmatter using python3
# Use quoted heredoc (no bash expansion) + pass variables as argv
cat > /tmp/_publish_thb.py << 'PYEOF'
import re, json, sys

slug      = sys.argv[1]
draft_path = sys.argv[2]
posts_path = sys.argv[3]
today = __import__('datetime').date.today().isoformat()

with open(draft_path) as f:
    raw = f.read()

# Strip "Nästa steg" helper text if accidentally saved
lines = raw.split('\n')
clean_lines = []
for line in lines:
    if re.match(r'^(Nästa steg|Next steps):.*(publicera|publish)', line):
        break
    clean_lines.append(line)
raw = '\n'.join(clean_lines)

# Parse frontmatter
fm = {}
body = raw
fm_match = re.match(r'^---\s*\n(.*?)\n---\s*\n(.*)', raw, re.DOTALL)
if fm_match:
    fm_text = fm_match.group(1)
    body = fm_match.group(2).strip()
    for line in fm_text.split('\n'):
        m = re.match(r'^(\w+):\s*(.+)', line)
        if m:
            k, v = m.group(1), m.group(2).strip().strip('"\'')
            fm[k] = v
    # tags
    tags_m = re.search(r'^tags:\s*\[(.+?)\]', fm_text, re.MULTILINE)
    if tags_m:
        fm['tags'] = [t.strip().strip('"\'') for t in tags_m.group(1).split(',')]

title       = fm.get('title', slug.replace('-', ' ').title())
description = fm.get('description', '')
pub_date    = fm.get('pubDate', today + 'T09:00:00Z')
if not pub_date.endswith('Z') and 'T' not in pub_date:
    pub_date = pub_date + 'T09:00:00Z'
tags        = fm.get('tags', ['nhl analytics', 'hockey statistics'])
keywords_ts = json.dumps(tags if isinstance(tags, list) else [tags])

# Convert markdown to HTML (simple converter – handles common elements)
def md_to_html(md):
    html = md

    # Fenced code blocks
    html = re.sub(r'```(\w+)?\n(.*?)```', lambda m: f'<pre><code class="language-{m.group(1) or ""}">{m.group(2)}</code></pre>', html, flags=re.DOTALL)

    # Tables
    def convert_table(m):
        lines = [l.strip() for l in m.group(0).strip().split('\n') if l.strip()]
        rows = [l for l in lines if not re.match(r'^\|?[\s\-\|:]+\|?$', l)]
        result = '<table class="analytics-table"><tbody>'
        for i, row in enumerate(rows):
            cells = [c.strip() for c in row.strip('|').split('|')]
            tag = 'th' if i == 0 else 'td'
            result += '<tr>' + ''.join(f'<{tag}>{c}</{tag}>' for c in cells) + '</tr>'
        result += '</tbody></table>'
        return result
    html = re.sub(r'(\|[^\n]+\n)+', convert_table, html)

    # Headers
    html = re.sub(r'^#### (.+)$', r'<h4>\1</h4>', html, flags=re.MULTILINE)
    html = re.sub(r'^### (.+)$', r'<h3>\1</h3>', html, flags=re.MULTILINE)
    html = re.sub(r'^## (.+)$', r'<h2>\1</h2>', html, flags=re.MULTILINE)
    html = re.sub(r'^# (.+)$', r'<h1>\1</h1>', html, flags=re.MULTILINE)

    # Bold/italic
    html = re.sub(r'\*\*\*(.+?)\*\*\*', r'<strong><em>\1</em></strong>', html)
    html = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', html)
    html = re.sub(r'\*(.+?)\*', r'<em>\1</em>', html)

    # Links
    html = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', html)
    # Internal link placeholders [länk: slug]
    html = re.sub(r'\[länk:\s*([^\]]+)\]', r'<a href="/insights/\1">\1</a>', html)

    # Unordered lists
    def ul_replace(m):
        items = re.findall(r'^[-*]\s+(.+)$', m.group(0), re.MULTILINE)
        return '<ul>' + ''.join(f'<li>{i}</li>' for i in items) + '</ul>'
    html = re.sub(r'(^[-*]\s+.+\n?)+', ul_replace, html, flags=re.MULTILINE)

    # Ordered lists
    def ol_replace(m):
        items = re.findall(r'^\d+\.\s+(.+)$', m.group(0), re.MULTILINE)
        return '<ol>' + ''.join(f'<li>{i}</li>' for i in items) + '</ol>'
    html = re.sub(r'(^\d+\.\s+.+\n?)+', ol_replace, html, flags=re.MULTILINE)

    # Paragraphs (double newlines)
    paragraphs = re.split(r'\n\n+', html.strip())
    result_parts = []
    for p in paragraphs:
        p = p.strip()
        if not p:
            continue
        if re.match(r'^<(h[1-6]|ul|ol|pre|table|div)', p):
            result_parts.append(p)
        else:
            result_parts.append(f'<p>{p.replace(chr(10), " ")}</p>')
    html = '\n'.join(result_parts)

    return html

html_content = md_to_html(body)

# Escape backticks and ${ for template literal safety
html_content = html_content.replace('\\\\', '\\\\\\\\')
html_content = html_content.replace('`', '\\`')
html_content = html_content.replace('\${', '\\\${')

# Build new BlogPost TS entry
title_safe = title.replace("'", "\\'")
desc_safe   = description.replace("'", "\\'")
entry = (
    "  {\n"
    f"    slug: '{slug}',\n"
    f"    title: '{title_safe}',\n"
    f"    metaTitle: '{title_safe} | The Hockey Brain',\n"
    f"    metaDescription: '{desc_safe}',\n"
    f"    keywords: {keywords_ts},\n"
    f"    publishedAt: '{pub_date}',\n"
    f"    content: `{html_content}`,\n"
    "  },"
)

# Inject after "export const posts: BlogPost[] = ["
with open(posts_path) as f:
    posts_ts = f.read()

insert_after = 'export const posts: BlogPost[] = ['
idx = posts_ts.find(insert_after)
if idx == -1:
    print('ERROR: could not find posts array in lib/posts.ts', file=sys.stderr)
    sys.exit(1)

insert_pos = idx + len(insert_after) + 1  # after the [
new_posts_ts = posts_ts[:insert_pos] + '\n' + entry + '\n' + posts_ts[insert_pos:]

with open(posts_path, 'w') as f:
    f.write(new_posts_ts)

print(f'Injected post: {slug}')
print(f'Title: {title}')
PYEOF
python3 /tmp/_publish_thb.py "$SLUG" "$DRAFT_FILE" "$POSTS_FILE"
rm -f /tmp/_publish_thb.py

# Commit and push
git -C "$REPO_DIR" remote set-url origin "$AUTH_REPO_URL"
git -C "$REPO_DIR" add lib/posts.ts
git -C "$REPO_DIR" -c user.name="OpenClaw SEO" -c user.email="emilingemarkarlsson@gmail.com" \
  commit -m "feat: add SEO article – ${SLUG}"
git -C "$REPO_DIR" push origin HEAD

# Clean up draft
rm -f "$DRAFT_FILE" "$META_FILE"

ARTICLE_URL="https://${DOMAIN}/insights/${SLUG}"
echo "Published: ${ARTICLE_URL}"
echo "Repo: $GITHUB_REPO"

# Telegram notification
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
"${SCRIPTS_DIR}/telegram-notify.sh" "thehockeybrain" \
  "✅ <b>Artikel publicerad</b> – The Hockey Brain
🔗 ${ARTICLE_URL}" || true

# n8n newsletter webhook
if [[ -n "$LIST_UUID" ]]; then
  ARTICLE_TITLE=$(python3 -c "
import re, sys
with open('${POSTS_FILE}') as f:
    content = f.read()
m = re.search(r\"slug: '${SLUG}'.*?title: '([^']+)'\", content, re.DOTALL)
print(m.group(1) if m else '${SLUG}')
" 2>/dev/null || echo "$SLUG")
  curl -s -o /dev/null -X POST "https://n8n.theunnamedroads.com/webhook/article-published" \
    -H "Content-Type: application/json" \
    -d "{
      \"slug\": \"${SLUG}\",
      \"url\": \"${ARTICLE_URL}\",
      \"title\": $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "${ARTICLE_TITLE}"),
      \"description\": \"\",
      \"umamiName\": \"thehockeybrain\",
      \"projectName\": $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "${PROJECT_NAME}"),
      \"listUuid\": \"${LIST_UUID}\"
    }" || true
fi
