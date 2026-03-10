# Så att "publicera {slug}" fungerar från Slack

För att agenten ska **köra publiceringsscriptet** när du skriver "publicera {slug}" i Slack (och inte svara med "jq is required") behöver du göra detta **en gång**:

---

## Steg 1: Kör install-scriptet

Detta kopierar den senaste **publish-draft.sh** (utan jq), uppdaterade agentfiler och workspace till OpenClaw-containern.

```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/openclaw-install-seo-agent.sh
```

---

## Steg 2: Uppdatera agentens Instructions i OpenClaw

Agenten måste ha en tydlig regel att **alltid köra scriptet** vid "publicera {slug}". Det finns nu i filen **openclaw/agents/OPENCLAW-INSTRUCTIONS-SHORT.txt**.

1. Öppna **Coolify** → ditt **OpenClaw-projekt** → **Agents** (eller motsvarande) → den agent som svarar i Slack (t.ex. SEO / tur-openclaw).
2. Hitta fältet **Instructions**, **System prompt** eller **Agent instructions**.
3. Öppna i repot filen **openclaw/agents/OPENCLAW-INSTRUCTIONS-SHORT.txt** och **klistra in hela innehållet** i Instructions-fältet (ersätt det gamla om du vill att detta ska gälla).
4. Spara.

Då får agenten bland annat denna regel högst upp:

- *När användaren skriver "publicera {slug}" eller "publish {slug}" ska du alltid köra: /data/.openclaw/scripts/publish-draft.sh {slug}. Scriptet kräver inte jq.*

---

## Steg 3: Kontrollera GITHUB_TOKEN

För att scriptet ska kunna pusha behöver **GITHUB_TOKEN** vara satt i Coolify (Environment Variables för OpenClaw) eller som fil `/data/.openclaw/github-token` i containern. Se **openclaw/GIT-SETUP.md**.

---

## Steg 4: Kontrollera att agenten kan köra kommandon (Tools)

Om agenten svarar med "jq is required" eller "I cannot run the script" **utan att ha kört scriptet**, har den ofta inte tillgång till **exec** (kommandokörning).

1. I OpenClaw Dashboard: **Agents** → **main** → fliken **Tools**.
2. Kontrollera att ett verktyg för att köra kommandon är **aktiverat** (t.ex. **exec**, **run_command**, **bash** eller liknande). Aktivera det om det är av.
3. Spara och testa igen med `@tur-openclaw publicera n8n-data-pipeline-tutorial`.

Utan exec kan agenten inte köra `publish-draft.sh` och gissar då felaktigt att "jq is required".

---

## Felsökning: Netlify build – "publishDate: Invalid date"

Om Netlify-felet säger att blogginlägget inte matchar collection schema och **publishDate: Invalid date**:

1. Öppna **sajtens repo** (t.ex. emilingemarkarlsson-astro-theme) → `src/content/blog/<slug>.md`.
2. I frontmatter: byt **`pubDate`** till **`publishDate`** om det står pubDate.
3. Säkerställ att datumet är ett **giltigt ISO 8601-sträng**, t.ex. `publishDate: 2026-02-23` eller `publishDate: 2026-02-23T12:00:00.000Z`. Rätt format: `ÅÅÅÅ-MM-DD` eller full ISO med tid.
4. Spara, commit och push – Netlify bygger om.

Framtida artiklar: agenten är instruerad (plan + playbook) att använda `publishDate` för emilingemarkarlsson. Kör install-scriptet så att uppdaterade filer ligger i containern.

---

## Testa

I Slack (#all-tur-ab):

```text
@tur-openclaw publicera n8n-data-pipeline-tutorial
```

(Ersätt slug med det som stod i agentens meddelande efter draft.) Agenten ska köra scriptet och rapportera antingen "Published: https://..." eller ett konkret felmeddelande från scriptet.
