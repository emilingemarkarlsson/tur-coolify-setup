#!/usr/bin/env bash
# Kopierar SEO-agentens dokument och site-repos.json in i OpenClaw-containern.
# Kör från repots rot: ./scripts/openclaw-install-seo-agent.sh
# Kräver SSH-alias "tha" och att OpenClaw körs på servern.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS_DIR="$REPO_ROOT/openclaw/agents"
WORKSPACE_DIR="$REPO_ROOT/openclaw/workspace"

for f in SEO-SITE-AGENT.md SEO-PROCESS.md SEO-PLAYBOOK.md SEO-ARTICLE-SUGGESTIONS.md AEO-PLAYBOOK.md; do
  if [[ ! -f "$AGENTS_DIR/$f" ]]; then
    echo "Saknar $AGENTS_DIR/$f"
    exit 1
  fi
done
# SEO-ROLLING-AUTOMATION-PROMPT.md är valfri – hoppa över om den saknas
if [[ ! -f "$AGENTS_DIR/site-repos.json" ]]; then
  echo "Saknar $AGENTS_DIR/site-repos.json – skapa den från site-repos.example.json och fyll i dina repon."
  exit 1
fi
if [[ ! -d "$WORKSPACE_DIR" ]] || [[ ! -f "$WORKSPACE_DIR/AGENTS.md" ]]; then
  echo "Saknar $WORKSPACE_DIR/AGENTS.md – Core Files för OpenClaw workspace."
  exit 1
fi

echo "Hämtar OpenClaw-container från tha..."
CONTAINER=$(ssh tha 'docker ps --format "{{.Names}}" | grep -i openclaw | head -1')
if [[ -z "$CONTAINER" ]]; then
  echo "Ingen OpenClaw-container hittad på tha. Kör: ssh tha 'docker ps | grep openclaw'"
  exit 1
fi

echo "Skapar /data/.openclaw/agents och drafts i $CONTAINER..."
ssh tha "docker exec $CONTAINER mkdir -p /data/.openclaw/agents /data/.openclaw/drafts"

echo "Kopierar SEO-SITE-AGENT.md, SEO-PROCESS.md, SEO-PLAYBOOK.md, SEO-ARTICLE-SUGGESTIONS.md, SEO-ROLLING-AUTOMATION-PROMPT.md, AEO-PLAYBOOK.md..."
for f in SEO-SITE-AGENT.md SEO-PROCESS.md SEO-PLAYBOOK.md SEO-ARTICLE-SUGGESTIONS.md SEO-ROLLING-AUTOMATION-PROMPT.md AEO-PLAYBOOK.md; do
  scp -q "$AGENTS_DIR/$f" "tha:/tmp/$f"
  ssh tha "docker cp /tmp/$f $CONTAINER:/data/.openclaw/agents/$f"
  ssh tha "rm -f /tmp/$f"
done
if [[ -f "$AGENTS_DIR/SEO-ROLLING-AUTOMATION-PROMPT.md" ]]; then
  echo "Kopierar SEO-ROLLING-AUTOMATION-PROMPT.md..."
  scp -q "$AGENTS_DIR/SEO-ROLLING-AUTOMATION-PROMPT.md" "tha:/tmp/SEO-ROLLING-AUTOMATION-PROMPT.md"
  ssh tha "docker cp /tmp/SEO-ROLLING-AUTOMATION-PROMPT.md $CONTAINER:/data/.openclaw/agents/SEO-ROLLING-AUTOMATION-PROMPT.md"
  ssh tha "rm -f /tmp/SEO-ROLLING-AUTOMATION-PROMPT.md"
fi

echo "Kopierar site-repos.json till /data/.openclaw/site-repos.json..."
scp -q "$AGENTS_DIR/site-repos.json" "tha:/tmp/site-repos.json"
ssh tha "docker cp /tmp/site-repos.json $CONTAINER:/data/.openclaw/site-repos.json"
ssh tha "rm -f /tmp/site-repos.json"

