# Undersökning: CPU-last 22 jan – 17+ feb

## Resultat från genomförd undersökning (2026-02-XX)

### Vad som hittades på servern

| Källa | Resultat |
|-------|----------|
| **Reboot** | Senaste reboot: **4 feb 2026 06:39** – sedan dess har servern kört (inga fler reboots). |
| **Apt (paketuppdateringar)** | Uppgraderingar körda: **5 feb**, **8 feb**, **14 feb**, **15 feb**, **16 feb**, **21 feb** – alla runt 06:xx. Tydligt **schemalagt** (troligen unattended-upgrades eller cron). |
| **Docker** | Docker startade **4 feb 06:39** (efter reboot). **16 feb** och **19 feb**: många containers stoppades (“restart canceled”, “hasBeenManuallyStopped=true”) – troligen manuell stopp eller omstart av Docker/Coolify. |
| **CPU idag** | **LiteLLM** använder **~271 % CPU** och ~2 GB RAM – tydligt den tyngsta containern. Övriga (n8n, open-webui, qdrant, minio, umami, coolify) ligger på 0–3 %. |
| **OOM/kraschar** | Inga OOM-kills i loggen. “kill”-träffar var SSH-brute-force (“Invalid user killer”) och Docker “Could not send KILL signal” vid containerstopp. **Docker Hub rate limit** (“toomanyrequests”) vid image-pulls runt midnatt 15–21 feb. |
| **Git (lokalt)** | Inga commits i intervallet jan–feb 2026. |

### Tolkning mot dina tre faser

- **Fas 1 (22 jan – 5 feb)**  
  Låg last – normalt. Inget särskilt i loggarna i detta intervall (före reboot 4 feb).

- **Fas 2 (6 feb – 16 feb)**  
  - **4 feb 06:39**: Reboot → Docker startar → alla containers startar. LiteLLM (och ev. open-webui/n8n) kan ha legat på hög CPU under längre tid efter omstart.  
  - **5, 8, 14, 15, 16 feb** (~06:xx): Schemalagda apt-uppgraderingar. Varje körning kan trigga omstart av tjänster eller Docker, vilket håller lasten uppe.  
  - **LiteLLM** är idag tydligt CPU-tung (271 %) – om den körde liknande då förklarar den både konstant hög last och att den dominerar total CPU.

- **Fas 3 (17 feb →)**  
  - **16 feb** (och **19 feb**): Många containers stoppades (“restart canceled”). Efter det färre tjänster igång → **lägre baslast**.  
  - **Spikes 250–300 %**: Passar med att **LiteLLM** fortfarande kör och vid aktivitet drar nästan alla vCPU (som vid mätningen 271 %). Eventuella apt-körningar (t.ex. 21 feb) eller korta omstarter ger ytterligare korta toppar.

### Rekommendationer (konkreta)

1. **Begränsa LiteLLM**  
   Sätt CPU-limit på LiteLLM-containern (t.ex. 1–1,5 vCPU) så att den inte kan belasta alla 3 vCPU. Görs i Coolify (Edit Compose → deploy.resources.limits) eller i docker-compose under den resursen.

2. **Schemalagda apt-körningar**  
   Kontrollera cron/unattended-upgrades:  
   `ssh tha 'grep -r "" /etc/cron.d /etc/cron.daily /var/spool/cron 2>/dev/null; cat /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null'`  
   Överväg att köra uppgraderingar mindre ofta eller på en tid då lasten är lägre, så att inte varje körning ger långvarig hög last.

3. **Docker Hub rate limit**  
   “toomanyrequests” vid pull runt midnatt – om du kör många pull (t.ex. scheduled “docker pull” eller Coolify image refresh) kan det hjälpa att minska frekvensen eller använda image cache.

4. **SSH brute-force**  
   “Invalid user killer/bloom/room/hooman” – överväg fail2ban eller begränsa SSH till nycklar för att minska bråk.

---

## Dina tre faser (sammanfattning)

| Fas | Period | Last | Tolkning |
|-----|--------|------|----------|
| **1** | 22 jan – 5 feb | ~5–20% | Normal, låg belastning |
| **2** | 6 feb – 16 feb | 150–300% (konstant) | Alla 3 vCPU nästan fullt utnyttjade |
| **3** | 17 feb → | Nästan 0% + korta spikes 250–300% | Låg bas, tillfälliga toppar |

---

## Troliga orsaker (hypoteser)

### Fas 2: Varför konstant hög last 6–16 feb?

- **Systemuppdatering / omstart**
  - `update-server.sh` kör `apt upgrade -y` och `systemctl restart docker` → alla containers startar om. Efter det kan **alla tjänster samtidigt** göra init/indexering/compilation i några timmar–dagar.
  - Om någon körde uppdatering runt **6 feb** kan det förklara att lasten **går upp** från och med då.

- **Coolify/containers omstart**
  - `restart-coolify.sh` eller manuell `docker compose up -d` i `/data/coolify/source` + proxy + alla services ger samma effekt: många tjänster startar samtidigt och kan vara CPU-tunga en tid.

