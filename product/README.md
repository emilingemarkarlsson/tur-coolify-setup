# The €35/month AI Stack

**One Hetzner VPS. Coolify. n8n. LiteLLM. 33 workflow templates. Everything you need to run a self-hosted AI publishing operation.**

This is the exact stack behind [The Unnamed Roads](https://theunnamedroads.com) — 7 live sites publishing AI-generated content daily, with analytics, newsletter dispatch, and Telegram notifications. Total infra cost: ~€35/month.

---

## What's included

```
the-35-euro-ai-stack/
├── README.md                    ← this file
├── setup/
│   ├── 01-hetzner-setup.md      ← VPS setup (5 min)
│   ├── 02-coolify-setup.md      ← deploy platform (15 min)
│   ├── 03-n8n-setup.md          ← workflow engine (10 min)
│   ├── 04-litellm-setup.md      ← LLM proxy (10 min)
│   └── 05-openclaw-setup.md     ← publish server (15 min)
├── workflows/
│   ├── README.md                ← all 33 workflows explained
│   └── *.json                   ← import directly into n8n
└── templates/
    └── site-repos.json          ← OpenClaw multi-site config
```

---

## The stack

| Component | Purpose | Cost |
|-----------|---------|------|
| [Hetzner CX32](https://hetzner.cloud/?ref=ECLED3WXrvIQ) | VPS — runs everything | €13/mo |
| Coolify | Self-hosted PaaS, manages containers | Free (self-hosted) |
| n8n | Workflow automation engine | Free (self-hosted) |
| LiteLLM | LLM proxy + cost tracking | Free (self-hosted) |
| Minio | S3-compatible object storage | Free (self-hosted) |
| Umami | Privacy-first analytics | Free (self-hosted) |
| Listmonk | Newsletter management | Free (self-hosted) |
| OpenClaw | Publish server (GitHub commits) | Free (self-hosted) |
| Groq API | Fast LLM inference | ~€5–8/mo |
| Gemini API | Quality content generation | ~€3/mo |
| Netlify/Vercel | Site hosting | Free tier |
| **Total** | | **~€21–24/mo** |

---

## What the 33 workflows do

### Daily analytics (5 workflows)
Umami data → week-over-week comparison → Telegram. Runs every morning at 08:00.

### SEO content pipeline (6 workflows)
Keyword research → topic scoring → article generation → quality gate → publish → IndexNow.

### Article generators (7 workflows)
One per site. Groq or Gemini → OpenClaw → GitHub commit → Netlify/Vercel deploy.

### Publishing infrastructure (3 workflows)
Newsletter dispatch, Telegram approval flow, Bluesky posting.

### Monitoring (2 workflows)
Error notifications, monthly traffic + cost report.

### Utility (10 workflows)
Contact form handling, early access signups, AEO optimization, feedback loops.

---

## Who this is for

- Solo founders who want to run multiple content sites without a team
- Developers tired of paying €50+/month per managed service
- Anyone who wants to self-host n8n, LiteLLM, Umami, and Listmonk without the setup pain

---

## What you need before starting

- A credit card (for Hetzner — €13/month)
- A Groq API key (free tier covers most usage)
- A GitHub account
- Basic comfort with a terminal (copy/paste level, not developer level)

---

## Support

Questions? Reach out via [emilingemarkarlsson.com/contact](https://emilingemarkarlsson.com/contact)
