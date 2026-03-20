#!/usr/bin/env bash
# Listar artiklar för en sajt med AEO-relevant metadata.
# Kräver att clone-site.sh har körts först.
# Användning: list-articles.sh <umamiName>
# Output:     JSON med slug, publishDate, dateModified, hasFAQ, hasSchema, wordCount

set -euo pipefail

SITE_REPOS="/data/.openclaw/site-repos.json"
REPOS_DIR="/data/.openclaw/repos"

UMAMI_NAME="${1:-}"
if [[ -z "$UMAMI_NAME" ]]; then
  echo "Usage: $0 <umamiName>" >&2
  exit 1
fi

python3 - "$UMAMI_NAME" "$REPOS_DIR" "$SITE_REPOS" <<'PYEOF'
import json, os, re, sys

umami_name, repos_dir, site_repos_path = sys.argv[1:]

with open(site_repos_path) as f:
    data = json.load(f)

site = next((s for s in data["sites"] if s.get("umamiName") == umami_name), None)
if not site:
    print(json.dumps({"error": f"Site not found: {umami_name}"}))
    sys.exit(1)

content_path = site.get("contentPath", "src/content/blog")
repo_dir = os.path.join(repos_dir, umami_name)
articles_dir = os.path.join(repo_dir, content_path)

if not os.path.isdir(articles_dir):
    print(json.dumps({
        "error": f"Repo not cloned or path missing: {articles_dir}",
        "hint": f"Run: clone-site.sh {umami_name}"
    }))
    sys.exit(1)

articles = []
for fname in sorted(os.listdir(articles_dir)):
    if not fname.endswith((".md", ".mdx")):
        continue
    fpath = os.path.join(articles_dir, fname)
    try:
        with open(fpath, encoding="utf-8", errors="replace") as f:
            content = f.read()
    except Exception:
        continue

    slug = re.sub(r'\.(mdx?)$', '', fname)
    pub = (re.search(r'publishedDate:\s*["\']?(\S+?)["\']?\s*$', content, re.M) or
           re.search(r'publishDate:\s*["\']?(\S+?)["\']?\s*$', content, re.M))
    mod = re.search(r'dateModified:\s*["\']?(\S+?)["\']?\s*$', content, re.M)
    has_faq = bool(re.search(
        r'^##\s*(Vanliga frågor|FAQ|Frequently Asked Questions|Common Questions)',
        content, re.IGNORECASE | re.MULTILINE
    ))
    has_schema = 'application/ld+json' in content or '"@type"' in content
    word_count = len(re.sub(r'---.*?---', '', content, flags=re.DOTALL).split())

    articles.append({
        "slug": slug,
        "file": fname,
        "publishDate": pub.group(1).strip() if pub else None,
        "dateModified": mod.group(1).strip() if mod else None,
        "hasFAQ": has_faq,
        "hasSchema": has_schema,
        "wordCount": word_count
    })

no_faq = [a["slug"] for a in articles if not a["hasFAQ"]]
no_schema = [a["slug"] for a in articles if not a["hasSchema"]]

print(json.dumps({
    "umamiName": umami_name,
    "domain": site.get("domain", ""),
    "total": len(articles),
    "missingFAQ": len(no_faq),
    "missingSchema": len(no_schema),
    "articles": articles
}, indent=2))
PYEOF
