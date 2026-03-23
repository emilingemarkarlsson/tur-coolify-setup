#!/usr/bin/env bash
# Komplett pipeline för datadrivna NHL-artiklar.
# Gör allt i ett script: fetch → LLM-artikel → publish.
#
# Användning:
#   nhl-article-pipeline.sh thehockeybrain   → Next.js, analytiskt djup
#   nhl-article-pipeline.sh thehockeyanalytics → Astro, coachfokus
#
# Kräver: curl, python3, jq (om ej installerat: apt-get install jq)
# LITELLM_URL och GITHUB_TOKEN måste vara satta (via env eller filer).

set -euo pipefail

SITE="${1:-}"
if [[ -z "$SITE" || ( "$SITE" != "thehockeybrain" && "$SITE" != "thehockeyanalytics" ) ]]; then
  echo "Usage: $0 thehockeybrain|thehockeyanalytics" >&2
  exit 1
fi

SCRIPTS_DIR="/data/.openclaw/scripts"
DATA_DIR="/data/.openclaw/nhl-data"
DRAFTS_DIR="/data/.openclaw/drafts"
mkdir -p "$DATA_DIR" "$DRAFTS_DIR"

TODAY=$(date +%Y-%m-%d)
echo "[$TODAY] NHL article pipeline for $SITE" >&2

# ── 1. Fetch NHL data ────────────────────────────────────────────────────────
echo "[1/5] Fetching NHL data..." >&2
"$SCRIPTS_DIR/nhl-data-fetch.sh" > "$DATA_DIR/latest.json"

# ── 2. Pick finding ──────────────────────────────────────────────────────────
echo "[2/5] Picking finding..." >&2
LAST_TYPE=$(cat "$DATA_DIR/last-finding.txt" 2>/dev/null || echo "")

FINDING_JSON=$(python3 - "$DATA_DIR/latest.json" "$LAST_TYPE" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
last_type = sys.argv[2].strip()
findings = data.get('findings', [])
if not findings:
    print('{}')
    sys.exit(0)
# Prefer a different type than last
chosen = findings[0]
for f in findings:
    if f.get('type') != last_type:
        chosen = f
        break
print(json.dumps(chosen))
PYEOF
)

if [[ "$FINDING_JSON" == "{}" ]]; then
  echo "No findings available in NHL data." >&2
  exit 1
fi

FINDING_TYPE=$(echo "$FINDING_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('type','unknown'))")
FINDING_HEADLINE=$(echo "$FINDING_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('headline',''))")
FINDING_INSIGHT=$(echo "$FINDING_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('insight',''))")
TEAM_ABBREV=$(echo "$FINDING_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('abbrev','xxx'))" | tr '[:upper:]' '[:lower:]')

# Article angle depends on site
ANGLE_KEY=$([ "$SITE" == "thehockeybrain" ] && echo "article_angle_thb" || echo "article_angle_tha")
ARTICLE_ANGLE=$(echo "$FINDING_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('$ANGLE_KEY',''))")

echo "  Finding: $FINDING_TYPE – $FINDING_HEADLINE" >&2

# ── 3. Build LLM prompt ──────────────────────────────────────────────────────
echo "[3/5] Generating article via LLM..." >&2

# Site-specific instructions
if [[ "$SITE" == "thehockeybrain" ]]; then
  SITE_TONE="analytical, data-nerd, opinionated. Audience: coaches, GMs, analytics staff. Length: 1400-1800 words."
  SITE_AUTHOR="The Hockey Brain Analytics Team"
  SITE_DOMAIN="thehockeybrain.com"
  FRONTMATTER_FORMAT='---
title: "[title]"
description: "[description max 160 chars]"
pubDate: "'"$TODAY"'T09:00:00Z"
updatedDate: "'"$TODAY"'T09:00:00Z"
tags: ["nhl analytics", "hockey statistics", "[team name]", "[finding type]"]
author: "The Hockey Brain Analytics Team"
heroImage: "/images/blog/placeholder.jpg"
---'
else
  SITE_TONE="accessible, practical, coach-focused. Audience: coaches and scouts who want to use data. Avoid heavy math. Length: 1100-1400 words."
  SITE_AUTHOR="The Hockey Analytics Team"
  SITE_DOMAIN="thehockeyanalytics.com"
  FRONTMATTER_FORMAT='---
layout: '"'"'@/templates/BasePost.astro'"'"'
title: '"'"'[title]'"'"'
description: "[description max 160 chars]"
pubDate: '"$TODAY"'T09:00:00Z
updatedDate: '"$TODAY"'T09:00:00Z
imgSrc: '"'"'/assets/images/image-post7.jpeg'"'"'
imgAlt: '"'"'[brief image alt text]'"'"'
tags: ['"'"'hockey analytics'"'"', '"'"'nhl'"'"', '"'"'[team name]'"'"', '"'"'coaching'"'"']
author: '"'"'The Hockey Analytics Team'"'"'
---'
fi

