# Workflow Reference

All 33 n8n workflows included in this pack. Import each `.json` file via n8n → Workflows → Import from file.

---

## Before you import

Every workflow has placeholder values for:
- `YOUR_TELEGRAM_BOT_TOKEN`
- `YOUR_TELEGRAM_CHAT_ID`
- `YOUR_GITHUB_TOKEN`
- API keys (Groq, Gemini, Minio)

Update these in the workflow or as n8n credentials after importing.

---

## Daily analytics (5 workflows)

| File | What it does | Schedule |
|------|-------------|---------|
| `tha-dailyumamireport.json` | Traffic report for The Hockey Analytics → Telegram | 08:00 daily |
| `eik-dailyumamireport.json` | Traffic report for EIK → Telegram | 08:05 daily |
| `thb-dailyumamireport.json` | Traffic report for The Hockey Brain → Telegram | 08:10 daily |
| `taf-dailyumamireport.json` | Traffic report for The Agent Fabric → Telegram | 08:15 daily |
| `weekly-traffic-report.json` | Week-over-week comparison all sites → Telegram | Mon 09:00 |

**Needs:** Umami Postgres credentials, Telegram bot token

---

## SEO content pipeline (6 workflows)

| File | What it does | Schedule |
|------|-------------|---------|
| `tha-keyword-research.json` | NHL API + Groq → scored keyword list → Minio | 09:45 daily |
| `tha-seogenerator.json` | Reads keywords → Groq article → quality score → publish | 10:00 daily |
| `tha-seopublisher.json` | Webhook → Minio draft → GitHub → IndexNow → Telegram | on webhook |
| `eik-keyword-research.json` | Seed topics → Groq score → Minio + Telegram | 08:00 daily |
| `eik-seo-generator.json` | Reads keywords → Groq+E-A-T → Minio draft → Telegram buttons | 09:00 daily |
| `eik-seo-publisher.json` | Webhook → Minio → GitHub → IndexNow → Telegram | on webhook |

**Needs:** Minio credentials, Groq API key, GitHub token, Telegram

---

## Article generators (7 workflows)

| File | What it does | Schedule |
|------|-------------|---------|
| `thb-daily---nhl-playoff-bubble-article.json` | NHL API live standings → Gemini → GitHub → IndexNow → Telegram | daily |
| `tur-article-generator.json` | Groq → OpenClaw → theunnamedroads.com/posts/ | 11:00 daily |
| `tan-article-generator.json` | Groq → OpenClaw → tan-website.netlify.app/blog/ | 11:30 daily |
| `taf-article-generator.json` | Groq → OpenClaw → tur-theagentfabric.vercel.app/blog/ | 12:00 daily |
| `tpr-article-generator.json` | Groq → OpenClaw → tur-theprintroute.vercel.app/blog/ | daily |
| `fin-dailyumamireport.json` | Finance site analytics → Telegram | 08:20 daily |
| `tpr-dailyumamireport.json` | TPR analytics → Telegram | 08:25 daily |

**Needs:** Groq API key, OpenClaw endpoint, Telegram

---

## Publishing infrastructure (4 workflows)

| File | What it does | Trigger |
|------|-------------|---------|
| `article-published---newsletter-dispatch.json` | Webhook → Resend → Bluesky | on webhook |
| `tur---telegram-approvals.json` | Inline button callbacks → OpenClaw publish | on Telegram callback |
| `newsletter-signup-handler.json` | Signup form → Listmonk → Telegram | on webhook |
| `tpr-earlyaccess-telegram.json` | Early access form → Telegram | on webhook |

**Needs:** Resend API key, Listmonk credentials, Telegram, Bluesky credentials

---

## Monitoring (2 workflows)

| File | What it does | Trigger |
|------|-------------|---------|
| `monitor---telegram-on-error.json` | Any workflow error → Telegram alert | on error |
| `monthly-report.json` | Umami MoM traffic + LiteLLM spend → Telegram | 1st of month |

**Needs:** Telegram, Umami Postgres, LiteLLM API key

---

## Utility (9 workflows)

| File | What it does |
|------|-------------|
| `tur-contactnotificationtotelegram.json` | Contact form → Telegram |
| `content-performance-feedback.json` | Mon 09:15 → Umami top articles → Groq analysis → Minio insights |
| `aeo-content-optimizer.json` | AEO/GEO content optimization pass |
| `geo-aeo-intelligence.json` | GEO signal monitoring |
| `ai-traffic-monitor.json` | AI referrer tracking (ChatGPT, Perplexity, etc.) |
| `store-seo-draft.json` | Webhook → store draft in Minio |
| `eik-keyword-approver.json` | Webhook → Telegram confirmation for EIK keywords |
| `tur-dailyumamireport.json` | TUR analytics → Telegram |
| `tan-dailyumamireport.json` | TAN analytics → Telegram |

---

## Activation order (recommended)

1. `monitor---telegram-on-error` — activate first so you catch setup errors
2. Daily umami reports — validate your Umami connection
3. Keyword research workflows — validate Minio + Groq
4. Article generators — validate OpenClaw connection
5. SEO pipeline — validate full research → generate → publish chain
6. Everything else
