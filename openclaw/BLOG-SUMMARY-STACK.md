# Summary: My self-hosted AI and automation stack (Coolify, LiteLLM, OpenClaw, n8n)

**Purpose:** Draft for a blog post on your personal site (e.g. emilingemarkarlsson.com). Edit freely and adjust tone/length.

---

## What is this?

A fully self-hosted stack for AI chat, agents, and automation – without handing everything to OpenAI or other SaaS. Everything runs on your own infrastructure (Hetzner + Coolify), with open-source tools and full control over data and cost.

---

## Parts of the stack

### Coolify (the foundation)
- **What:** Self-hosted PaaS (alternative to Heroku/Vercel). Manages Docker containers, domains, SSL, environment variables, and deploy.
- **Role:** All services below run as Coolify "resources" on the same server. Easy to add new services, back up, and update.

### LiteLLM (AI proxy)
- **What:** A proxy that speaks the OpenAI-compatible API (`/v1/chat/completions`) but routes requests to different models (OpenAI, Anthropic, Google Gemini, DeepSeek, etc.).
- **Role:** One API key (master key) and one URL. Every service that needs an LLM (OpenClaw, Open WebUI, n8n, Langflow) points here instead of to each provider. You change model or add a new provider in LiteLLM – nothing needs to change in OpenClaw or n8n.
- **Bonus:** You can set spending limits, log usage, and see cost per request in the LiteLLM UI.

### OpenClaw (AI agent)
- **What:** An AI agent that can run tools (read files, run scripts, search memory) and talk to the user via Slack (or another interface).
- **Role:** In my setup OpenClaw is used as an **SEO and site agent**: it plans content, suggests articles based on traffic (Umami) and content plans, writes drafts, and – after approval in Slack – publishes to GitHub so Netlify builds the site. Everything is driven from Slack with short commands ("article suggestions for emilingemarkarlsson", "publish slug").
- **Technical link:** OpenClaw gets `OPENAI_API_BASE` = LiteLLM URL and `OPENAI_API_KEY` = LiteLLM master key. Then both chat and tools (e.g. memory search) use the same API.

### n8n (workflow automation)
- **What:** Visual workflow engine (node-based), like Zapier/Make but self-hosted.
- **Role:** Scheduled or triggered flows: e.g. fetch data from Umami → format → (optionally) send to LiteLLM for a summary → post to Slack. You can also run n8n → OpenClaw (n8n fetches data, OpenClaw writes the report). For the SEO flow I kept the main logic in OpenClaw (one agent, clear "Next steps" in Slack) and use n8n more as a complement where it fits (e.g. daily Umami summary if you want it via n8n instead of OpenClaw cron).

### Other services in the same Coolify project
- **Umami** – analytics (visits, top pages). Used by OpenClaw to prioritize sites and article suggestions.
- **MinIO** – S3-compatible storage (files, backup).
- **Langflow** – visual AI flow builder (can also use LiteLLM).
- **Open WebUI** – chat interface to LiteLLM (for manual chat outside Slack).

---

## What we implemented (SEO + content)

1. **One agent, multiple sites**  
   OpenClaw has one instruction set (SEO-SITE-AGENT) that applies to all sites. Site is chosen via the command (e.g. "article suggestions for emilingemarkarlsson"). Each site has its own plan file (language, pillars, content gaps).

2. **Slack as control panel**  
   The user doesn’t need to memorise commands. Every agent reply ends with "Next steps:" and exactly what to type (e.g. "Type: publish my-article-slug"). Approve/reject with a number (1–5) or "Approve" / "discard slug".

3. **Draft → GitHub → Netlify**  
   Drafts are saved in the container; on "publish slug" the agent runs a script that reads draft + metadata, finds the right repo (site-repos.json), commits and pushes. Netlify builds the site automatically. No manual copy-paste into the repo.

4. **Reminder without AI cost**  
   A simple cron on the server (e.g. 09:00) calls the Slack Incoming Webhook with a reminder ("Time to think about a new article"). No API calls, no credits – just so you don’t forget the flow.

5. **Security**  
   API keys, GitHub token, and webhook URLs live in Coolify Environment Variables or in files on the server – not in the repo. The install script only syncs agent files, plans, and scripts into the OpenClaw container.

---

## Why this combination?

- **LiteLLM in the middle:** One place for all LLM calls. Switching model or adding DeepSeek/Gemini only requires config in LiteLLM, not in every service.
- **OpenClaw for "agent work":** SEO planning, keyword strategy, brief, writing, and publishing need steps, tools (scripts, reading files), and consistent "Next steps" – that fits an agent better than building lots of small n8n flows.
- **n8n kept:** Useful for time-based or event-driven flows (e.g. "every morning fetch X and send to Slack/OpenClaw") and for wiring in services that OpenClaw doesn’t talk to directly.
- **Coolify:** One place to deploy, view logs, set env vars, and update – without manually managing docker-compose on the server every time.

---

## Short flow (SEO article)

1. **Reminder** (cron) → Slack: "Want article suggestions?"
2. **User** types: "article suggestions for emilingemarkarlsson".
3. **OpenClaw** (via LiteLLM) analyses plan + Umami, sends 3–5 suggestions to Slack with "Next steps: Type 1–5 or produce article for … about …".
4. **User** replies e.g. "2" or "Approve" → agent writes brief, then draft.
5. **User** types "publish slug" → agent runs publish script → push to GitHub → Netlify deploys.
6. **Agent** confirms in Slack with a link to the published article.

---

## Technical notes (for anyone who wants to reproduce)

- **OpenClaw ↔ LiteLLM:** In Coolify (OpenClaw) set: `OPENAI_API_BASE` = LiteLLM URL (e.g. `https://litellm.…/v1`), `OPENAI_API_KEY` = LiteLLM master key. Then both chat and tools (memory search etc.) work. If you see "Invalid OpenAI API key" – check that the key matches the one in LiteLLM and that no budget/spend limit in LiteLLM has kicked in so requests are rejected.
- **New site:** Add to `site-repos.json` (repo, contentPath, domain), create a plan file under `openclaw/agents/plans/`, run the install script, test with "article suggestions for [site]" in Slack.
- **Docs in repo:** OPENCLAW-OVERBLICK.md (overview + troubleshooting), GIT-SETUP.md (token, publish), SNABBKOMMANDON.md (Slack), SETUP-SEO-OPENCLAW.md (full setup).

---

## Conclusion (for the blog post)

You can phrase it roughly like this: *"I run a self-hosted stack with Coolify as the base, LiteLLM as the single AI gateway, OpenClaw as the agent for SEO and content, and n8n for workflow automation. Everything is driven from Slack – article suggestions, approve, publish – and Netlify builds the site on push. That gives control over data and cost, and a clear path from idea to published article."*

Edit and remove whatever doesn’t fit your site or your tone.
