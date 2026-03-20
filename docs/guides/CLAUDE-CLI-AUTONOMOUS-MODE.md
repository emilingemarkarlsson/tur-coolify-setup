# Claude CLI – Autonomt läge

Riktlinjer för vad Claude får göra självständigt i detta projekt kontra när godkännande krävs.

---

## Autonoma åtgärder (kör utan att fråga)

| Åtgärd | Exempel |
|--------|---------|
| Läs/sök filer | `Read`, `Glob`, `Grep` |
| Redigera/skapa filer | `Edit`, `Write` – kod, config, docs |
| Kör lokala scripts | `server-health.sh`, diagnos, verify |
| SSH till `tha` – läsning | `docker ps`, `df -h`, `free -h`, `apt list` |
| SSH till `tha` – säkra scripts | `coolify-update.sh list/status`, `server-health.sh` |
| Apt upgrade på `tha` | Systempaket, Docker-uppdateringar |
| Starta om / deploya containers | `coolify-update.sh deploy/restart <uuid>` |
| Synka filer till container | `openclaw-install-seo-agent.sh` |
| Git add + commit | Lokal commit, valfri branch |
| Skapa ny branch | `git checkout -b fix/...` |
| Söka webben | `WebSearch`, `WebFetch` |
| Spara till minne | `/memory/` i projektet |
| SEO-arbete t.o.m. draft | Planering, keyword, brief, skriva artikel, spara draft |

---

## Kritiska åtgärder (vänta på godkännande)

| Åtgärd | Anledning |
|--------|-----------|
| `git push` till `main` | Publiceras publikt – fråga alltid |
| `git push --force` | Destruktiv historieskrivning |
| Publicera artikel (`publicera <slug>`) | Går live på sajten |
| Radera filer/mappar permanent | Svårt att återställa |
| `docker rm`, `docker volume rm` | Destruktiv |
| Ändra/skapa secrets eller API-nycklar | Säkerhetsrisk |
| Ny betaltjänst eller nytt API med kostnad | Ekonomisk påverkan |
| Ändra Coolify environment variables | Påverkar produktion |
| Skicka meddelanden till Slack | Synligt för teamet |
| `git reset --hard` på main | Destruktiv |

---

## Väntestrategi (om du inte svarar)

1. Spara state – skriv vad som är klart och vad som väntar.
2. Fortsätt med parallellt arbete som inte kräver godkännande.
3. Vänta max ~5 minuter på svar vid push eller publicering.
4. Aldrig gissa – kör aldrig kritisk åtgärd "för det troligtvis är OK".

Godkänd formulering: `ja`, `ok`, `kör det`, `pusha`, `publicera <slug>`.

Bätcha godkännanden: "Jag har gjort X, Y, Z. Behöver pusha – godkänn?" hellre än att fråga efter varje steg.

---

## Projektspecifika regler

- **SSH-alias:** `tha` = Hetzner (`46.62.206.47`)
- **Coolify API:** `~/.coolify-token` | `scripts/coolify-update.sh`
- **OpenClaw container:** `openclaw-w44cc84w8kog4og400008csg`
- **Synka till container:** `./scripts/openclaw-install-seo-agent.sh`
- **Commit-stil:** `feat:` / `fix:` / `docs:` + `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`
- **Publish-flöde:** draft → Slack → `publicera <slug>` → push GitHub → Netlify bygger
- **Secrets:** Aldrig i commitade filer – Coolify env eller serverfiler

---

## Relaterade filer

| Fil | Syfte |
|-----|-------|
| `docs/guides/CLAUDE-CLI-AUTONOMOUS-PROMPT.txt` | Kort prompt att klistra in som projektinstruktion |
| `CLAUDE.md` | Projektinstruktioner som Claude CLI läser automatiskt |
| `scripts/coolify-update.sh` | Deploya/restarta via Coolify API |
| `scripts/server-health.sh` | Serverhälsa utan sidoeffekter |
| `openclaw/agents/SEO-SITE-AGENT.md` | Agentinstruktioner för SEO-flödet |
| `scripts/openclaw-install-seo-agent.sh` | Synka filer till OpenClaw-container |
