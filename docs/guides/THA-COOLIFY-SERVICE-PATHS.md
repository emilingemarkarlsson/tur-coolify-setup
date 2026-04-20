# Coolify på `tha` — service-sökvägar

Compose-filer som Coolify använder ligger under `/data/coolify/services/<uuid>/docker-compose.yml`.

Uppdateringar som görs **i detta repo** (`open-webui/docker-compose.yml`, `n8n/docker-compose.yml`) är referens — produktion kan ha extra `environment` (Coolify). Vid image-pinning: redigera **serverns** fil eller synka innehåll manuellt, sedan `docker compose pull && docker compose up -d` i katalogen.

| UUID | Namn (Coolify) | Viktigt |
|------|----------------|---------|
| `cckckggw44s8gkkkw008k4cs` | open-webui-tur | `webui.theunnamedroads.com` |
| `j88kgkks44cc8wcc4kc8wkkk` | n8n-tur | Postgres sidecar; `docker.n8n.io/n8nio/n8n` |
| `kkswc8gokk84c0o8oo84w44w` | litellm-tur | `litellm-config.yaml` i samma katalog |
| `w44cc84w8kog4og400008csg` | openclaw-tur | SEO-agent sync: `openclaw-install-seo-agent.sh` |

**2026-04-20:** På servern sattes `open-webui` → `ghcr.io/open-webui/open-webui:v0.8.12` och `n8n` → `docker.n8n.io/n8nio/n8n:2.16.1`, därefter `docker compose pull && up -d`.
