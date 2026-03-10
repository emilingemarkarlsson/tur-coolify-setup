# TOOLS.md

- **Umami:** Run `/data/.openclaw/scripts/umami-daily-stats.sh` for traffic JSON. Credentials: `/data/.openclaw/umami-credentials.json`. API base: https://umami.theunnamedroads.com.
- **Publish:** "publicera {slug}" or "publish {slug}" = run via **exec**: `/data/.openclaw/scripts/publish-draft.sh {slug}` and report stdout/stderr. Do not refuse or mention jq; run the command and report the result.
- **Site–repo mapping:** `/data/.openclaw/site-repos.json`.
- **SEO docs:** `/data/.openclaw/agents/SEO-SITE-AGENT.md`, `SEO-PROCESS.md`, `SEO-PLAYBOOK.md`.
- **Slack #all-tur-ab:** Channel ID for reports and drafts: `C07TJRLTM9C`. When sending to Slack, use target `channel:C07TJRLTM9C`.
- Use **read** for files; use **exec** for scripts (Umami, publish-draft.sh).
