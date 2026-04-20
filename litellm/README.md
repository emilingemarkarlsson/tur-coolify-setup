# LiteLLM Proxy

LiteLLM Proxy (LLM Gateway) – enhetligt API mot flera LLM-leverantörer, kostnadsspårning, rate limiting.  
Dokumentation: [LiteLLM – Getting Started](https://docs.litellm.ai/).

## Viktigt: `num_workers`

På denna server (4 GB RAM, 3 vCPU) ska **`--num_workers` vara 1** (inte 8).

- 8 workers + Prisma query-engines ger för många anslutningar mot Postgres → **"FATAL: sorry, too many clients already"**.
- LiteLLM kraschar då vid start → Coolify startar om → crash-loop och hög CPU utan att du kör något.

I compose-filen är det redan satt till `1`. Om du redigerar i Coolify, ändra bara:

```yaml
    command:
      - '--config'
      - /app/config.yaml
      - '--port'
      - '4000'
      - '--num_workers'
      - '1'   # inte 8
```

Efter ändring: **Redeploy** LiteLLM i Coolify.

## `litellm-config.yaml`

Compose bind-mountar `./litellm-config.yaml` → `/app/config.yaml`. I repot finns **`litellm-config.example.yaml`** som mall: kopiera till `litellm-config.yaml` (lokalt eller på servern), fyll i `model_list` så den matchar dina modeller i LiteLLM UI och provider-nycklar i Coolify.

**Stil / brand** ska inte gömmas i YAML — använd `docs/brand/CONTENT-STYLE-BUNDLE.md` + `product/templates/brand-voice-tur-hyperlist.json` i n8n/Open WebUI/OpenClaw som system prompt.

## Coolify

Compose-filen här är en referenskopia. Den faktiska deploymenten görs från Coolify; env-variabler (nycklar, lösenord) hanteras där. Om du vill synka tillbaka från Coolify till repot kan du använda `./scripts/sync-coolify-resources.sh`.
