# CMO System Design — Signal → Brief → Distribute

Full architecture for the content + distribution system.
This is the heart of the operation.

---

## Overview

```
REALITY LAYER
  Paperclip collects: Stripe events, LiteLLM spend,
  Umami traffic, publish events, workflow errors
  → daily-ops-log.json in Minio

SIGNAL LAYER (07:00 daily)
  HN Algolia API + Reddit + RSS feeds
  → LiteLLM scores relevance per site cluster
  → daily-signals-[site].json in Minio

EDITORIAL LAYER — CMO Agent (07:30 daily)
  Reads: signals + ops log + editorial-memory.json
  Produces:
    - content brief per site (topic, angle, hook, tone)
    - EIK post brief (what happened this week worth sharing)
    - X post draft per brief
  → briefs saved to Minio, consumed by generators at 08:00+

GENERATION LAYER (08:00–12:00)
  Each generator reads its brief instead of generic seed topic
  Draft → Critic/QA call → score >= 6 on all dimensions → publish
  IF score < 6 → one retry with revision notes → publish or discard

DISTRIBUTION LAYER
  After each publish:
    → X post (from brief, auto-posted when X API active)
    → EIK weekly numbers post (Emil approves in Telegram)
    → Newsletter dispatch (existing, unchanged)
```

---

## Brand Voice JSON (Minio: brand-voice/eik.json)

Fetched at the start of every LiteLLM call producing EIK content.
Never hardcoded in workflow nodes — single source of truth.

For **all TUR niche sites** (not only EIK), also load [`product/templates/brand-voice-tur-hyperlist.json`](../../product/templates/brand-voice-tur-hyperlist.json) into the same system context — HyperList-inspired structure + [`HYPERLIST-VOICE.md`](./HYPERLIST-VOICE.md).

```json
{
  "persona": "Emil Ingemar Karlsson — solo technical founder, Stockholm. Runs 8 sites on €35/month. Writes like he thinks: direct, specific, no buzzwords. Always grounded in something he built or measured.",
  "voice_rules": [
    "Lead with the finding, not the setup. Sentence 1 = the claim or the number.",
    "Sentences under 18 words average. Break long ideas into two sentences.",
    "One idea per paragraph. 2-4 sentences max.",
    "Use 'I'. Not passive constructions.",
    "Numbers as digits: 8 sites, €35, not 'eight' or 'thirty-five euros'.",
    "Make trade-offs explicit: 'I chose X because Y made Z impossible.'",
    "End on implication, not summary. Never restate what was just said."
  ],
  "anti_patterns": [
    "In today's rapidly evolving landscape",
    "It's worth noting that",
    "Let's dive in",
    "At the end of the day",
    "In conclusion / To summarize",
    "Whether you're a X or a Y",
    "This is a game-changer"
  ],
  "structural_logic": "Claim (sentence 1) → Evidence/example (sentence 2-3) → [condition if changes conclusion] → Implication (final sentence). This is the hierarchy. Every paragraph.",
  "topic_anchors": [
    "Proof: what I built or measured",
    "Trade-off: what I chose and why",
    "Failure: what broke and what it showed",
    "Architecture: the logic and rejected alternatives"
  ]
}
```

---

## Signal Monitoring Workflow (n8n)

**ID to create**: `signal-monitor`
**Schedule**: 07:00 daily

```
Schedule Trigger (07:00)

[Branch A — Hacker News]
HTTP GET: https://hn.algolia.com/api/v1/search?tags=story&numericFilters=points>100&dateRange=last_24h&hitsPerPage=30
→ Extract: title, url, points, num_comments

[Branch B — Reddit]
HTTP GET: https://www.reddit.com/r/MachineLearning+SideProject+entrepreneur/hot.json?limit=25
(User-Agent header required: "signal-monitor/1.0")
→ Extract: title, url, ups, num_comments

[Branch C — RSS feeds]
RSS Read node: [configured per site cluster]
→ Extract: title, link, pubDate

Merge all three branches

Code node — deduplicate + format:
  - Remove items older than 24h
  - Deduplicate by domain (max 1 item per domain)
  - Format as array: [{source, title, url, engagement_score}]

LiteLLM call — relevance scoring:
  System: "Score each signal for relevance to these topic clusters: [cluster list per site].
           Return JSON: [{title, url, score_0_10, relevant_to: [site list], reasoning_one_line}]
           Score 10 = directly relevant + high engagement. Score 1 = irrelevant.
           Only return items with score >= 6."

Code node — split by site:
  Filter items by relevant_to field
  Save: signals-tur.json, signals-taf.json, signals-tha.json etc.

Minio PUT: seo-drafts/daily-signals-[site]-[date].json per site

Telegram: brief summary to Reports topic (5)
  "Signals 15 apr: THA=4 items, TUR=7 items, TAF=3 items"
```

---

## CMO Agent (Paperclip)

**Workspace**: new workspace `cmo`
**Heartbeat**: daily, 07:30
**AGENTS.md reads**: daily-signals, editorial-memory, performance-insights

