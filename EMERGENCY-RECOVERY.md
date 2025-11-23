# 🚨 Coolify Emergency Troubleshooting Guide

## Problem: Coolify går inte att nå plötsligt

### Steg 1: Grundläggande serveråtkomst
```bash
# SSH till servern (prova olika användare)
ssh root@46.62.206.47
ssh ubuntu@46.62.206.47
ssh admin@46.62.206.47

# Om SSH inte fungerar - kontrollera från Hetzner Console:
# 1. Logga in på https://console.hetzner.cloud
# 2. Välj din server
# 3. Använd "Console" knappen för direktåtkomst
```

### Steg 2: Kontrollera serverstatus (från Hetzner Console)
```bash
# Kontrollera att servern körs
systemctl status

# Kontrollera disk space (vanlig orsak till krasch)
df -h

# Kontrollera minne
free -h

# Kontrollera CPU load
top
```

### Steg 3: Kontrollera Docker
```bash
# Är Docker igång?
systemctl status docker
docker --version

# Om Docker inte körs:
systemctl start docker
systemctl enable docker
```

### Steg 4: Kontrollera Coolify specifikt
```bash
# Leta efter Coolify installation
ls -la /data/coolify/
ls -la /opt/coolify/
find / -name "*coolify*" -type d 2>/dev/null

# Kontrollera Coolify containers
docker ps -a | grep coolify
docker ps -a | grep traefik

# Kontrollera Docker networks
docker network ls
```

### Steg 5: Starta om Coolify
```bash
# Om Coolify är installerat i /data/coolify
cd /data/coolify/source
docker-compose down
docker-compose up -d

# Eller prova:
cd /opt/coolify
docker-compose restart

# Kontrollera logs
docker logs coolify --tail 50
docker logs coolify-traefik --tail 50
```

## 🔥 Vanliga orsaker till Coolify-krasch:

### 1. Disk space slut
```bash
df -h
# Om disk är full:
docker system prune -a --volumes
```

### 2. Minne slut / OOM Killer
```bash
dmesg | grep -i "killed process"
free -h
# Om minne är slut - starta om servern
```

### 3. Docker daemon kraschat
```bash
systemctl restart docker
```

### 4. Coolify database korrupt
```bash
# Backup och återställ
cd /data/coolify
docker-compose down
cp -r data data_backup
docker-compose up -d
```

### 5. Port konflikter
```bash
netstat -tlnp | grep ':80\|:443\|:8000'
# Döda processer som använder portar
```

## 🆘 Emergency recovery:

### Om inget fungerar - Reinstall Coolify:
```bash
# Backup data först!
cp -r /data/coolify /backup/coolify-$(date +%Y%m%d)

# Reinstall
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

### Om servern är helt trasig:
1. Gå till Hetzner Console
2. Skapa snapshot av servern
3. Starta om servern
4. Om fortfarande problem - återställ från snapshot

## 🔍 Debug commands att köra:

```bash
# Komplett serverdiagnostic
echo "=== SERVER STATUS ==="
uptime
df -h
free -h
docker ps -a
systemctl status docker
systemctl status coolify 2>/dev/null || echo "No coolify service"

echo "=== COOLIFY STATUS ==="
ls -la /data/coolify/ 2>/dev/null || echo "No /data/coolify"
docker ps | grep coolify
docker logs coolify --tail 10 2>/dev/null || echo "No coolify container"

echo "=== NETWORK STATUS ==="
netstat -tlnp | grep ':80\|:443'
docker network ls

echo "=== DISK USAGE ==="
du -sh /var/lib/docker/
du -sh /data/ 2>/dev/null || echo "No /data directory"
```