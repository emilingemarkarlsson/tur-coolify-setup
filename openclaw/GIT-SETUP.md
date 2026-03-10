# Git i OpenClaw – så att "publicera {slug}" pushar till GitHub

För att agenten ska kunna publicera när du skriver **publicera {slug}** i Slack behöver OpenClaw-containern **Git-åtkomst** till dina GitHub-repon. Enklast är att använda en **GitHub Personal Access Token (PAT)**.

---

## Steg 1: Skapa en GitHub Personal Access Token

1. Gå till **GitHub → Settings → Developer settings → Personal access tokens** ([direct link](https://github.com/settings/tokens)).
2. **Tokens (classic)** → **Generate new token (classic)**.
3. **Note:** t.ex. `OpenClaw SEO publish`.
4. **Expiration:** 90 days eller No expiration (du kan rotera senare).
5. **Scopes:** kryssa i **repo** (full control of private repositories). Det räcker för clone/push till dina repon.
6. **Generate token** – **kopiera tokenet** (du ser det bara en gång). Det ser ut ungefär som `ghp_xxxxxxxxxxxx`.

---

## Steg 2: Lägg token i OpenClaw-containern

Containern måste ha tillgång till tokenet. Två sätt:

### Alternativ A: Miljövariabel i Coolify (rekommenderat)

1. Öppna **Coolify** → ditt **OpenClaw-projekt** → **OpenClaw-tjänsten** (den container som kör OpenClaw).
2. Gå till **Environment Variables** / **Variabler**.
3. Lägg till:
   - **Name:** `GITHUB_TOKEN`
   - **Value:** `ghp_ditt_token_här` (klistra in tokenet från Steg 1).
4. Spara och **starta om** containern (eller redeploy) så att variabeln laddas.

### Alternativ B: Fil i containern (om du inte kan sätta env i Coolify)

Kör lokalt (ersätt `ghp_DITT_TOKEN` med ditt token):

```bash
CONTAINER=$(ssh tha 'docker ps --format "{{.Names}}" | grep -i openclaw | head -1')
ssh tha "docker exec $CONTAINER sh -c 'mkdir -p /data/.openclaw && echo ghp_DITT_TOKEN > /data/.openclaw/github-token && chmod 600 /data/.openclaw/github-token'"
```

**OBS:** Filen försvinner om containern skapas om (t.ex. vid redeploy). Då måste du köra kommandot igen eller använda Alternativ A.

---

## Steg 3: Säkerställ att publish-scriptet finns

När du kör **install** kopieras **openclaw/scripts/publish-draft.sh** till containern. Scriptet kräver **inte jq** (använder python3). Det använder `GITHUB_TOKEN` eller `/data/.openclaw/github-token` för att klona/pusha.

Kör (från repots rot):

```bash
./scripts/openclaw-install-seo-agent.sh
```

**Om agenten fortfarande säger "jq is required":** Scriptet i repot behöver jq inte. Antingen är containern inte uppdaterad, eller så kör agenten inte scriptet. Gör så här:
1. **Publicera artikeln nu (manuellt från din dator):**  
   `./scripts/openclaw-publish-now.sh n8n-data-pipeline-tutorial`  
   Det kopierar den senaste publish-draft.sh till containern och kör publiceringen. Kräver att `tha` och GITHUB_TOKEN är satt.
2. I OpenClaw (Coolify) → agent Instructions: lägg till en rad så här så att agenten alltid kör scriptet:  
   *"När användaren skriver 'publicera {slug}': kör alltid kommandot /data/.openclaw/scripts/publish-draft.sh {slug} och rapportera output. Scriptet kräver inte jq."*

---

## Steg 4: Testa Git-åtkomst (valfritt)

SSH till servern och kör:

```bash
CONTAINER=$(ssh tha 'docker ps --format "{{.Names}}" | grep -i openclaw | head -1')
ssh tha "docker exec $CONTAINER sh -c 'echo \$GITHUB_TOKEN | head -c 10'"
```

Om du ser början av token (t.ex. `ghp_xxxx`) är env satt. Om du använder fil istället:

```bash
ssh tha "docker exec $CONTAINER sh -c 'test -f /data/.openclaw/github-token && echo OK || echo MISSING'"
```

---

## Sammanfattning

| Steg | Vad |
|------|-----|
| 1 | Skapa GitHub PAT med scope **repo**, kopiera tokenet. |
| 2 | Sätt **GITHUB_TOKEN** i Coolify (env) eller skapa **/data/.openclaw/github-token** i containern. |
| 3 | Kör **./scripts/openclaw-install-seo-agent.sh** så att publish-draft.sh finns i containern. |
| 4 | När du skriver **publicera {slug}** i Slack anropar agenten scriptet som använder tokenet för push. |

**Säkerhet:** Dela aldrig tokenet i Slack eller i repo. Om tokenet läcker: återkalla det på GitHub och skapa ett nytt.