# Build the full data context for the prompt
DATA_CONTEXT=$(echo "$FINDING_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
data = d.get('data', {})
lines = []
for k, v in data.items():
    if k not in ('conference', 'division', 'league_sequence'):
        lines.append(f'  {k}: {v}')
print('Finding type: ' + d.get('type',''))
print('Headline: ' + d.get('headline',''))
print('Insight: ' + d.get('insight',''))
print('Article angle: ' + d.get('article_angle_thb' if '${SITE}' == 'thehockeybrain' else 'article_angle_tha', ''))
print('Data points:')
print('\n'.join(lines))
")

PROMPT="Write a data-driven hockey analytics article for ${SITE_DOMAIN}.

SITE TONE: ${SITE_TONE}

FINDING DATA:
${DATA_CONTEXT}

ARTICLE REQUIREMENTS:
1. Start with the EXACT statistic from the data (e.g., '57.3%. That is...' or '73.9% points pace.'). NEVER open with 'In today's world', 'Hockey is', or 'In recent years'.
2. Explain what the metric means and how it is calculated (show the formula).
3. Include all key numbers in a markdown table.
4. Historical context: how teams in this situation typically perform (cite data patterns).
5. A section titled 'What Most Analysts Get Wrong' or 'The Common Mistake'.
6. At least one opinionated sentence (e.g., 'The popular narrative about X is wrong').
7. FAQ block with 3-5 questions and answers.
8. End with: 'Want to bring advanced analytics to your club? [Get in touch](https://${SITE_DOMAIN}/contact).'

OUTPUT FORMAT: Return ONLY the complete markdown article with frontmatter. Use this exact frontmatter:
${FRONTMATTER_FORMAT}

Do not include any commentary, explanations, or text outside the markdown article."

# ── 4. Call LLM (LiteLLM with Anthropic fallback) ────────────────────────────
LITELLM_URL="${OPENAI_API_BASE:-${LITELLM_URL:-http://litellm-kkswc8gokk84c0o8oo84w44w.46.62.206.47.sslip.io/v1}}"
LITELLM_KEY="${OPENAI_API_KEY:-sk-placeholder}"

PROMPT_JSON=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$PROMPT")

# Try LiteLLM models in order
RESPONSE=""
for MODEL in "gemini-flash" "deepseek-chat" "groq-llama"; do
  CANDIDATE=$(curl -sfk --max-time 120 \
    "${LITELLM_URL}/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${LITELLM_KEY}" \
    -d "{
      \"model\": \"${MODEL}\",
      \"messages\": [{\"role\": \"user\", \"content\": ${PROMPT_JSON}}],
      \"temperature\": 0.7,
      \"max_tokens\": 3000
    }" 2>/dev/null || echo "")
  if echo "$CANDIDATE" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('choices')" 2>/dev/null; then
    RESPONSE="$CANDIDATE"
    echo "  LiteLLM model: $MODEL" >&2
    break
  fi
done

# Fallback: Anthropic API directly
if [[ -z "$RESPONSE" ]] && [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "  LiteLLM unavailable – falling back to Anthropic API (claude-haiku-4-5)..." >&2
  ANTHROPIC_RESP=$(curl -sf --max-time 120 \
    "https://api.anthropic.com/v1/messages" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${ANTHROPIC_API_KEY}" \
    -H "anthropic-version: 2023-06-01" \
    -d "{
      \"model\": \"claude-haiku-4-5-20251001\",
      \"max_tokens\": 3000,
      \"messages\": [{\"role\": \"user\", \"content\": ${PROMPT_JSON}}]
    }" 2>/dev/null || echo "")
  if [[ -n "$ANTHROPIC_RESP" ]]; then
    RESPONSE=$(echo "$ANTHROPIC_RESP" | python3 -c "
import json,sys
d=json.load(sys.stdin)
text = d['content'][0]['text']
print(json.dumps({'choices':[{'message':{'content':text}}]}))
" 2>/dev/null || echo "")
  fi
fi

if [[ -z "$RESPONSE" ]]; then
  echo "All LLM providers failed or timed out." >&2
  exit 1
fi

ARTICLE=$(echo "$RESPONSE" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    content = d['choices'][0]['message']['content']
    print(content)
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
")

if [[ -z "$ARTICLE" ]]; then
  echo "LLM returned empty article." >&2
  exit 1
fi

echo "  Article generated ($(echo "$ARTICLE" | wc -w) words)" >&2

# ── 5. Save draft and publish ────────────────────────────────────────────────
# Build slug: nhl-{type-short}-{team}-{date}
TYPE_SHORT=$(echo "$FINDING_TYPE" | sed 's/regression_candidate_up/regression-up/;s/regression_candidate_down/regression-down/;s/best_underlying/best-underlying/;s/ot_dependent/ot-dependent/;s/home_road_split/home-road/')
SLUG="nhl-${TYPE_SHORT}-${TEAM_ABBREV}-${TODAY}"

echo "[4/5] Saving draft: $SLUG..." >&2
echo "$ARTICLE" > "${DRAFTS_DIR}/${SLUG}.md"
echo "umamiName=${SITE}" > "${DRAFTS_DIR}/${SLUG}.meta"

echo "[5/5] Publishing..." >&2
if [[ "$SITE" == "thehockeybrain" ]]; then
  "$SCRIPTS_DIR/publish-draft-thehockeybrain.sh" "$SLUG"
  ARTICLE_URL="https://thehockeybrain.com/insights/${SLUG}"
else
  "$SCRIPTS_DIR/publish-draft.sh" "$SLUG"
  ARTICLE_URL="https://thehockeyanalytics.com/posts/${SLUG}"
fi

# Save last finding type
echo "$FINDING_TYPE" > "$DATA_DIR/last-finding.txt"

echo "" >&2
echo "Published: $ARTICLE_URL" >&2
echo "Finding: $FINDING_HEADLINE" >&2

# Output for Slack
echo "PUBLISHED: $ARTICLE_URL"
echo "FINDING: $FINDING_HEADLINE"
