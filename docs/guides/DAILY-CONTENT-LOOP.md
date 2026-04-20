# Daglig content-loop — data → brief → generation med din stil

Målet: varje arbetsdag finns **färsk signal**, en **brief** per sajt (eller pool), och alla LLM-anrop bär **samma stil** (HyperList + brand).

## Ordning (översikt)

1. **07:00** — Signal-monitor (n8n): HN + Reddit + RSS → score via LiteLLM → `daily-signals-{site}.json` i MinIO (se [`CMO-SYSTEM-DESIGN.md`](../brand/CMO-SYSTEM-DESIGN.md)).
2. **07:30** — CMO / manuell brief: läs signals + Umami + `editorial-memory.json` → skriv `cmo-briefs/brief-{site}-{date}.json`.
3. **08:00+** — Artikel-generatorer: första steget HTTP GET brief från MinIO; **system prompt** = [`CONTENT-STYLE-BUNDLE.md`](../brand/CONTENT-STYLE-BUNDLE.md) + [`brand-voice-tur-hyperlist.json`](../../product/templates/brand-voice-tur-hyperlist.json) (inline eller fetch).
4. **Critic** — andra LiteLLM-anrop med samma brand bundle + “score JSON dimensions” (se CMO-design).
5. **Publicering** — OpenClaw eller befintlig publish-kedja; Telegram Publishes enligt [`TELEGRAM-NOTIFICATION-ARCHITECTURE.md`](./TELEGRAM-NOTIFICATION-ARCHITECTURE.md).

## Var stilen bor (single source of truth)

| Fil | Syfte |
|-----|--------|
| [`docs/brand/HYPERLIST-VOICE.md`](../brand/HYPERLIST-VOICE.md) | Tänk-sätt från HyperLists (AND/OR, villkor) |
| [`docs/brand/BRAND-VOICE-TUR.md`](../brand/BRAND-VOICE-TUR.md) | Persona per sajt, anti-patterns |
| [`docs/brand/CONTENT-STYLE-BUNDLE.md`](../brand/CONTENT-STYLE-BUNDLE.md) | Kort/lång `system`-text att klistra in |
| [`product/templates/brand-voice-tur-hyperlist.json`](../../product/templates/brand-voice-tur-hyperlist.json) | JSON för MinIO + HTTP-fetch i n8n |

## LiteLLM

- Proxy-config: [`litellm/litellm-config.example.yaml`](../../litellm/litellm-config.example.yaml) — kopiera till `litellm-config.yaml` på servern; modellnamn måste matcha det du anropar från n8n/Open WebUI.
- **Stil** styrs av klienten (system prompt), inte av själva proxy-taggen — undvik att hårdkoda långa prompts i YAML; använd brand-bundle ovan.

## Drift

- Daglig LiteLLM-usage-påminnelse: [`LITELLM-DAILY-SPEND-SLACK.md`](./LITELLM-DAILY-SPEND-SLACK.md).
- SEO/OpenClaw: [`SEO-OPENCLAW-AUTOMATION.md`](./SEO-OPENCLAW-AUTOMATION.md).
