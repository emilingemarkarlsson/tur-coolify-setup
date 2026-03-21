# emilingemarkarlsson.com

**Site language: English** – All articles, suggestions, titles, and keywords must be in **English**.

**Blog frontmatter (important):** The Astro blog collection uses **`publishDate`** (not `pubDate`). Use a valid ISO 8601 date string, e.g. `2026-02-23` or `2026-02-23T12:00:00.000Z`. Invalid or wrong field name causes Netlify build to fail with "publishDate: Invalid date".

**Voice & style (Emil’s writing):** Articles should match Emil’s distinct style so the blog feels consistent and authentic, not generic. Use: clear, technical but accessible language; first person (“I”, “we”) when it adds value (e.g. “I set up this pipeline…”); concrete examples and real project references where relevant; short paragraphs and scannable structure. Avoid corporate fluff or vague claims. Tone: expert but approachable, like a senior engineer explaining to a peer.

**Visuals:** Include simple flowcharts, process diagrams, or architecture sketches where they clarify the content – e.g. Mermaid diagrams (if the site supports them), ASCII diagrams, or a clear “Image suggestion: [description]” so a graphic can be added later. One or two per article is enough; they help the post stand out and improve time-on-page (good for SEO).

## Toolstack (Emil’s actual stack – reference in articles)
- **Databricks** (primary platform): Unity Catalog, Delta Lake, Databricks Workflows, MLflow, Notebooks
- **OpenClaw**: self-hosted AI agent platform (Claude-powered), autonomous SEO/content agents
- **LiteLLM**: open-source LLM proxy for routing/cost control across providers
- **Coolify**: self-hosted PaaS for container deployments on Hetzner
- **n8n**: workflow automation / API orchestration
- **Astro**: static site framework
- **Hetzner VPS**: infrastructure

## Pillars (topic areas – prioritised)

1. **Chat with Data & Proactive Data Agents** ← HIGH PRIORITY
   - AI agents that query, monitor, and proactively report on data (Databricks-first)
   - Chat interfaces on top of Delta Lake / Unity Catalog
   - LLM-driven anomaly detection, auto-reports, triggered insights
   - Keywords: “chat with data Databricks”, “proactive data agent”, “LLM data pipeline”, “AI data monitoring”, “natural language queries Delta Lake”

2. **OpenClaw & Self-Hosted AI Agents** ← HIGH PRIORITY
   - Building and running autonomous AI agents with OpenClaw
   - How the SEO/content automation stack works end-to-end
   - Self-hosted AI vs cloud AI tradeoffs
   - Keywords: “OpenClaw AI agent”, “self-hosted AI agent platform”, “autonomous SEO agent”, “Claude agent self-hosted”, “AI content automation”

3. **Databricks Engineering** ← HIGH PRIORITY
   - Modern data stack patterns with Databricks as the backbone
   - Delta Lake, Unity Catalog, Workflows, MLflow in practice
   - Lakehouse architecture, medallion layers, real-world pitfalls
   - Keywords: “Databricks Unity Catalog tutorial”, “Delta Lake pipeline”, “Databricks MLflow workflow”, “lakehouse architecture guide”, “Databricks data engineering 2025”

4. **Workflow Automation & Orchestration**
   - n8n pipelines, API automation, event-driven workflows
   - Connecting LLMs to data pipelines (LiteLLM + Databricks patterns)
   - Keywords: “n8n Databricks integration”, “LLM workflow orchestration”, “LiteLLM proxy setup”, “API automation tutorial”

5. **Self-Hosting & Infrastructure**
   - Coolify, Hetzner, Docker – running production AI/data workloads cheaply
   - Self-hosted LLM stack (LiteLLM, Ollama, OpenClaw on VPS)
   - Keywords: “self-hosted LLM stack”, “Coolify deployment guide”, “Hetzner VPS AI workloads”, “self-hosted Coolify tutorial”

## Gaps (content to add)
- **High:** Zero articles specifically about OpenClaw, chat-with-data patterns, or proactive data agents – these are unique angles Emil can own.
- **High:** No Databricks-specific tutorials despite it being the primary stack – large search volume, low competition for niche long-tails.
- **Medium:** No articles connecting LiteLLM / OpenClaw to Databricks – this cross-tool content is a differentiation opportunity.
- **Low:** Internal linking between toolstack articles is missing.

## First articles to create (priority order)
1. “How I Built a Proactive Data Agent on Databricks That Slacks Me Anomalies Before I Notice Them”
2. “Chat With Your Delta Lake: Building a Natural Language Query Layer on Databricks”
3. “OpenClaw: How I Run Autonomous AI Agents on My Own Server for Almost Nothing”
4. “Databricks Unity Catalog in Practice: What the Docs Don’t Tell You”
5. “LiteLLM as an LLM Router: Why Every Team Running Multiple Models Needs This”
6. “From Zero to Self-Hosted AI Stack: Coolify + LiteLLM + OpenClaw on Hetzner”
7. “Proactive vs Reactive Data: The Mindset Shift That Changes How You Build Pipelines”

## Keyword clusters
| Cluster | Keywords |
|---------|----------|
| Chat with data | chat with data Databricks, natural language SQL Databricks, LLM data query, ask your data AI |
| Proactive agents | proactive data agent, AI anomaly detection pipeline, LLM monitoring Databricks, data agent Slack alert |
| OpenClaw | OpenClaw agent, self-hosted Claude agent, autonomous AI content agent, OpenClaw tutorial |
| Databricks | Databricks Unity Catalog guide, Delta Lake tutorial 2025, Databricks MLflow, Databricks workflow automation |
| LiteLLM | LiteLLM proxy setup, LiteLLM multiple providers, open source LLM router |
| Self-hosting | self-hosted AI stack, Coolify self-host, Hetzner AI deployment, self-hosted LLM 2025 |

## Affiliate programs (include relevant links in articles)

Include affiliate links **only when the tool is genuinely mentioned in context** – never force it. Add a short "Tools used" or "Resources" section at the end of articles where natural.

| Program | Link (replace REFERRAL_CODE) | Commission | When to include |
|---------|------------------------------|-----------|-----------------|
| **Hetzner Cloud** | `https://hetzner.cloud/?ref=REFERRAL_CODE` | 20 EUR credit per signup | Any article about self-hosting, VPS, Coolify, infrastructure |
| **n8n Cloud** | `https://n8n.partnerlinks.io/REFERRAL_CODE` | Recurring % | Articles about workflow automation, n8n tutorials |
| **Coolify Cloud** | `https://coolify.io/?via=REFERRAL_CODE` | Recurring % | Self-hosting, deployment, Coolify setup articles |
| **ConvertKit (Kit)** | `https://partners.convertkit.com/REFERRAL_CODE` | 30% recurring | Articles about email marketing, newsletter building |
| **Databricks** | Partner program – contact Databricks | Deal-based | Enterprise data stack articles (link to partner page, not affiliate) |

**Newsletter CTA** – include at the end of every article:
```
---
*If you found this useful, I write about [topic] and more in my newsletter. [Subscribe here](https://emilingemarkarlsson.ck.page/subscribe).*
```

## Notes
- Emil’s unique angle is the **full stack**: Databricks (enterprise data) + OpenClaw/LiteLLM (self-hosted AI) + Coolify (infra). Very few people write from this exact vantage point – lean into it.
- Articles should reference real experiences and concrete numbers (costs, latency, model comparisons) – not generic overviews.
- Tone: senior data/AI engineer explaining to peers. First-person, opinionated, concrete.
