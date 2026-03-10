# OpenClaw agent-briefs och konfiguration

Det här är **agent-specar** och exempelkonfig för OpenClaw. **SEO-processen** är byggd som en best-in-class pipeline: planering → keyword-strategi → content brief → skrivning → publicering.

## Filer

| Fil | Syfte |
|-----|--------|
| **SEO-SITE-AGENT.md** | Huvudbrief för SEO & Site Intelligence Agent: fyra faser (planering, keyword, brief, skrivning), Umami, GitHub, Slack, regler och triggers. |
| **SEO-PROCESS.md** | Processbeskrivning: Fas 1–4, cadens (veckovis/daglig), var artefakter sparas (Slack, ev. docs/ i repo). |
| **SEO-PLAYBOOK.md** | Kvalitetskrav: EEAT, search intent, struktur, interna länkar, frontmatter, språk – använd vid brief och skrivning. |
| **NASTA-STEG.md** | Checklista: site-repos, Git, instructions, cron, testkör. |
| **site-repos.example.json** / **site-repos.json** | Mappning Umami-sajt → GitHub repo, contentPath, stack. |
| **seo-plan-override.example.md** | Mall för användarjusterad plan. Kopiera till `seo-plan-override.md`, fyll i pillars/fokus/gaps per sajt – agenten läser och använder vid Fas 1. |
| **OPENCLAW-INSTRUCTIONS-SHORT.txt** | Kort text att klistra in som agent instructions i OpenClaw (pekar på filerna ovan). |

**Full setup-guide:** [../SETUP-SEO-OPENCLAW.md](../SETUP-SEO-OPENCLAW.md) – steg-för-steg inkl. install-script och cron-kommandon.

## Snabbstart SEO-agent (best-in-class)

1. **Umami** – På plats: `https://umami.theunnamedroads.com`, credentials i `/data/.openclaw/umami-credentials.json`, script `umami-daily-stats.sh`.
2. **Slack** – #all-tur-ab för rapporter, briefs och godkännanden.
3. **Site-repos** – Fyll i `site-repos.json` (från example) med dina GitHub-repon per sajt.
4. **Agent** – Lägg **SEO-SITE-AGENT.md** som instructions; gör **SEO-PROCESS.md** och **SEO-PLAYBOOK.md** tillgängliga (samma instructions eller under `/data/.openclaw/agents/`).
5. **Cron** – Veckovis planering (Fas 1), veckovis keyword (Fas 2), daglig lägesrapport; Slack för brief och artikel på begäran.
6. **Git** – Valfritt: agenten pushar (SSH/PAT) eller du pushar manuellt efter draft i Slack.

Se [SEO-SITE-AGENT.md](SEO-SITE-AGENT.md) och [SEO-PROCESS.md](SEO-PROCESS.md) för exakta faser och regler; [NASTA-STEG.md](NASTA-STEG.md) för uppsättning.
