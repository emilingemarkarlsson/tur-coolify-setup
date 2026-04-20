# HyperList-inspirerad kommunikation — TUR / nischer

Källa: *OnePageBook HyperLists* (Geir Isene / Å-Circle) — strukturera tankar som **träd**, **villkor**, **AND/OR**, utan onödig prosa.

Detta dokument är **inte** en kravlista att publicera HyperList-syntax på sajterna. Det är ett **tänk- och skrivlager** så att allt innehåll som går via LiteLLM/n8n/OpenClaw får **din** röst: tydlig, hierarkisk, bevisbar.

---

## Kärnprinciper (översatt till content)

| HyperList-idé | Hur det blir text |
|---------------|-------------------|
| **En sak per rad (Item)** | En huvudtanke per stycke; inga kedjor av “förresten”. |
| **Indrag = djup** | H2/H3 följer logik: claim → stöd → undantag. |
| **`[villkor]`** | Skriv ut *när* påståendet gäller: säsongsintervall, stack, målgrupp. |
| **`[? valfritt]`** | Ta bara med sidospår om de ändrar slutsatsen; annars ut. |
| **AND:** | Alla underpunkter måste stå för att slutsatsen ska hålla. |
| **OR:** | Ge alternativ tydligt — inte “man kan göra si eller så” i en dimma. |
| **Referenser `<...>`** | Intern länk eller källa dit läsaren hoppar; inga tomma “läs mer”. |
| **Operatorer (VERSALER:)** | Rubriker som *gör något*: bevis, undantag, nästa steg — inte “Bakgrund”. |

---

## Förbjudet (motsvarar HyperList-motstånd: ostrukturerad fluff)

- Inledningar som inte är första steget i trädet (“I en tid där…”, “AI revolutionerar…”).
- Stycke utan **ett** klart påstående i första meningen.
- “Slutsats” som upprepar ingress — HyperList slutar på **implikation eller nästa handling**, inte sammanfattning.
- Lista med adjektiv utan siffror eller observation.

---

## Mall: artikel som logiskt träd (meta för LLM)

Använd internt i briefs och system prompts (inte nödvändigtvis som publicerad rubrikstruktur):

```text
**H1:** [Konkret claim eller mätbart påstående]

**AND:**
  Första beviset (data, observation, replikerbart steg)
  [? undantag] Om undantaget ändrar slutsatsen — annars hoppa över

**OR:** (om läsaren kan välja väg)
  Alternativ A: när X
  Alternativ B: när Y

**IMPLIKATION:** Vad följer — en mening, inte en recap.
```

---

## Koppling till befintlig brand voice

- [`BRAND-VOICE-TUR.md`](BRAND-VOICE-TUR.md) — persona per sajt, anti-patterns, SEO utan att förstöra rösten.
- [`CMO-SYSTEM-DESIGN.md`](CMO-SYSTEM-DESIGN.md) — `brand-voice/eik.json`; lägg HyperList som `structural_mode: "hyperlist-inspired"` i utökade JSON-mallar under `product/templates/`.

---

## Var detta ska injiceras

1. **LiteLLM-anrop från n8n** — prependa `system`-meddelande med utdrag från [`product/templates/brand-voice-tur-hyperlist.json`](../../product/templates/brand-voice-tur-hyperlist.json) (MinIO eller inline).
2. **OpenClaw SEO-agent** — se [`SEO-SITE-AGENT.md`](../../openclaw/agents/SEO-SITE-AGENT.md): brief + artikel ska följa trädlogiken.
3. **Open WebUI** — spara en “System”-preset som klistrar in innehåll från [`CONTENT-STYLE-BUNDLE.md`](./CONTENT-STYLE-BUNDLE.md).

Valfritt nästa steg: ladda upp `brand-voice-tur-hyperlist.json` till MinIO `brand-voice/` och hämta med HTTP i workflows (samma mönster som `eik.json` i CMO-designen).
