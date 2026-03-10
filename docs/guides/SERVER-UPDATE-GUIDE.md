# Server Update Guide - Hetzner

> **Snabbguide:** För enkel uppdatering, se [UPDATE.md](../../UPDATE.md) i root (2 kommandon!)

Denna detaljerade guide hjälper dig att uppdatera din Hetzner-server och koppla upp dig via SSH.

## Förutsättningar

- Hetzner Cloud-konto med åtkomst till servern
- SSH-nyckel för autentisering
- Server IP: `46.62.206.47`

## Steg 1: Verifiera SSH-anslutning

### Kontrollera SSH-nyckel

Först, kontrollera om din SSH-nyckel finns:

```bash
ls -la ~/.ssh/id_ed25519_coolify
```

Om nyckeln inte finns, skapa en ny:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_coolify -C "coolify-hetzner"
```

### Konfigurera SSH Config

Lägg till följande i din `~/.ssh/config`:

```bash
Host tha
    HostName 46.62.206.47
    User root
    IdentityFile ~/.ssh/id_ed25519_coolify
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host coolify-tha
    HostName 46.62.206.47
    User root
    IdentityFile ~/.ssh/id_ed25519_coolify
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

### Testa SSH-anslutning

```bash
# Testa med quick-ssh scriptet
./scripts/quick-ssh.sh

# Eller testa direkt
ssh tha 'echo "SSH fungerar!"'
```

Om SSH inte fungerar, se felsökningsavsnittet nedan.

## Steg 2: Uppdatera servern

### Säkerhetskopiera först

Innan du uppdaterar, säkerhetskopiera viktiga data:

```bash
# Anslut till servern
ssh tha

# Skapa backup av Coolify data
cd /data/coolify
tar czf /tmp/coolify-backup-$(date +%Y%m%d).tar.gz .

# Kontrollera Docker volumes
docker volume ls
```

### Systemuppdateringar

Kör följande kommandon på servern:

```bash
# Uppdatera paketlistor
apt update

# Visa tillgängliga uppdateringar
apt list --upgradable

# Uppdatera systempaket (säkerhetsuppdateringar)
apt upgrade -y

# Uppdatera alla paket (inklusive större versioner)
# apt full-upgrade -y  # Använd med försiktighet

# Rensa bort oanvända paket
apt autoremove -y
apt autoclean
```

### Docker-uppdateringar

```bash
# Kontrollera Docker-version
docker --version

# Uppdatera Docker (om nödvändigt)
# För Ubuntu/Debian:
apt update
apt install docker.io docker-compose-plugin -y

# Starta om Docker (stoppar alla containers tillfälligt)
systemctl restart docker
```

### Coolify-uppdateringar

```bash
# Kontrollera Coolify-version
cd /data/coolify/source
docker compose ps

# Uppdatera Coolify (via deras officiella metod)
# Se: https://coolify.io/docs/installation/update
```

## Steg 3: Verifiera efter uppdatering

Efter uppdateringar, verifiera att allt fungerar:

```bash
# Kör quick-ssh för snabb status
./scripts/quick-ssh.sh

# Kontrollera Docker-containers
ssh tha 'docker ps'

# Kontrollera Coolify-status
ssh tha 'cd /data/coolify/source && docker compose ps'

# Testa externa endpoints
./scripts/diagnose.sh
```

## Felsökning SSH

### Problem: "Permission denied (publickey)"

**Lösning 1: Lägg till din publika nyckel på servern**

```bash
# Kopiera din publika nyckel
cat ~/.ssh/id_ed25519_coolify.pub

# Anslut via Hetzner Console och lägg till nyckeln:
# 1. Gå till https://console.hetzner.cloud
# 2. Välj din server
# 3. Klicka på "Console" för direktåtkomst
# 4. Kör: nano ~/.ssh/authorized_keys
# 5. Klistra in din publika nyckel
```

**Lösning 2: Använd Hetzner Cloud Console**

Om SSH inte fungerar alls:

1. Logga in på [Hetzner Cloud Console](https://console.hetzner.cloud)
2. Välj din server
3. Klicka på "Console" för direktåtkomst via webbläsare
4. Lägg till din SSH-nyckel manuellt

### Problem: "Connection timeout"

**Kontrollera:**

```bash
# Testa ping
ping -c 3 46.62.206.47

# Testa SSH-port
nc -zv 46.62.206.47 22

# Om ping fungerar men SSH inte:
# Servern kan vara överbelastad eller SSH-daemonen kraschat
# Använd Hetzner Console för direktåtkomst
```

### Problem: "Host key verification failed"

```bash
# Ta bort gammal host key
ssh-keygen -R 46.62.206.47

# Försök igen
ssh tha
```

## Automatiserad uppdatering

Använd scriptet `scripts/update-server.sh` för automatiserad uppdatering:

```bash
./scripts/update-server.sh
```

Detta script:
- Säkerhetskopierar viktiga data
- Uppdaterar systempaket
- Uppdaterar Docker (om nödvändigt)
- Verifierar att allt fungerar efter uppdatering

## Best Practices

1. **Uppdatera regelbundet**: Köra säkerhetsuppdateringar minst en gång i månaden
2. **Säkerhetskopiera innan uppdateringar**: Alltid säkerhetskopiera innan större uppdateringar
3. **Testa i staging först**: Om möjligt, testa uppdateringar på en testserver först
4. **Övervaka efter uppdatering**: Använd monitoring-verktyg för att se till att allt fungerar
5. **Dokumentera ändringar**: Håll koll på vad som uppdaterats och när

## Vanliga kommandon

```bash
# Snabb status
./scripts/quick-ssh.sh

# Full diagnostik
./scripts/diagnose.sh

# SSH direkt
ssh tha

# VS Code Remote
# Cmd+Shift+P → Remote-SSH: Connect to Host → tha
```

## Ytterligare resurser

- [Hetzner Cloud Documentation](https://docs.hetzner.com/)
- [Coolify Update Guide](https://coolify.io/docs/installation/update)
- [Ubuntu Server Guide](https://ubuntu.com/server/docs)

