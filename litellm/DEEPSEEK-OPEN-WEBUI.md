# DeepSeek i LiteLLM + Open WebUI

Så lägger du till DeepSeek i LiteLLM och använder det från Open WebUI.

## 1. API-nyckel

- Gå till [DeepSeek Platform](https://platform.deepseek.com/) och skapa en API-nyckel.
- Du behöver den i steg 2.

## 2. LiteLLM – miljövariabel (krävs även för UI)

I **Coolify** → LiteLLM-resursen → **Environment**:

Lägg till:

```env
DEEPSEEK_API_KEY=sk-...din-nyckel...
```

Spara och **Redeploy** LiteLLM en gång så att variabeln laddas. Därefter kan du lägga till modellen i UI utan fler omstarter.

## 3. LiteLLM – lägg till DeepSeek i **UI** (rekommenderat)

1. Öppna **`https://<din-litellm-domän>/ui`** (samma domän som LiteLLM-proxyn, med `/ui`).
2. Logga in med **UI_USERNAME** och **UI_PASSWORD** (samma som i Coolify env).
3. Gå till **Model Management** / **Add model**.
4. Lägg till modell: **Model name** t.ex. `deepseek-chat`, **Model** `deepseek/deepseek-chat`, **API key** `os.environ/DEEPSEEK_API_KEY`. Spara.
5. Lägg gärna till `deepseek-reasoner` också: Model name `deepseek-reasoner`, Model `deepseek/deepseek-reasoner`, API key `os.environ/DEEPSEEK_API_KEY`.

Modellerna är aktiva direkt utan omstart. Källa: [LiteLLM UI](https://docs.litellm.ai/docs/proxy/ui), [Model Management](https://docs.litellm.ai/docs/proxy/model_management).

---

### Alternativ: via config-fil (model_list)

Config-filen ligger på servern i Coolify-service-mappen, t.ex.:

`/data/coolify/services/<litellm-service-id>/litellm-config.yaml`

**Alternativ A – redigera på servern**

```bash
ssh tha
# Hitta rätt mapp (id kan variera)
ls /data/coolify/services/ | grep -i litellm  # eller list-coolify-resources för att se ID
cd /data/coolify/services/<litellm-service-id>
nano litellm-config.yaml
```

**Alternativ B – i Coolify:** om du har “Edit Compose” / filredigering för config, redigera där.

Lägg till **DeepSeek** i `model_list` (samma struktur som dina andra modeller). Exempel:

```yaml
model_list:
  # ... dina befintliga modeller (gpt-4, claude, voyage, etc.) ...
  - model_name: deepseek-chat
    litellm_params:
      model: deepseek/deepseek-chat
      api_key: os.environ/DEEPSEEK_API_KEY
  - model_name: deepseek-reasoner
    litellm_params:
      model: deepseek/deepseek-reasoner
      api_key: os.environ/DEEPSEEK_API_KEY
```

- **`model_name`** = namnet som Open WebUI (och andra klienter) väljer i listan, t.ex. `deepseek-chat`.
- **`model`** = LiteLLM-modell-ID: `deepseek/deepseek-chat` eller `deepseek/deepseek-reasoner` (reasoning/“thinking”-modell).

Spara filen och **Redeploy** LiteLLM i Coolify så att den laddar nya config.

## 4. Open WebUI – anslut till LiteLLM och välj DeepSeek

1. Öppna Open WebUI (din domän för open-webui).
2. Gå till **Settings** (kugghjulet) → **Connections** / **API Keys** (eller **Admin** → **Settings** → **External API**).
3. Lägg till en **OpenAI-kompatibel** anslutning:
   - **API URL:** din LiteLLM-proxy-URL, t.ex. `https://<litellm-domän>/v1` (port 4000 bakom Traefik, så samma domän som du använt för LiteLLM).
   - **API Key:** LiteLLM **master key** (samma som `LITELLM_MASTER_KEY` i Coolify), t.ex. `sk-1234` eller vad du satt.
4. Spara. Open WebUI ska då lista modeller från LiteLLM.
5. Skapa en ny chatt eller välj modell: välj **deepseek-chat** eller **deepseek-reasoner** (så som du döpte dem i `model_name`).

Om modellerna inte syns: kontrollera att LiteLLM har startat om efter config-ändring och att Open WebUI använder rätt API URL (LiteLLM) och master key.

## Referens – modeller DeepSeek

| model_name (i config) | Användning |
|------------------------|------------|
| `deepseek-chat`        | Allmän chat (`deepseek/deepseek-chat`) |
| `deepseek-reasoner`    | Reasoning/thinking-modell |
| `deepseek-coder`       | Kod (om du vill lägga till) |

Källa: [LiteLLM – DeepSeek](https://docs.litellm.ai/docs/providers/deepseek).
