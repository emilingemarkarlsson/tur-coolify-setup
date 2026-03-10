# 🔄 Uppgraderingsguide - Systematisk Process

## Automatiserad Uppgradering (Rekommenderat)

**Komplett automatiserad uppgradering av allt:**
```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/auto-upgrade-all.sh
```

Detta script:
- ✅ Analyserar nuvarande miljö
- ✅ Uppgraderar Ubuntu-servern
- ✅ Uppdaterar Docker
- ✅ Uppdaterar Coolify
- ✅ Synkar resurser och skapar dokumentation
- ✅ Verifierar allt

---

## Snabbstart (Manuell)

**Kontrollera vad som behöver uppdateras:**
```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/upgrade-check.sh
```

Detta script kontrollerar:
- ✅ Systemversioner (Ubuntu, Docker, Coolify, Traefik)
- ✅ Kompatibilitet enligt officiell dokumentation
- ✅ Tillgängliga uppdateringar
- ✅ Ger rekommendationer för nästa steg

---

## Komplett Uppgraderingsprocess (Manuell)

### Steg 1: Kontrollera Status

```bash
./scripts/upgrade-check.sh
```

Detta visar:
- Nuvarande versioner
- Kompatibilitetsproblem
- Vad som behöver uppdateras

### Steg 2: Uppdatera Systempaket

Om systemuppdateringar behövs:

```bash
./scripts/update-server.sh
```

Detta:
- ✅ Säkerhetskopierar data
- ✅ Uppdaterar systempaket
- ✅ Startar om Docker, Coolify och services
- ✅ Verifierar att allt fungerar

### Steg 3: Uppgradera Traefik (om Docker 29.x)

Om Docker 29.x kräver Traefik v3.6.1+:

```bash
./scripts/upgrade-traefik.sh
```

Detta uppgraderar Traefik enligt Coolify's officiella rekommendation.

### Steg 4: Verifiera Versioner

Kontrollera att allt är kompatibelt:

```bash
./scripts/verify-and-fix-versions.sh
```

Detta:
- ✅ Verifierar Ubuntu 22.04.5 LTS
- ✅ Verifierar Docker 29.1.3
- ✅ Verifierar Traefik v3.6.1+
- ✅ Fixar kompatibilitetsproblem

### Steg 5: Verifiera Allt

Slutlig verifiering:

```bash
./scripts/verify-all.sh
```

Detta kontrollerar:
- ✅ Serverstatus
- ✅ Docker-status
- ✅ Coolify-status
- ✅ Externa endpoints
- ✅ Systemhälsa

---

## Specifika Uppgraderingar

### Ubuntu Systemuppdateringar

**När:** När systemet visar "System restart required" eller regelbundet (månadsvis)

**Process:**
```bash
./scripts/update-server.sh
```

**Efter omstart (om nödvändigt):**
```bash
ssh tha 'reboot'
# Vänta 2-3 minuter
./scripts/verify-all.sh
```

### Docker Uppgradering

**När:** När Docker visar uppdateringar eller kompatibilitetsproblem

**Process:**
1. Kontrollera senaste version: https://docs.docker.com/engine/release-notes/
2. Uppdatera via systempaket:
   ```bash
   ./scripts/update-server.sh
   ```

### Traefik Uppgradering

**När:** 
- Docker 29.x kräver Traefik v3.6.1+ eller v2.11.31+
- Coolify visar varning om Traefik-version

**Process:**
```bash
./scripts/upgrade-traefik.sh
```

**Enligt Coolify's officiella dokumentation:**
- Docker 29.x → Traefik v3.6.1+ (rekommenderat)
- Alternativ: Traefik v2.11.31+

### Coolify Uppgradering

**När:** När Coolify visar uppdateringar i dashboard

**Process:**
1. Öppna Coolify dashboard: https://coolify.theunnamedroads.com
2. Gå till: Settings → Update
3. Följ instruktionerna i dashboard

---

## Felsökning efter Uppgradering

### Om Services inte når efter uppdatering

```bash
./scripts/diagnose-404.sh
```

Detta diagnostiserar systematiskt:
- Serverstatus
- Docker-status
- Coolify-status
- Traefik routing
- Network-anslutningar
- Traefik labels

### Om Traefik API-fel (client version too old)

```bash
./scripts/upgrade-traefik.sh
```

Detta uppgraderar Traefik till v3.6.1 enligt officiell rekommendation.

### Om Coolify Dashboard inte når

```bash
./scripts/fix-coolify-dashboard.sh
```

Detta fixar:
- Network-anslutningar
- Traefik labels
- Routing-konfiguration

---

## Officiell Dokumentation

**Referens:**
- **Coolify:** https://coolify.io/docs
- **Traefik:** https://doc.traefik.io/traefik/
- **Docker:** https://docs.docker.com/
- **Ubuntu:** https://ubuntu.com/server/docs

**Specifika Guides:**
- Coolify Troubleshooting: https://coolify.io/docs/troubleshoot
- Traefik Docker Provider: https://doc.traefik.io/traefik/providers/docker/

---

## Checklista för Uppgradering

- [ ] Kör `./scripts/upgrade-check.sh` för att se vad som behöver uppdateras
- [ ] Säkerhetskopiera viktiga data (görs automatiskt av `update-server.sh`)
- [ ] Uppdatera systempaket: `./scripts/update-server.sh`
- [ ] Uppgradera Traefik (om Docker 29.x): `./scripts/upgrade-traefik.sh`
- [ ] Verifiera versioner: `./scripts/verify-and-fix-versions.sh`
- [ ] Verifiera allt: `./scripts/verify-all.sh`
- [ ] Testa alla services
- [ ] Testa Coolify dashboard

---

## Snabbkommandon

```bash
# Kontrollera vad som behöver uppdateras
./scripts/upgrade-check.sh

# Uppdatera allt
./scripts/update-server.sh

# Uppgradera Traefik
./scripts/upgrade-traefik.sh

# Verifiera allt
./scripts/verify-all.sh

# Felsökning
./scripts/diagnose-404.sh
```

---

## Viktiga Noteringar

1. **Backup:** `update-server.sh` skapar automatiskt backup av Coolify-data
2. **Nedtid:** Uppdateringar kan orsaka kort nedtid (1-2 minuter)
3. **Testa:** Testa alltid efter uppdateringar
4. **Dokumentation:** Följ alltid officiell dokumentation för breaking changes

---

## Support

Om problem uppstår:
1. Kör `./scripts/diagnose-404.sh` för systematisk diagnostik
2. Kontrollera `TROUBLESHOOTING.md` för vanliga problem
3. Se officiell dokumentation för specifika fel

