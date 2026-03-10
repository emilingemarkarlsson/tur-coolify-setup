# 🔄 Serveruppdatering - Snabbguide

> **💡 Automatiserad uppgradering:** För komplett automatiserad process, se [UPGRADE.md](UPGRADE.md)

## Automatiserad Uppgradering (Rekommenderat)

**Komplett automatiserad uppgradering av allt:**
```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/auto-upgrade-all.sh
```

Detta uppgraderar:
- ✅ Ubuntu-servern
- ✅ Docker
- ✅ Coolify
- ✅ Alla aktiva services
- ✅ Skapar/uppdaterar dokumentation

---

## Snabbuppdatering (Manuell - 2 kommandon)

**Steg 1: Kontrollera vad som behöver uppdateras**
```bash
cd ~/Documents/dev/tur-coolify-setup
./scripts/upgrade-check.sh
```

**Steg 2: Uppdatera servern**
```bash
./scripts/update-server.sh
```

Det är allt! Scriptet kommer att:

- ✅ Visa serverstatus
- ✅ Säkerhetskopiera data
- ✅ Uppdatera systempaket
- ✅ Starta om Docker
- ✅ Starta om Coolify
- ✅ Starta om alla services
- ✅ Verifiera att allt fungerar

**Svara `ja` när scriptet frågar om du vill fortsätta.**

**Viktigt:** Scriptet startar om Docker, Coolify och alla services automatiskt. Detta kan ta 1-2 minuter.

---

## Efter uppdatering

**Verifiera att allt fungerar:**
```bash
./scripts/verify-all.sh
```

**Om servern visar "System restart required":**
```bash
ssh tha 'reboot'
# Vänta 2-3 minuter
./scripts/verify-all.sh
```

---

## Komplett Uppgraderingsprocess

För systematisk uppgradering med versionkontroll och kompatibilitetsverifiering, se: **[UPGRADE.md](UPGRADE.md)**

Detta inkluderar:
- ✅ Versionkontroll mot officiell dokumentation
- ✅ Kompatibilitetsverifiering
- ✅ Traefik-uppgradering för Docker 29.x
- ✅ Systematisk felsökning

---

## Detaljerad guide

För mer information, se: [docs/guides/SERVER-UPDATE-GUIDE.md](docs/guides/SERVER-UPDATE-GUIDE.md)
