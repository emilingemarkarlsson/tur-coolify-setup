# Agent Writer som artikel-motor på Coolify

[Agent Writer](https://github.com/gregorym/agent-writer) är en open-source-app (AGPL v3) för AI-genererade bloggartiklar, keyword-analys och publicering till Ghost eller **GitHub (MDX via Pull Requests)**. Här beskrivs om det går att använda som motor för dina sajter och hur du hostar det på Coolify.

---

## Kort svar: ja, med anpassningar

- **Multi-site:** Appen har inbyggt stöd för flera webbplatser – du kan lägga in alla 8 sajter och koppla varje till rätt GitHub-repo.
- **GitHub:** Publicering sker som MDX-filer via PR, vilket passar Astro (`src/content/blog` eller `src/content/posts`) om du anpassar eller konfigurerar sökväg/frontmatter.
- **Coolify:** Projektet har **ingen färdig Docker-image**. Du behöver bygga egen image (Dockerfile) och köra web + worker + PostgreSQL (t.ex. som separata services i Coolify).

---

## Vad Agent Writer ger dig

| Funktion | Beskrivning |
|----------|-------------|
| **AI-artiklar** | Långa artiklar från keyword/ämne via Google Gemini; kan generera bilder. |
| **Keyword-analys** | DataForSEO API – keyword för URL, relaterade keywords. |
| **Schemaläggning** | Planera generering och publicering i tid. |
| **GitHub** | Publicera som MDX via Pull Request (PAT eller GitHub App). |
| **Multi-site** | Hantera flera webbplatser med egna integrationer. |

**Stack (från CONTRIBUTING):** Next.js (apps/web), Node-worker (apps/worker), PostgreSQL, Prisma, Lucia Auth, Gemini, DataForSEO, Octokit (GitHub).

---

## Vad som behöver anpassas

### 1. Docker & Coolify

- Repot har **ingen Dockerfile**. Du behöver:
  - **Dockerfile** för monorepot: install (pnpm), build (web + worker), och antingen en image som kör både web och worker, eller två images (web + worker).
  - **docker-compose.yml** med:
    - **agent-writer-web** (Next.js, port 3000)
    - **agent-writer-worker** (background jobs)
    - **PostgreSQL** (om du inte redan har en delad Postgres)
  - I Coolify: nytt projekt → deploy med denna compose; sätt domain och env-variabler.

### 2. Content-sökväg och format (Astro)

- Agent Writer publicerar till GitHub som **MDX**. Dina Astro-sajter använder t.ex.:
  - `src/content/blog/*.md` eller `src/content/posts/*.md`
  - Frontmatter enligt varje sajts schema (title, description, pubDate, tags, heroImage, m.m.).
- Du måste kontrollera i Agent Writers kod **vilken mapp/filnamn** som används vid GitHub-push. Om den skriver till t.ex. `content/blog/` eller `posts/` måste du antingen:
  - **Konfigurera** (om appen har path per site), eller
  - **Patcha** så att den skriver till `src/content/blog/` (eller `src/content/posts/`) och att frontmatter matchar dina Astro-collections (t.ex. från `site-repos.json` / `contentPath`).

### 3. Integrations mot din nuvarande setup

- **Umami:** Agent Writer använder inte Umami idag. Du kan:
  - **Antingen** använda Agent Writer enbart för redaktionell motor (keyword → artikel → PR) och låta OpenClaw + Umami vara kvar för trafikanalys och SEO-briefs.
  - **Eller** senare lägga till en integration (t.ex. läsa Umami per site för att prioritera vilken sajt/keyword som ska få nästa artikel).
- **site-repos.json:** Din fil med domain ↔ GitHub-repo kan användas som referens när du konfigurerar “Websites” i Agent Writer (en site = en domain + ett repo). Ev. kan du bygga ett litet import-script som skapar sites i Agent Writer utifrån `site-repos.json`.

### 4. API-nycklar och secrets

- **Obligatoriskt:** PostgreSQL, Google Gemini API, Lucia (auth secrets).
- **För GitHub-publish:** GitHub Personal Access Token (repo scope) eller GitHub App – samma som du skulle använda för OpenClaw push.
- **Valfritt:** DataForSEO (keyword-analys). Utan det får du fortfarande AI-artiklar och manuell keyword-input.

---

## Steg för att köra på Coolify (högnivå)

1. **Forka/clona Agent Writer** (AGPL kräver att ändringar kan redovisas om du distribuerar).
2. **Lägg till Dockerfile(s)** i ditt fork:
   - Node 18+, pnpm, `pnpm install`, `pnpm build` (web + worker).
   - Antingen en Dockerfile som startar både web och worker, eller separata för web respektive worker.
3. **Lägg till docker-compose.yml** (eller använd den i denna guide) med web, worker och Postgres; miljövariabler enligt deras `.env.example` / dokumentation.
4. **Skapa databas:** Kör Prisma-migrationer vid första start (`pnpm prisma migrate deploy` i database-paketet).
5. **Coolify:** Ny Application (Docker Compose) → klistra in compose, sätt env (DATABASE_URL, GEMINI_API_KEY, GITHUB_TOKEN, etc.), sätt domain och deploy.
6. **I Agent Writer UI:** Lägg till dina 8 webbplatser (namn + URL), koppla GitHub-integration per sajt med rätt repo. Kontrollera/ändra content path om det behövs för Astro.

---

## Exempel docker-compose (Coolify)

Nedan är ett **skelett** du kan klistra in i Coolify och justera (image-namn, volumes, env). Eftersom Agent Writer inte levererar färdiga images måste du först bygga en image (t.ex. från ett eget repo som inkluderar Dockerfile).

```yaml
# agent-writer/docker-compose.yml (exempel – kräver egen byggd image)
services:
  agent-writer-db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: agentwriter
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: agentwriter
    volumes:
      - agentwriter_pgdata:/var/lib/postgresql/data
    restart: unless-stopped

  agent-writer-web:
    image: ${AGENT_WRITER_IMAGE:-ghcr.io/ditt-org/agent-writer:latest}
    env_file: .env
    environment:
      DATABASE_URL: postgresql://agentwriter:${POSTGRES_PASSWORD}@agent-writer-db:5432/agentwriter
      # GEMINI_API_KEY, GITHUB_TOKEN, NEXTAUTH_* etc.
    depends_on:
      - agent-writer-db
    restart: unless-stopped
    # Coolify/Traefik: labels för domain

  agent-writer-worker:
    image: ${AGENT_WRITER_IMAGE:-ghcr.io/ditt-org/agent-writer:latest}
    command: ["node", "apps/worker/dist/index.js"]
    env_file: .env
    environment:
      DATABASE_URL: postgresql://agentwriter:${POSTGRES_PASSWORD}@agent-writer-db:5432/agentwriter
    depends_on:
      - agent-writer-db
    restart: unless-stopped

volumes:
  agentwriter_pgdata: {}
```

Du behöver alltså först i ditt fork (eller eget repo) lägga till en **Dockerfile** som bygger Next.js + worker och exponerar rätt entrypoints, sedan bygga och pusha image till t.ex. GHCR eller Docker Hub och referera den i `AGENT_WRITER_IMAGE`.

---

## Jämfört med nuvarande OpenClaw SEO-agent

| | OpenClaw SEO-agent | Agent Writer |
|--|-------------------|--------------|
| **Plats** | OpenClaw (befintlig) | Egen app på Coolify |
| **Datakälla** | Umami + site-repos.json | DataForSEO (keyword) + egna sites |
| **Output** | Draft → Slack → manuell/script push | UI → schemaläggning → direkt PR till GitHub |
| **Auth/DB** | Ingen egen DB | PostgreSQL + inloggning |
| **Anpassning** | Brief + script | Kod (path, frontmatter, ev. Umami) |

Du kan köra **båda**: OpenClaw för daglig Umami-rapport + SEO-brief och prioritering; Agent Writer som redaktionell motor som skriver artiklar och öppnar PR mot samma repon. Om du vill att Agent Writer också ska använda Umami för prioritering krävs en egen liten integration (t.ex. anropa Umami API eller samma script som `umami-daily-stats.sh`).

---

## Sammanfattning

- **Ja**, du kan använda Agent Writer som motor för artiklar till dina sajter och hosta på Coolify.
- **Måste:** Dockerisera projektet (Dockerfile + compose), köra Postgres, sätta env (Gemini, GitHub, DB). Eventuell anpassning av content path och frontmatter för Astro.
- **Valfritt:** Koppla in Umami/site-repos för prioritering; behålla OpenClaw för rapporter och briefs.

Om du vill kan nästa steg vara att lägga upp en konkret **Dockerfile** och en **docker-compose.yml** i ett eget katalog (t.ex. `agent-writer/`) i tur-coolify-setup som bygger från din fork av Agent Writer och är redo att deploya i Coolify.