- **CPU-tunga tjänster (kontinuerlig last)**
  - **open-webui** (LLM-inference om den kör modeller lokalt)
  - **LiteLLM** (`litellm-zc8s8sg4kks4ccc04sg4ks0o`) – proxy/inference
  - **n8n** – tungt om många workflows körs ofta eller felaktiga loopar
  - **Qdrant** – vektor-DB, kan vara CPU-intensiv vid indexering/sökning
  - **Umami** – normalt lätt, men kan spike vid stor trafik/aggregation

- **Loop / felkonfiguration**
  - Ett workflow i n8n, en ständigt körande jobb eller en tjänst som ständigt försöker ansluta/omstart kan ge konstant hög CPU.

### Fas 3: Varför nästan noll sedan 17 feb, med korta spikes?

- **Tjänster stoppade eller omkonfigurerade**
  - Om tung arbetsbelastning (t.ex. open-webui/LiteLLM eller många n8n-körningar) stängts av eller minskats **runt 17 feb** → baslasten sjunker.

- **Containers omstartade igen**
  - Ny omstart (t.ex. `restart-coolify.sh`, `update-server.sh`, eller manuell restart) **runt 17 feb** kan ge:
    - Kortvarig hög last under omstart (spikes 250–300%).
    - Därefter lägre bas om färre tjänster eller lättare konfiguration körs.

- **Spikes**
  - Spikes 250–300% passar med: deploy/restart, batch-körning (n8n), inference (open-webui/LiteLLM), eller backup/indexering.

---

## Kommandon att köra på servern (spår efter vad som hände)

Kör dessa via `ssh tha` (eller `./scripts/quick-ssh.sh` och sedan SSH) för att koppla faserna till händelser.

### 1. När kördes systemuppdateringar? (apt)

```bash
# Senaste apt-uppgraderingar (datum)
grep -h "Start-Date:\|End-Date:" /var/log/apt/history.log* 2>/dev/null | tail -80
```

Om du ser **End-Date** runt **6 feb** och igen runt **17 feb** stödjer det att uppdateringar/omstarter ligger i tid med fas 2 och 3.

### 2. När startades Docker om?

```bash
# Docker-tjänsten start/restart
journalctl -u docker --since "2026-01-20" --until "2026-02-25" --no-pager | grep -E "Starting|Started|Stopping|Stopped"
```

### 3. När startades om systemet (reboot)?

```bash
# Reboots
last reboot --since 2026-01-20
# eller
journalctl --list-boots --no-pager | tail -20
```

### 4. Vilka processer/containers använder CPU idag?

```bash
# Topp 10 containers efter CPU (live)
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

Bra att köra både när lasten är **låg** och under en **spike** (jämför vilken container som sticker ut).

### 5. Kort historik från systemloggar (kraschar/OOM)

```bash
# OOM, kraschar, hårdvarufel
journalctl --since "2026-02-01" --until "2026-02-20" --no-pager | grep -iE "oom|kill|out of memory|segfault" | tail -30
```

### 6. Coolify/egen aktivitet (om du loggar kommandon)

Om du körde script från repot kan du kolla (lokal maskin):

```bash
# Lokalt: git-historik (om du committat efter körningar)
git log --oneline --since="2026-01-01" --until="2026-02-25"
```

---

## Rekommendationer

1. **Kör kommandona ovan** och spara output (särskilt apt history och Docker journal runt 6 feb och 17 feb).
2. **Jämför datum** mellan:
   - Dina tre faser (22 jan, 6 feb, 17 feb)
   - `apt` End-Date, `journalctl -u docker` start/restart, och `last reboot`.
3. **Identifiera CPU-tunga tjänster nu**: kör `docker stats --no-stream` vid låg last och under en spike så du ser vilken container som drar.
4. **Om du vill minska risk för långvarig hög last**:
   - Schemalägg inte `update-server.sh` / `restart-coolify.sh` samtidigt som tung användning (t.ex. n8n batch eller open-webui).
   - Överväg resursgränser för tunga containers (t.ex. `deploy.resources.limits.cpus` i docker-compose) så att en tjänst inte kan belasta alla 3 vCPU konstant.

---

## Snabbreferens: Script som påverkar last

| Script | Effekt |
|--------|--------|
| `update-server.sh` | `apt upgrade`, `systemctl restart docker`, startar om Coolify + services → kortvarig hög CPU, kan följas av längre period av hög last om många tjänster initierar |
| `restart-coolify.sh` | Samma Docker-omstart + omstart av alla Coolify-services |
| `fix-coolify-platform.sh` | Uppdaterar Docker/Coolify/Traefik och startar om allt |
| `fix-services.sh` | Startar om stoppade services → kan ge CPU-toppar när de väcker |

Om du vill kan nästa steg vara att lägga till ett litet script som sparar `docker stats` och `uptime` med tidsstämpel varje timme, så du har historik till nästa gång.
