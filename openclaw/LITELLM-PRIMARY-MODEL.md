# Primary Model i OpenClaw när du kör LiteLLM

OpenClaw skickar anrop till LiteLLM. Fältet **Primary model (default)** ska innehålla **exakt det modellnamn som LiteLLM exponerar** – samma sträng som du ser i LiteLLM UI eller i din `model_list`.

---

## Steg 1: Hitta modellnamnet i LiteLLM

**Alternativ A – LiteLLM UI (enklast)**

1. Öppna din LiteLLM-webbgränssnitt: **`https://<din-litellm-domän>/ui`**  
   (t.ex. `https://litellm.theunnamedroads.com/ui` eller den URL du använder för LiteLLM.)
2. Logga in om det krävs.
3. Gå till **Models** / **Model Management**.
4. Notera **modellens namn** – t.ex. `gpt-4o`, `deepseek-chat`, `claude-3-5-sonnet` eller `openai/gpt-4o`. Det är den strängen du ska använda.

**Alternativ B – API (lista alla modeller)**

Om du har LiteLLM master key och domän:

```bash
curl -s -H "Authorization: Bearer DIN_MASTER_KEY" "https://<din-litellm-domän>/v1/models" | jq '.data[].id'
```

Då får du en lista med modell-ID:n. Välj ett (t.ex. `gpt-4o` eller `deepseek-chat`) och använd det i OpenClaw.

**Alternativ C – Konfiguration på servern**

Om du redan vet vilka modeller som finns i din `litellm-config.yaml` (under `model_list`), använd **model**-värdet där. T.ex.:

```yaml
model_list:
  - model_id: gpt-4o
    litellm_params:
      model: openai/gpt-4o
```

Här kan du använda antingen `gpt-4o` (model_id) eller `openai/gpt-4o` (model) – beroende på vad LiteLLM faktiskt accepterar i `/v1/chat/completions`. Ofta är det **model_id** som gäller i API-anrop.

---

## Steg 2: Fyll i OpenClaw

1. Öppna **OpenClaw Control** → **Agents** → **main** → **Overview**.
2. I **Primary model (default)** skriver du **exakt** det modellnamn du hittade (ett ord, inga mellanslag), t.ex.:
   - `gpt-4o`
   - `deepseek-chat`
   - `claude-3-5-sonnet`
   - eller `openai/gpt-4o` om det är så LiteLLM listar det.
3. Klicka **Save**.

---

## Om OpenClaw pratar med LiteLLM

OpenClaw måste vara konfigurerad att använda LiteLLM som backend. I Coolify (OpenClaw-resursens env) ska du typ ha:

| Variabel | Värde |
|----------|--------|
| `OPENAI_API_BASE` | `https://<din-litellm-domän>/v1` |
| `OPENAI_API_KEY` | LiteLLM **master key** |

Då använder OpenClaw LiteLLM som om det vore OpenAI, och **Primary model** är det modell-ID som LiteLLM accepterar (samma som i UI eller `/v1/models`).

---

## Vanliga modellnamn (exempel)

| Om du använder | Prova i Primary model |
|----------------|------------------------|
| OpenAI via LiteLLM | `gpt-4o` eller `openai/gpt-4o` |
| Anthropic via LiteLLM | `claude-3-5-sonnet` eller `anthropic/claude-3-5-sonnet` |
| DeepSeek via LiteLLM | `deepseek-chat` eller `deepseek/deepseek-chat` |

Om något inte fungerar: dubbelkolla i LiteLLM UI vilka modeller som är aktiva och vilket **id** de har – det id:t är vad du skriver i OpenClaw.
