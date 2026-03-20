#!/usr/bin/env bash
# Hanterar AEO-progress tracking – vilka artiklar som är refreshade.
# Läser /data/.openclaw/aeo-progress.json och returnerar nästa batch av obehandlade artiklar.
#
# Användning:
#   aeo-progress.sh next [N]           – returnera N nästa obehandlade artiklar (default 5)
#   aeo-progress.sh done <site> <slug> – markera artikel som klar
#   aeo-progress.sh status             – visa sammanfattning

set -euo pipefail

PROGRESS_FILE="/data/.openclaw/aeo-progress.json"
SITE_REPOS="/data/.openclaw/site-repos.json"
REPOS_DIR="/data/.openclaw/repos"

CMD="${1:-next}"

# Init progress file om den saknas
if [[ ! -f "$PROGRESS_FILE" ]]; then
  echo '{"refreshed": {}}' > "$PROGRESS_FILE"
fi

case "$CMD" in

  next)
    N="${2:-5}"
    python3 - "$N" "$PROGRESS_FILE" "$SITE_REPOS" "$REPOS_DIR" <<'PYEOF'
import json, os, re, sys

n, progress_path, site_repos_path, repos_dir = int(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]

with open(progress_path) as f:
    progress = json.load(f)
refreshed = progress.get("refreshed", {})

with open(site_repos_path) as f:
    data = json.load(f)

# Skip rapport-only (finnbodahamnplan) and sites without articles yet
skip_sites = {"finnbodahamnplan"}

candidates = []
for site in data["sites"]:
    name = site.get("umamiName", "")
    if name in skip_sites:
        continue
    content_path = site.get("contentPath", "src/content/blog")
    articles_dir = os.path.join(repos_dir, name, content_path)
    if not os.path.isdir(articles_dir):
        continue
    for fname in sorted(os.listdir(articles_dir)):
        if not fname.endswith((".md", ".mdx")):
            continue
        slug = re.sub(r'\.(mdx?)$', '', fname)
        # Skip if already refreshed
        if refreshed.get(name, {}).get(slug):
            continue
        fpath = os.path.join(articles_dir, fname)
        try:
            with open(fpath, encoding="utf-8", errors="replace") as f:
                content = f.read()
        except Exception:
            continue
        has_faq = bool(re.search(r'^##\s*(Frequently Asked Questions|Vanliga frågor|FAQ)', content, re.I | re.M))
        pub = (re.search(r'publishedDate:\s*["\']?(\S+?)["\']?\s*$', content, re.M) or
               re.search(r'publishDate:\s*["\']?(\S+?)["\']?\s*$', content, re.M))
        word_count = len(re.sub(r'---.*?---', '', content, flags=re.DOTALL).split())
        if not has_faq and word_count > 200:
            candidates.append({
                "umamiName": name,
                "domain": site.get("domain", ""),
                "slug": slug,
                "publishDate": pub.group(1).strip() if pub else "9999",
                "wordCount": word_count
            })

# Sort by publish date (oldest first)
candidates.sort(key=lambda x: x["publishDate"])
print(json.dumps(candidates[:n], indent=2))
PYEOF
    ;;

  done)
    SITE="${2:-}"
    SLUG="${3:-}"
    if [[ -z "$SITE" || -z "$SLUG" ]]; then
      echo "Usage: $0 done <umamiName> <slug>" >&2
      exit 1
    fi
    python3 - "$SITE" "$SLUG" "$PROGRESS_FILE" <<'PYEOF'
import json, sys, datetime
site, slug, path = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    p = json.load(f)
p.setdefault("refreshed", {}).setdefault(site, {})[slug] = datetime.date.today().isoformat()
with open(path, "w") as f:
    json.dump(p, f, indent=2)
print(f"Marked done: {site}/{slug}")
PYEOF
    ;;

  status)
    python3 - "$PROGRESS_FILE" "$SITE_REPOS" "$REPOS_DIR" <<'PYEOF'
import json, os, re, sys
progress_path, site_repos_path, repos_dir = sys.argv[1], sys.argv[2], sys.argv[3]

with open(progress_path) as f:
    progress = json.load(f)
refreshed = progress.get("refreshed", {})
total_done = sum(len(v) for v in refreshed.values())

with open(site_repos_path) as f:
    data = json.load(f)

print(f"{'Site':<25} {'Total':>6} {'No FAQ':>7} {'Done':>6} {'Remaining':>10}")
print("-" * 58)
grand_total = grand_no_faq = grand_done = 0
for site in data["sites"]:
    name = site.get("umamiName", "")
    content_path = site.get("contentPath", "src/content/blog")
    articles_dir = os.path.join(repos_dir, name, content_path)
    if not os.path.isdir(articles_dir):
        continue
    total = no_faq = 0
    for fname in os.listdir(articles_dir):
        if not fname.endswith((".md", ".mdx")): continue
        total += 1
        slug = re.sub(r'\.(mdx?)$', '', fname)
        try:
            content = open(os.path.join(articles_dir, fname), encoding="utf-8", errors="replace").read()
        except: continue
        if not re.search(r'^##\s*(Frequently Asked Questions|Vanliga frågor|FAQ)', content, re.I | re.M):
            no_faq += 1
    done = len(refreshed.get(name, {}))
    remaining = no_faq - done
    print(f"{name:<25} {total:>6} {no_faq:>7} {done:>6} {max(0,remaining):>10}")
    grand_total += total; grand_no_faq += no_faq; grand_done += done
print("-" * 58)
print(f"{'TOTALT':<25} {grand_total:>6} {grand_no_faq:>7} {grand_done:>6} {max(0,grand_no_faq-grand_done):>10}")
PYEOF
    ;;

  *)
    echo "Usage: $0 next [N] | done <site> <slug> | status" >&2
    exit 1
    ;;
esac
