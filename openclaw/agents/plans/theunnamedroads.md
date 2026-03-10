# theunnamedroads.com

## SEO positioning

The Unnamed Roads is **the playbook for building AI-native companies as a solo founder**.  
The site focuses on operators who use AI agents instead of employees, build multiple ventures in parallel, and treat systems and workflows as their main leverage. Articles should challenge the traditional startup narrative (big teams, VC funding, office culture) and instead showcase how a single, well-equipped operator plus AI can ship at venture scale.

## Pillars (3–5 temaområden)

1. **AI-Native Business Models & Strategy**  
   How to design businesses where AI is part of the core value creation, not an add-on. Pricing models, value props, moats, and defensibility in an AI-saturated market.

2. **AI Agents, Systems & Workflows**  
   Practical architectures for autonomous agents, toolchains, orchestration, monitoring, and safety. How to move from “chat with a model” to real systems that run parts of the business.

3. **Solo Founder Operating Systems**  
   How a single operator uses AI to manage product, growth, operations, finance, and support. Decision-making frameworks, weekly rhythms, dashboards, and feedback loops.

4. **Tactical AI Execution & Automation**  
   Deep dives into concrete workflows: lead generation, research, content, product experiments, customer success, data pipelines, and internal tools powered by AI.

5. **AI-Leveraged Lifestyle (Optional)**  
   How to design a life around AI leverage: time freedom, geographic flexibility, parallel projects, and personal energy management for long-term, high-output work.

## Gaps (content som saknas)

- **High priority:**  
  - Step-by-step guides for **launching a one-person AI-native startup** from zero to first dollars.  
  - Detailed, real-world **case studies** of solo founders running multi-venture portfolios with agents.  
  - **Playbooks for deploying AI agents in specific business functions** (sales, support, ops, product) with concrete tool stacks and prompts.  
  - Comparisons: **AI-native vs traditional SaaS** – economics, speed, margins, and risks.

- **Medium priority:**  
  - Templates for **operating systems** (weekly review, experiment boards, scorecards) tailored to AI-augmented founders.  
  - Guides on **choosing, evaluating, and switching models/providers** as a solo operator without breaking systems.  
  - Patterns for **combining n8n / automation tools with AI agents** for robust, low-maintenance workflows.

- **Low priority:**  
  - Opinion pieces on the future of work, venture capital, and employment in an AI-native world (useful for authority, but secondary to tactical guides).  
  - High-level thinkpieces about “the future of AI” that are not anchored in concrete solo-founder decisions.

## Site language

- **Språk:** Engelska (hela artikeln ska vara på engelska).  
- **Ton:** Personal but sharp, opinionated, systems-driven, and explicitly anti-traditional startup narrative. Write for an ambitious solo operator who wants leverage, not headcount.

## Frontmatter & filstruktur (viktigt för publicering)

- **Filplats:** `src/content/posts/{slug}.md`  
  (slug = kebab-case, t.ex. `workflow-automation-solutions-for-business.md` → URL `/posts/workflow-automation-solutions-for-business`).
- **Frontmatter för denna sajt måste följa `src/content/config.ts` – använd exakt dessa fält:**
  - `title: "..."` – används som H1/SEO-titel.
  - `description: "..."` – meta description (~150–160 tecken, inkl. huvud-keyword).
  - `publishedDate: 2025-01-20` – **datumfältet heter `publishedDate` (inte `publishDate`/`pubDate`)**. Använd ISO-datum `YYYY-MM-DD`.
  - `author: "Emil Ingemar Karlsson"` eller den author som passar artikeln.
  - `authorAgent: aion` (valfritt, sätt om artikeln bör märkas som skriven av en agent).
  - `tags: ['tag-1', 'tag-2']` – 2–5 relevanta tags, gemener, kebab-case.
  - `draft: false` när artikeln är redo att publiceras (drafts ska normalt inte sparas i detta repo).
- Följ även generella regler i `SEO-PLAYBOOK.md` (EEAT, struktur, interna länkar), men **för datumfältet gäller alltid `publishedDate` för theunnamedroads.com.**

## Primary keyword clusters

- **AI-native company building**
  - build a business with AI  
  - AI native company  
  - AI-first business model  
  - AI-powered SaaS for solo founders  

- **Solo founder & one-person startup**
  - one person startup with AI  
  - AI solopreneur  
  - solo founder operating system  
  - build multiple businesses as a solo founder  