# Plans per sajt (en fil per sajt – rekommenderat)
if [[ -d "$AGENTS_DIR/plans" ]]; then
  echo "Kopierar plans/ (en fil per sajt)..."
  ssh tha "docker exec $CONTAINER mkdir -p /data/.openclaw/agents/plans"
  for plan in "$AGENTS_DIR/plans"/*.md; do
    [[ -f "$plan" ]] || continue
    fname=$(basename "$plan")
    scp -q "$plan" "tha:/tmp/$fname"
    ssh tha "docker cp /tmp/$fname $CONTAINER:/data/.openclaw/agents/plans/$fname"
    ssh tha "rm -f /tmp/$fname"
  done
fi
# Äldre: en enda override-fil (om plans/ inte används)
if [[ -f "$AGENTS_DIR/seo-plan-override.md" ]]; then
  echo "Kopierar seo-plan-override.md (användarjusterad plan, en fil)..."
  scp -q "$AGENTS_DIR/seo-plan-override.md" "tha:/tmp/seo-plan-override.md"
  ssh tha "docker cp /tmp/seo-plan-override.md $CONTAINER:/data/.openclaw/agents/seo-plan-override.md"
  ssh tha "rm -f /tmp/seo-plan-override.md"
fi

# Workspace som UI visar (Agents → main → Files) är /data/workspace
echo "Skapar /data/workspace och kopierar Core Files (syns i OpenClaw UI)..."
ssh tha "docker exec $CONTAINER mkdir -p /data/workspace"
for f in AGENTS.md SOUL.md IDENTITY.md USER.md TOOLS.md HEARTBEAT.md BOOTSTRAP.md MEMORY.md; do
  if [[ -f "$WORKSPACE_DIR/$f" ]]; then
    scp -q "$WORKSPACE_DIR/$f" "tha:/tmp/$f"
    ssh tha "docker cp /tmp/$f $CONTAINER:/data/workspace/$f"
    ssh tha "rm -f /tmp/$f"
  fi
done
# SEO-planer i workspace-ROTEN (UI visar bara filer i roten, inte undermappar)
if [[ -d "$AGENTS_DIR/plans" ]]; then
  echo "Kopierar plans/ till /data/workspace/ som seo-plan-{umamiName}.md (syns i UI Files-listan)..."
  for plan in "$AGENTS_DIR/plans"/*.md; do
    [[ -f "$plan" ]] || continue
    bname=$(basename "$plan" .md)
    fname="seo-plan-$bname.md"
    scp -q "$plan" "tha:/tmp/$fname"
    ssh tha "docker cp /tmp/$fname $CONTAINER:/data/workspace/$fname"
    ssh tha "rm -f /tmp/$fname"
  done
fi

# Scripts i containern
OPENCLAW_SCRIPTS="$REPO_ROOT/openclaw/scripts"
ssh tha "docker exec $CONTAINER mkdir -p /data/.openclaw/scripts"
for script in store-seo-draft.sh publish-draft.sh umami-daily-stats.sh clone-site.sh list-articles.sh stage-refresh.sh; do
  if [[ -f "$OPENCLAW_SCRIPTS/$script" ]]; then
    echo "Kopierar $script..."
    scp -q "$OPENCLAW_SCRIPTS/$script" "tha:/tmp/$script"
    ssh tha "docker cp /tmp/$script $CONTAINER:/data/.openclaw/scripts/$script && docker exec $CONTAINER chmod +x /data/.openclaw/scripts/$script"
    ssh tha "rm -f /tmp/$script"
  fi
done

echo ""
echo "Klar. Filer i containern:"
echo "  /data/.openclaw/agents/SEO-SITE-AGENT.md, SEO-PROCESS.md, SEO-PLAYBOOK.md, AEO-PLAYBOOK.md"
echo "  /data/.openclaw/site-repos.json"
[[ -d "$AGENTS_DIR/plans" ]] && echo "  /data/.openclaw/agents/plans/*.md (en fil per sajt)"
[[ -f "$AGENTS_DIR/seo-plan-override.md" ]] && echo "  /data/.openclaw/agents/seo-plan-override.md (användarjusterad plan, en fil)"
echo "  /data/workspace/ (Core Files + seo-plan-theunnamedroads.md, seo-plan-finnbodahamnplan.md, … – syns i UI Files-listan)"
echo ""
echo "Nästa: Öppna OpenClaw Control → Agents → main → Files → Refresh. Du ser planfilerna som seo-plan-{sajt}.md – klicka och redigera."
echo "  Lägg sedan till cron-jobb (se openclaw/SETUP-SEO-OPENCLAW.md eller KOR-DESSA-STEG.md) och testa."
