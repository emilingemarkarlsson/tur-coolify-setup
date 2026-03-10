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

## Coolify

Compose-filen här är en referenskopia. Den faktiska deploymenten görs från Coolify; env-variabler (nycklar, lösenord) hanteras där. Om du vill synka tillbaka från Coolify till repot kan du använda `./scripts/sync-coolify-resources.sh`.
