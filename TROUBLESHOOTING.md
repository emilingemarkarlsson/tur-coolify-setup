# 🔧 Troubleshooting - Services inte tillgängliga

## Verifiera Versioner enligt Coolify's Officiella Dokumentation

**Kontrollera att allt är kompatibelt:**
```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/verify-and-fix-versions.sh
```

Detta script:
- ✅ Verifierar Ubuntu 22.04.5 LTS
- ✅ Verifierar Docker 29.1.3
- ✅ Uppgraderar Traefik till v3.6.1 (Coolify's rekommendation för Docker 29.x)
- ✅ Verifierar kompatibilitet enligt officiell dokumentation

## Komplett fix efter Ubuntu-uppdatering

**Om inget fungerar efter Ubuntu-uppdatering:**
```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/fix-coolify-platform.sh
```

**Om Traefik API-fel kvarstår (client version too old):**
```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/upgrade-traefik.sh
```

Detta uppdaterar Traefik till v3.6.1 enligt Coolify's officiella rekommendation.

Detta script:
- ✅ Uppdaterar Docker
- ✅ Uppdaterar Coolify till senaste version
- ✅ Fixar Traefik API-problem
- ✅ Startar om allt
- ✅ Verifierar att allt fungerar

## Systematisk felsökning

**För 404-fel efter serveromstart - diagnostisera först:**
```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/diagnose-404.sh
```

Detta script går igenom allt systematiskt:
- Server status efter omstart
- Docker status
- Coolify status
- Traefik proxy (kritiskt!)
- Docker networks
- Service containers
- Traefik labels
- DNS & endpoints
- Portar & connectivity

## Akut: Coolify når inte efter Traefik-uppdatering

**Om Traefik använder för gammal Docker API (client version too old):**
```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/upgrade-traefik.sh
```

Detta uppgraderar Traefik till v3.0 som stödjer Docker API 1.44+.

**Om Traefik-uppdatering gick fel och Coolify inte når:**
```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/fix-traefik-downgrade.sh
```

Detta återställer Traefik till v3.0.4 (fungerande version).

## Coolify Dashboard når inte (503 eller timeout)

**Om Coolify URL ger 503 Service Unavailable:**

```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/fix-coolify-503.sh
```

Detta fixar 503 genom att lägga till explicit Traefik-routing för Coolify (Coolify-containern saknar ofta Traefik labels). Verifierar direkt efteråt.

**Om services fungerar men Coolify dashboard inte når:**

1. **Konfigurera Domain i Coolify Dashboard:**
```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/configure-coolify-domain.sh
```

Detta visar:
- ✅ Hur du når Coolify via IP (port 8000)
- ✅ Steg-för-steg instruktioner för att konfigurera domänen
- ✅ Kontrollerar om domän redan är konfigurerad

2. **Om domain redan är konfigurerad men inte fungerar:**
```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/fix-coolify-dashboard.sh
```

Detta fixar:
- ✅ Ansluter Coolify till coolify network
- ✅ Kontrollerar Traefik labels på Coolify
- ✅ Startar om Coolify och Traefik
- ✅ Verifierar dashboard-åtkomst

## Snabb fix (1 kommando)

**404-fel eller "Not Available" (IP, DNS, Routing):**
```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/fix-routing.sh
```

Detta fixar:
- ✅ IP-adresser (kontrollerar att de är korrekta)
- ✅ DNS (verifierar att domäner pekar på rätt IP)
- ✅ Traefik routing (startar om och laddar om konfiguration)
- ✅ Services på network (säkerställer anslutning)
- ✅ Traefik labels (verifierar routing-konfiguration)

**Starta om allt (Coolify + Services):**
```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/restart-coolify.sh
```

**Services körs men ger 404-fel:**
```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/fix-404.sh
```

**Services körs inte alls:**
```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/fix-services.sh
```

Detta script:
- ✅ Kontrollerar Docker-status
- ✅ Identifierar stoppade services
- ✅ Kontrollerar Traefik-proxy
- ✅ Verifierar Docker networks
- ✅ Startar om stoppade services
- ✅ Verifierar att allt fungerar

---

## Vanliga orsaker efter serveruppdatering

### 1. Docker-containers stoppade
**Symptom:** Services visar "not available"

**Lösning:**
```bash
./scripts/fix-services.sh
```

### 2. Traefik-proxy körs inte
**Symptom:** Services når inte via HTTPS

**Lösning:**
```bash
ssh tha
docker ps | grep traefik
# Om stoppad:
docker start coolify-proxy
# Eller:
cd /data/coolify/proxy && docker compose up -d
```

### 3. Docker network saknas
**Symptom:** Containers kan inte kommunicera

**Lösning:**
```bash
ssh tha
docker network ls | grep coolify
# Om saknas, starta om Coolify:
cd /data/coolify/source && docker compose up -d
```

### 4. Services behöver omstart
**Symptom:** Services startade men når inte

**Lösning:**
```bash
ssh tha
cd /data/coolify/services/<service-id>
docker compose restart
```

---

## Manuell felsökning

### Steg 1: Kontrollera container-status

```bash
ssh tha 'docker ps -a'
```

**Titta efter:**
- Containers med status "Exited" → behöver startas
- Containers med status "Restarting" → problem med konfiguration

### Steg 2: Kontrollera Traefik

```bash
ssh tha 'docker ps | grep traefik'
```

**Om Traefik inte körs:**
```bash
ssh tha 'docker start coolify-proxy'
# Eller
ssh tha 'cd /data/coolify/proxy && docker compose up -d'
```

### Steg 3: Kontrollera logs

```bash
# Traefik logs
ssh tha 'docker logs coolify-proxy --tail 50'

# Service logs
ssh tha 'docker logs <container-name> --tail 50'
```

### Steg 4: Starta om specifik service

```bash
ssh tha
cd /data/coolify/services/<service-id>
docker compose restart
```

---

## Specifika problem

### Problem: "Service not available" efter uppdatering

**Orsak:** Containers stoppades under uppdateringen

**Fix:**
```bash
./scripts/fix-services.sh
```

### Problem: Services körs men ger 404-fel

**Orsak:** Traefik-proxy kan inte routa trafik till services

**Fix:**
```bash
./scripts/fix-404.sh
```

Detta fixar:
- Traefik-proxy status
- Docker network connectivity
- Traefik labels på services
- Routing-konfiguration

### Problem: Traefik visar 404

**Orsak:** Traefik-proxy körs inte eller har fel konfiguration

**Fix:**
```bash
ssh tha
cd /data/coolify/proxy
docker compose down
docker compose up -d
```

### Problem: Services startar men når inte via domän

**Orsak:** DNS eller Traefik routing-problem

**Fix:**
1. Kontrollera DNS: `nslookup <domain>`
2. Kontrollera Traefik logs: `ssh tha 'docker logs coolify-proxy'`
3. Verifiera Traefik labels i docker-compose.yml

### Problem: "Connection refused"

**Orsak:** Service lyssnar inte på rätt port eller network

**Fix:**
1. Kontrollera service logs
2. Verifiera port-konfiguration i docker-compose.yml
3. Kontrollera att service är på `coolify` network

---

## Verifiera efter fix

Efter att ha fixat problem, verifiera:

```bash
# Komplett verifiering
./scripts/verify-all.sh

# Lista alla resurser
./scripts/list-coolify-resources.sh

# Testa externa endpoints
./scripts/diagnose.sh
```

---

## Ytterligare hjälp

- **Coolify Dashboard:** https://coolify.theunnamedroads.com
- **Emergency Recovery:** `docs/guides/EMERGENCY-RECOVERY.md`
- **Lista resurser:** `./scripts/list-coolify-resources.sh`

