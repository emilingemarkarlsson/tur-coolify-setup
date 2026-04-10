# Step 4 — LiteLLM Setup

Estimated time: 10 minutes

LiteLLM is a proxy that sits between your workflows and LLM APIs. Every AI call goes through it — giving you unified cost tracking, model switching, rate limiting, and fallback routing.

---

## Deploy via Coolify

1. In Coolify, go to **Services** → **Add New Service**
2. Search for **LiteLLM** and select it
3. Set environment variables:

```
LITELLM_MASTER_KEY=sk-your-master-key-here
LITELLM_SALT_KEY=your-salt-key-here
DATABASE_URL=postgresql://user:password@postgres-host/litellm
```

4. Set your domain (e.g. `litellm.yourdomain.com`)
5. Click **Deploy**

---

## Configure models

Create a `config.yaml` file:

```yaml
model_list:
  - model_name: groq/llama-3.3-70b
    litellm_params:
      model: groq/llama-3.3-70b-versatile
      api_key: os.environ/GROQ_API_KEY

  - model_name: gemini/flash
    litellm_params:
      model: gemini/gemini-1.5-flash
      api_key: os.environ/GEMINI_API_KEY

  - model_name: anthropic/sonnet
    litellm_params:
      model: anthropic/claude-sonnet-4-6
      api_key: os.environ/ANTHROPIC_API_KEY

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
```

---

## Use in n8n workflows

In any HTTP Request node that calls an LLM, use:

```
URL: https://litellm.yourdomain.com/v1/chat/completions
Headers:
  Authorization: Bearer sk-your-master-key-here
  Content-Type: application/json
Body:
  {
    "model": "groq/llama-3.3-70b",
    "messages": [...]
  }
```

---

## Cost tracking

Open the LiteLLM dashboard at your domain to see:
- Spend per model
- Spend per day
- Request volume
- Error rates

This is how you know which sites and workflows are burning API budget.

---

## Next step

Proceed to [05-openclaw-setup.md](05-openclaw-setup.md)
