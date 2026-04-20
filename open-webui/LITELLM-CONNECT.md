# LiteLLM → Open WebUI: få in modeller

## 1. Anslutning (Inställningar → Anslutningar)

- Klicka **➕ Add Connection** eller redigera **OpenAI API**.
- Fyll i:
  - **URL:** `https://<din-litellm-domän>/v1`  
    Produktion: `https://litellm.theunnamedroads.com/v1` (kräver att DNS för `litellm` pekar mot servern).
  - **API Key:** LiteLLM **master key** (samma som `LITELLM_MASTER_KEY` i LiteLLM).
  - **Provider Type:** **OpenAI** (inte Azure OpenAI).
  - **Modell-ID:n:** Lämna tomt först (auto-upptäckt). Om inga modeller dyker upp, lägg till manuellt (se nedan).
- Spara och se till att anslutningen är **på** (grön toggle).

## 2. Om inga modeller syns: lägg till manuellt

I samma anslutning, under **Modell-ID:n**:

- Klicka **Lägg till ett modell-ID**.
- Skriv exakt de modell-ID som finns i LiteLLM (t.ex. `deepseek-chat`, `gpt-4`, `claude-3-5-sonnet`).
- Lägg till ett ID i taget, spara.

Modellnamnen måste matcha det du konfigurerat i LiteLLM (UI eller config).

## 3. Kontrollera under Modeller

- Gå till **Inställningar → Modeller**.
- Kontrollera att anslutningen är tillåten / att modellerna från den anslutningen inte är dolda.

## 4. Testa

- **Ny chatt** → välj modell i listan → skicka ett meddelande.
- Fungerar det inte: kolla LiteLLM-loggar och att URL + API key är rätt (inga mellanslag, korrekt `/v1`).

## Felsökning

- **401/403:** Fel API-nyckel. Använd LiteLLM master key.
- **Connection error / timeout:** Open WebUI-containern når inte URL:en. Testa med **public URL** (t.ex. sslip.io eller din domän) så att både Traefik och DNS är med.
- **Modelllistan tom:** Använd manuell **Modell-ID**-lista (steg 2).
