# OpenClaw

AI-driven kodassistent med stöd för 20+ AI-leverantörer, inbyggd browser-automation och integration med Telegram, Discord, Slack, WhatsApp.

- **Coolify-dokumentation:** [OpenClaw | Coolify Docs](https://coolify.io/docs/services/openclaw)
- **HTTPS krävs** – sätt domän med SSL (Traefik hanterar det om du lägger till domän i Coolify).

## Installation via Coolify

1. **Lägg till tjänst**
   - I Coolify: **Projekt** → **+ New Resource** → **Service** (eller **Services** → bläddra till OpenClaw om det finns som one-click).
   - Välj **OpenClaw** från Coolify’s services-mall / dokumentationen.
   - Om OpenClaw inte finns i listan: använd **Docker Compose** och klistra in den compose som Coolify eller [OpenClaw GitHub](https://github.com/openclaw/openclaw) anger för Coolify.

2. **Domän och HTTPS**
   - Sätt **Domain** till t.ex. `openclaw.theunnamedroads.com` (eller annan subdomän).
   - Säkerställ att DNS A-record pekar på servern. Traefik tar då SSL automatiskt.
   - OpenClaw kräver HTTPS för att fungera korrekt.

3. **Miljövariabler**
   - **AUTH_USERNAME** / **AUTH_PASSWORD** – genereras ofta av Coolify. Om inte, sätt egna för HTTP Basic Auth.
   - **OPENCLAW_GATEWAY_TOKEN** – genereras av Coolify för API-åtkomst.
   - **Minst en AI-leverantör** (se nedan). Rekommendation: använd **LiteLLM** så att alla dina modeller (DeepSeek, GPT, Claude, etc.) finns tillgängliga.

## Anslut OpenClaw till LiteLLM (rekommenderat)

Då du redan kör LiteLLM kan OpenClaw använda den som “en” provider och få tillgång till alla modeller du lagt in där (t.ex. DeepSeek, GPT-4, Claude).

### Variant A – OpenAI-kompatibel (enklast i Coolify)

LiteLLM exponerar ett OpenAI-kompatibelt API. Sätt i OpenClaw-resursens **Environment Variables**:

| Key | Value |
|-----|--------|
| `OPENAI_API_KEY` | LiteLLM **master key** (samma som `LITELLM_MASTER_KEY` i LiteLLM) |
| `OPENAI_API_BASE` | `https://<din-litellm-domän>/v1` (t.ex. `https://litellm.theunnamedroads.com/v1`) |
| `OPENCLAW_PRIMARY_MODEL` | T.ex. `deepseek-chat` eller `deepseek-reasoner` (samma namn som i LiteLLM) |

Då använder OpenClaw LiteLLM som backend och du väljer modell via LiteLLM-modellnamn.

### Variant B – OpenClaw’s LiteLLM-provider

OpenClaw har inbyggt stöd för LiteLLM. Sätt:

| Key | Value |
|-----|--------|
| `LITELLM_API_KEY` | LiteLLM master key (eller en virtuell nyckel skapad i LiteLLM för OpenClaw) |
| (om tillgängligt) `LITELLM_BASE_URL` eller motsvarande | `https://<din-litellm-domän>` (utan `/v1`) |

Om base URL bara går att sätta i config-fil, använd Variant A ovan.

Källa: [OpenClaw – LiteLLM](https://docs.openclaw.ai/providers/litellm).

## Övriga AI-leverantörer (om du inte använder LiteLLM)

Minst en av dessa behövs om OpenClaw inte går via LiteLLM:

- **Anthropic** — `ANTHROPIC_API_KEY`
- **OpenAI** — `OPENAI_API_KEY`
- **Google Gemini** — `GEMINI_API_KEY`
- **OpenRouter** — `OPENROUTER_API_KEY`
- **Groq** — `GROQ_API_KEY`
- **Mistral** — `MISTRAL_API_KEY`
- **xAI** — `XAI_API_KEY`
- **Cerebras** — `CEREBRAS_API_KEY`
- **Ollama (lokal)** — `OLLAMA_BASE_URL`
- **Amazon Bedrock** — `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`

Vid proxy (t.ex. OpenRouter): använd full provider-path i modellnamn, t.ex. `OPENCLAW_PRIMARY_MODEL=openrouter/google/gemini-2.5-flash`.

## Browser

`/browser` i OpenClaw ger en fjärrstyrd browser (Chrome DevTools Protocol) – användbar för OAuth, 2FA, captcha m.m. Konfiguration (valfritt):

- `BROWSER_DEFAULT_PROFILE` — profilnamn (default: `openclaw`)
- `BROWSER_SNAPSHOT_MODE` — t.ex. `efficient`
- `BROWSER_EVALUATE_ENABLED` — `true`/`false`

## SEO-artiklar och flera sajter

OpenClaw kan köra en SEO-agent som ger artikel-förslag, skriver artiklar och publicerar till GitHub (Netlify/Vercel bygger då). Allt triggas från Slack (#all-tur-ab).

- **Översikt (vad körs, säkerhet, nästa sajt):** [openclaw/OPENCLAW-OVERBLICK.md](OPENCLAW-OVERBLICK.md)
- **Snabbkommandon i Slack:** [openclaw/SNABBKOMMANDON.md](SNABBKOMMANDON.md)
- **Full SEO-setup:** [openclaw/SETUP-SEO-OPENCLAW.md](SETUP-SEO-OPENCLAW.md)

## Snabbkontroll

- **Coolify:** [OpenClaw | Coolify Docs](https://coolify.io/docs/services/openclaw)
- **OpenClaw + LiteLLM:** [LiteLLM – OpenClaw](https://docs.openclaw.ai/providers/litellm)
- **OpenClaw GitHub:** [openclaw/openclaw](https://github.com/openclaw/openclaw)