CMO agent output (saved to Minio: `cmo-briefs/brief-[site]-[date].json`):

```json
{
  "site": "theunnamedroads.com",
  "date": "2026-04-16",
  "topic": "Why n8n's expression engine breaks when you set workflows via API",
  "angle": "Practitioner postmortem — this bit me, here is exactly what happens and why",
  "hook": "n8n strips $json from your expressions when you PUT a workflow via API. Here's why and how to work around it.",
  "keywords": ["n8n api", "n8n workflow expressions", "n8n PUT workflow"],
  "tone_note": "Technical, first-person, specific. Show the actual broken expression and the fix.",
  "target_length": 600,
  "x_post_draft": "n8n stores $json.field expressions as strings. PUT via API normalizes them — $json disappears. Learned this the hard way across 3 workflows. Fix: move all data access into Code nodes. Never reference $json in an HTTP Request node's jsonBody if setting via API.",
  "signal_source": "internal — known production issue"
}
```

---

## Generator Upgrade (all sites)

**Change**: first step of every generator reads CMO brief from Minio instead of hardcoded topic.

```
Schedule Trigger
→ HTTP GET: Minio cmo-briefs/brief-[site]-[today].json
  [? file not found] → fallback to legacy keyword research file
→ Set: topic, angle, hook, tone_note from brief
→ LiteLLM generation call:
  System: [brand_voice.json for this site] + "Write a [target_length]-word article."
  User: "Topic: {{topic}}. Angle: {{angle}}. Hook to open with: {{hook}}. Tone note: {{tone_note}}"

→ [CRITIC / QA CALL — NEW]
  LiteLLM call:
  System: "You are a brand voice auditor. Score this content on 4 dimensions (1-10):
           1. Voice consistency: does it match the brand voice rules?
           2. Specificity: are claims backed by examples or data, not generalities?
           3. Original insight: does it say something not in 3 generic articles on this topic?
           4. Structure: lead sentence = claim, evidence follows, no filler?
           Return JSON: {scores: {voice, specificity, insight, structure}, overall, pass: bool, revision_notes: string}"
  User: "Brand voice rules: {{brand_voice}}. Content to audit: {{draft}}"

→ IF pass == false AND retry_count == 0:
  → LiteLLM revision call:
    System: [brand_voice]
    User: "Revise this draft. Specific issues: {{revision_notes}}. Draft: {{draft}}"
  → Run critic again (retry_count = 1)
→ IF overall >= 6: publish via OpenClaw
→ IF overall < 6 after retry: discard + Telegram alert
```

---

## Editorial Memory (Minio: brand-voice/editorial-memory.json)

Updated by `content-performance-feedback` workflow (already exists: lGsFrLuD0nlRCz8w).

```json
{
  "last_updated": "2026-04-15",
  "recent_topics_30d": [
    "n8n expression stripping bug",
    "LiteLLM proxy setup on Hetzner",
    "OpenClaw publish architecture"
  ],
  "high_performers": [
    {"slug": "how-i-run-7-sites", "pageviews_30d": 1240, "site": "theunnamedroads.com"},
    {"slug": "tha-nhl-standings-2025", "pageviews_30d": 890, "site": "thehockeyanalytics.com"}
  ],
  "avoid_for_30d": ["general n8n tutorials", "AI tool roundups"],
  "current_strategic_focus": "Consulting funnel — prioritize EIK content that demonstrates real automation results",
  "audience_insight": "TUR readers engage most with specific infrastructure breakdowns, not general AI trend pieces"
}
```

CMO agent reads this. Performance feedback workflow updates it weekly.

---

## Weekly Numbers Post (EIK / X)

New n8n workflow: `eik-weekly-numbers`
Schedule: Monday 08:00
Pulls: Umami (all 8 sites, 7 days), LiteLLM spend (7 days), Stripe events (7 days), publish count
CMO agent formats in EIK voice → Telegram approval (Emil) → X post

Template:
```
Week [N].

[X] articles published across [N] sites
Traffic: [+/-X%] vs last week
LLM spend: $[X]
[? Stripe payment] Revenue: [X] kr
[? notable event] [one line]

Everything else: ran without me.
```

This post is non-negotiable. It is the most authentic content you can produce.
Nothing about your stack is more compelling than the real numbers, weekly, forever.

---

## Build Order

```
Phase 1 (this week):
  1. Upload brand-voice/eik.json and brand-voice/tur.json to Minio
  2. Build signal-monitor workflow in n8n
  3. Add critic/QA call to one generator (TUR first, then others)

Phase 2 (next week):
  4. Create CMO agent workspace in Paperclip
  5. Wire CMO brief output → all generators
  6. Build eik-weekly-numbers workflow
  7. Add editorial memory update to performance-feedback workflow

Phase 3 (when X API approved):
  8. X auto-post after publish
  9. Weekly numbers post with Emil Telegram approval
```
