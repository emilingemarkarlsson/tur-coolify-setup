#!/usr/bin/env bash
# Klonar eller pullar en sajt (eller alla) till /data/.openclaw/repos/
# Användning: clone-site.sh [umamiName|all]
# Exempel:   clone-site.sh all
#            clone-site.sh theunnamedroads

set -euo pipefail

SITE_REPOS="/data/.openclaw/site-repos.json"
REPOS_DIR="/data/.openclaw/repos"

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

TARGET="${1:-all}"
mkdir -p "$REPOS_DIR"

python3 - "$TARGET" "$TOKEN" "$REPOS_DIR" "$SITE_REPOS" <<'PYEOF'
import json, subprocess, sys, os

target, token, repos_dir, site_repos_path = sys.argv[1:]

with open(site_repos_path) as f:
    data = json.load(f)

ok = 0
errors = 0
for site in data["sites"]:
    name = site.get("umamiName", "")
    repo = site.get("githubRepo", "")

    if target != "all" and name != target:
        continue
    if not repo or repo == "null":
        continue

    auth_url = repo.replace("https://", f"https://{token}@")
    repo_dir = os.path.join(repos_dir, name)

    print(f"Synkar {name}...", flush=True)
    if os.path.isdir(os.path.join(repo_dir, ".git")):
        result = subprocess.run(
            ["git", "-C", repo_dir, "pull", "--rebase"],
            capture_output=True, text=True
        )
    else:
        result = subprocess.run(
            ["git", "clone", "--depth", "1", auth_url, repo_dir],
            capture_output=True, text=True
        )

    if result.returncode != 0:
        print(f"  FEL: {result.stderr.strip()}", file=sys.stderr, flush=True)
        errors += 1
    else:
        print(f"  OK: {repo_dir}", flush=True)
        ok += 1

print(f"\nKlar: {ok} OK, {errors} fel.", flush=True)
if errors > 0:
    sys.exit(1)
PYEOF