- **AI agents & workflows**
  - AI agents for business  
  - autonomous AI workflows  
  - AI agents for operations / support / growth  
  - agentic workflows for small companies  

- **Tactical execution**
  - AI workflows for lead generation  
  - AI content engine for B2B  
  - AI for customer success and onboarding  
  - automate back office with AI  

Keywords ska användas naturligt i titlar, descriptions, H1, och brödtext – men alltid förankras i verkliga system, diagram och playbooks.

## Cornerstone article recommendation

**Arbetsnamn:**  
**“How to Build an AI-Native Company as a Solo Founder: The Operating System and Playbook”**

- **Syfte:** Vara den huvudsakliga referensen som allt annat länkar till när någon söker “AI native company”, “one person startup with AI” eller “AI solopreneur”.  
- **Innehåll:**  
  - Definition av AI-native företag och varför klassiska startup-råd (team, funding, office) inte passar solo-operatorn.  
  - Genomgång av de fyra huvudpelarna: business model, agents & systems, operating system, tactical execution.  
  - Konkreta arkitekturdiagram som visar hur AI-agenter, LiteLLM, n8n, Coolify m.fl. samverkar.  
  - Ett komplett veckoflöde för en AI-leveraged solo founder (från idé → experiment → deploy).  
- **Struktur:**  
  - Lång, djupgående guide (3 000+ ord), rik på interna länkar ut till mer specifika artiklar (t.ex. agent-playbooks, workflow-exempel, case studies).  
  - Ska ligga nära navet i internlänknings-strategin (se nedan).

## Internal linking strategy

- **Från alla taktik-artiklar → cornerstone:**  
  - Varje artikel om en specifik workflow, verktygstack eller agent ska länka tillbaka till cornerstone-artikeln med ankartext i stil med:  
    - “AI-native operating system for solo founders”  
    - “full playbook for building an AI-native company”
- **Mellan pelare:**  
  - Artiklar inom samma pillar (t.ex. AI agents & systems) ska länka till varandra med beskrivande ankartext:  
    - “agent architecture for customer support”  
    - “workflow design for autonomous research agents”.
- **Nedåtlänkar från cornerstone:**  
  - Cornerstone-artikeln länkar ut till:  
    - Case studies  
    - Workflow breakdowns  
    - Tooling deep dives (LiteLLM, OpenClaw, n8n, Open WebUI, etc.)  
  - Detta skapar en tydlig struktur där cornerstone = overview, övriga = detaljer.
- **Navigation via clusters:**  
  - Använd taggar som mappar till klustren ovan (`ai-native-company`, `ai-solofounder`, `ai-agents`, `ai-workflows`).  
  - Se till att tag-sidor och listor speglar verklig tematisk struktur (inte slumpmässiga labels).

## EEAT strategy (authority building)

- **Experience:**  
  - Basera artiklar på faktiska experiment, stackar och system du använder (Coolify, LiteLLM, OpenClaw, n8n, Umami, Netlify osv.).  
  - Visa loggar, arkitekturdiagram, screenshots (där det passar) och konkreta siffror (utan att exponera känsliga data).

- **Expertise:**  
  - Gå djupt på systemdesign, inte bara “5 AI tools you should try”.  
  - Förklara varför vissa arkitekturer är bättre för solo operators (cost, complexity, failure modes).  
  - Jämför alternativ och var tydlig med tradeoffs.

- **Authoritativeness:**  
  - Bygg serier av artiklar som följer samma teman (t.ex. “AI Operating System Series”, “Agent Workflow Series”).  
  - Publicera återkommande rapporter / “field notes” från egna experiment (12-week experiments, venture engine, etc.).  
  - Få externa länkar genom att skapa genuint användbara playbooks som andra operatörer vill referera till.

- **Trustworthiness:**  
  - Var transparent med begränsningar: vad du inte har testat, vad som är hypotes vs bevisad praktik.  
  - Länka till externa källor (papers, docs, repo-readmes) när du bygger vidare på andras idéer.  
  - Ha tydlig författarsignatur med kort bio som förklarar din roll som AI-native operator/venture studio.

## Fokus denna vecka

(Prioritera denna sajt: Ja/Nej eller t.ex. "Prioritet 2".  
Exempel: “Prioritet 1 – skriv cornerstone-artikeln + en taktisk workflow-artikel som länkar till den.”)

## Anteckningar

(Running notes: vilka serier är på gång, vilka experiment körs nu, vilka keywords som börjar ranka, vad som behöver uppdateras eller fördjupas.)
