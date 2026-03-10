# SEO-plan per sajt (en fil per sajt)

En **fil per sajt** gör det enkelt att justera planen: du redigerar bara filen för den sajt du vill ändra.

## Filnamn

Använd **umamiName** som filnamn (utan .md i namnet i denna mapp blir det `{umamiName}.md`):

| Sajt (domain) | Filnamn |
|---------------|---------|
| finnbodahamnplan.se | `finnbodahamnplan.md` |
| tur-theprintroute.vercel.app | `theprintroute.md` |
| tan-website.netlify.app | `theatomicnetwork.md` |
| tur-theagentfabric.vercel.app | `theagentfabric.md` |
| emilingemarkarlsson.com | `emilingemarkarlsson.md` |
| thehockeybrain.com | `thehockeybrain.md` |
| thehockeyanalytics.com | `thehockeyanalytics.md` |
| theunnamedroads.com | `theunnamedroads.md` |

## Innehåll i varje fil

Skriv vad som ska gälla för **den sajten**. Allt är valfritt – du behöver bara fylla i det du vill styra.

**Språk:** Skriv planen på **sajtens språk** (t.ex. engelska för emilingemarkarlsson.com). Då blir artikel-förslag, titlar och keywords i rätt språk.

```markdown
# [sajtens domain eller namn]

## Pillars (3–5 temaområden)
1. Pillar ett – kort beskrivning
2. Pillar två – …
3. …

## Gaps (content som saknas)
- **Hög:** …
- **Medium:** …
- **Låg:** …

## Fokus denna vecka
(Om denna sajt ska prioriteras: "Ja, prioritera" eller t.ex. "Prioritet 1 denna vecka". Annars låt stå tomt.)

## Anteckningar
(Valfria rader till agenten.)
```

Om du bara vill **ändra fokus** för en sajt räcker det med att skapa en fil med t.ex. endast:

```markdown
# theunnamedroads.com
## Fokus denna vecka
Prioritet 1 denna vecka.
```

Agenten läser alla `.md`-filer i denna mapp och matchar filnamnet (utan .md) mot **umamiName** i site-repos.json. Finns en fil för en sajt används den; saknas fil används automatisk analys.

## Var kan jag redigera?

**Var redigera:** OpenClaw UI (Agents → main → Files) visar bara **Core Files** (AGENTS.md, SOUL.md, …), inte planfilerna. Redigera därför planerna **här i repot** under **openclaw/agents/plans/** (t.ex. `theunnamedroads.md`, `finnbodahamnplan.md`). Kör sedan **`./scripts/openclaw-install-seo-agent.sh`** så kopieras de till containern som `seo-plan-{umamiName}.md` – agenten läser dem vid nästa Fas 1.

**Efter redigering:** Kör **`./scripts/openclaw-install-seo-agent.sh`** så kopieras planerna till containern (`/data/workspace/seo-plan-*.md` och `/data/.openclaw/agents/plans/`).
