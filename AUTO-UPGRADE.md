# 🤖 Automatiserad Uppgraderingsprocess

## Översikt

Detta projekt inkluderar en komplett automatiserad uppgraderingsprocess som:
- ✅ Analyserar nuvarande miljö
- ✅ Uppgraderar Ubuntu-servern
- ✅ Uppdaterar Docker
- ✅ Uppdaterar Coolify
- ✅ Synkar resurser från Coolify
- ✅ Skapar/uppdaterar dokumentation
- ✅ Verifierar allt

## Snabbstart

**Komplett automatiserad uppgradering:**
```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/auto-upgrade-all.sh
```

Detta är allt du behöver! Scriptet hanterar hela processen automatiskt.

---

## Vad Scriptet Gör

### Steg 1: Analysera Nuvarande Miljö
- Kontrollerar Ubuntu-version
- Kontrollerar Docker-version
- Kontrollerar Coolify-version
- Kontrollerar Traefik-version
- Identifierar kompatibilitetsproblem

### Steg 2: Uppgradera Ubuntu Server
- Säkerhetskopierar data
- Uppdaterar systempaket
- Startar om Docker, Coolify och services
- Verifierar att allt fungerar

### Steg 3: Verifiera & Uppdatera Docker
- Kontrollerar Docker-status
- Verifierar Docker API-kompatibilitet

### Steg 4: Uppdatera Coolify
- Kontrollerar Coolify-version
- Ger instruktioner för uppdatering

### Steg 5: Verifiera & Uppdatera Traefik
- Kontrollerar Traefik-kompatibilitet med Docker 29.x
- Rekommenderar uppgradering om nödvändigt

### Steg 6: Synka Coolify Resurser & Skapa Dokumentation
- Identifierar alla aktiva services i Coolify
- Skapar/uppdaterar mappar för varje service
- Genererar UPGRADE.md för varje service
- Genererar README.md för varje service
- Uppdaterar SERVICES.md

### Steg 7: Uppdatera Services
- Analyserar services som behöver uppdateras
- Ger rekommendationer baserat på senaste versioner

### Steg 8: Verifiering
- Verifierar serverstatus
- Verifierar Docker-status
- Verifierar Coolify-status
- Verifierar externa endpoints

---

## Synka Resurser & Skapa Dokumentation

**Synka resurser från Coolify och skapa dokumentation:**

**Metod 1: Via filsystem (standard):**
```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/sync-coolify-resources.sh
```

**Metod 2: Lista projekt först (om standard inte fungerar):**
```bash
# Lista alla resurser i projektet
./scripts/list-coolify-project.sh tha theunnamedroads

# Synka resurser
./scripts/sync-coolify-resources.sh
```

**Metod 3: Via API (om tillgänglig):**
```bash
./scripts/sync-coolify-api.sh tha https://coolify.theunnamedroads.com
```

Detta script:
- ✅ Identifierar alla aktiva services i Coolify
- ✅ Skapar mappar för nya services
- ✅ Hämtar docker-compose.yml från Coolify
- ✅ Genererar UPGRADE.md med best practices
- ✅ Genererar README.md med service-info
- ✅ Uppdaterar SERVICES.md automatiskt

---

## Service-dokumentation

Varje aktiv service har nu:
- **UPGRADE.md** - Komplett uppdateringsguide med:
  - Nuvarande konfiguration
  - Steg-för-steg uppdateringsinstruktioner
  - Var man hittar senaste versioner
  - Breaking changes-varningar
  - Backup-instruktioner
  - Troubleshooting

- **README.md** - Service-översikt med:
  - Konfiguration
  - Snabbuppdatering
  - Länkar till dokumentation

---

## Best Practices

1. **Kör regelbundet:**
   ```bash
   # Månadsvis eller efter större ändringar
   ./scripts/auto-upgrade-all.sh
   ```

2. **Synka resurser efter ändringar i Coolify:**
   ```bash
   # Efter att ha lagt till/ändrat services i Coolify
   ./scripts/sync-coolify-resources.sh
   ```

3. **Kontrollera versioner innan uppdatering:**
   ```bash
   # Se vad som behöver uppdateras
   ./scripts/upgrade-check.sh
   ```

4. **Verifiera efter uppdatering:**
   ```bash
   # Kontrollera att allt fungerar
   ./scripts/verify-all.sh
   ```

---

## Workflow

### Regelbunden Underhåll

```bash
# 1. Kontrollera vad som behöver uppdateras
./scripts/upgrade-check.sh

# 2. Kör komplett uppgradering
./scripts/auto-upgrade-all.sh

# 3. Verifiera allt
./scripts/verify-all.sh
```

### Efter Ändringar i Coolify

```bash
# 1. Synka resurser och skapa dokumentation
./scripts/sync-coolify-resources.sh

# 2. Granska skapad dokumentation
# 3. Uppdatera services enligt UPGRADE.md
```

---

## Ytterligare Resurser

- **Uppgraderingsguide:** [UPGRADE.md](UPGRADE.md)
- **Services:** [SERVICES.md](SERVICES.md)
- **Troubleshooting:** [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Coolify Dashboard:** https://coolify.theunnamedroads.com

