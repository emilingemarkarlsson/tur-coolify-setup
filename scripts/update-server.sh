#!/usr/bin/env bash
set -euo pipefail

# update-server.sh - Säker serveruppdatering för Hetzner Coolify-server
# Detta script uppdaterar systempaket, Docker och verifierar att allt fungerar

HOST="${1:-tha}"  # Använd SSH config alias 'tha' som standard
SERVER_IP="46.62.206.47"

echo "🔄 Server Update Script för Hetzner Coolify"
echo "=========================================="
echo ""

# Färger för output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funktion för att visa meddelanden
info() {
    echo -e "${GREEN}ℹ️  $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Steg 1: Verifiera SSH-anslutning
info "Steg 1: Verifierar SSH-anslutning..."

if ! ping -c 1 -W 2 "$SERVER_IP" &>/dev/null; then
    error "Servern svarar inte på ping"
    echo "Kontrollera att servern är igång i Hetzner Cloud Console"
    exit 1
fi

if ! ssh -o ConnectTimeout=5 "$HOST" 'echo "SSH OK"' &>/dev/null; then
    error "SSH-anslutning misslyckades"
    echo ""
    echo "Felsökning:"
    echo "  1. Kontrollera SSH-nyckel: ls -la ~/.ssh/id_ed25519_coolify"
    echo "  2. Testa manuellt: ssh -vvv $HOST"
    echo "  3. Använd Hetzner Console för direktåtkomst"
    exit 1
fi

info "SSH-anslutning fungerar ✓"
echo ""

# Steg 2: Visa nuvarande status
info "Steg 2: Nuvarande serverstatus..."

ssh "$HOST" bash <<'REMOTE'
echo "📊 Server Status:"
echo "  OS: $(lsb_release -d | cut -f2)"
echo "  Kernel: $(uname -r)"
echo "  Uptime: $(uptime -p)"
echo "  Disk: $(df -h / | awk 'NR==2 {print $5 " used (" $3 "/" $2 ")"}')"
echo "  Memory: $(free -h | awk 'NR==2 {print $3 "/" $2}')"
echo "  Load: $(uptime | awk -F'load average:' '{print $2}')"
echo ""
echo "🐳 Docker Status:"
docker --version 2>/dev/null || echo "  Docker: Ej installerat"
systemctl is-active docker >/dev/null && echo "  Status: ✅ Körs" || echo "  Status: ❌ Stoppad"
CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)
echo "  Containers: $CONTAINERS körs"
echo ""
echo "📦 Paket som kan uppdateras:"
apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l | xargs echo "  Antal:"
REMOTE

echo ""

# Steg 3: Bekräfta uppdatering
warn "Detta kommer att:"
echo "  • Uppdatera systempaket (apt update && apt upgrade)"
echo "  • Rensa oanvända paket (apt autoremove)"
echo "  • Starta om Docker (stoppar containers tillfälligt)"
echo "  • Starta om Coolify och alla services"
echo "  • Verifiera att allt fungerar efter uppdatering"
echo ""

read -p "Vill du fortsätta? (ja/nej): " -r < /dev/tty
if [[ ! $REPLY =~ ^[Jj]a$ ]]; then
    info "Uppdatering avbruten av användaren"
    exit 0
fi

echo ""

# Steg 4: Säkerhetskopiera (valfritt)
info "Steg 3: Skapar säkerhetskopia av Coolify data..."

ssh "$HOST" bash <<'REMOTE'
if [ -d "/data/coolify" ]; then
    BACKUP_DIR="/tmp/coolify-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    echo "Skapar backup i $BACKUP_DIR..."
    cd /data/coolify
    tar czf "$BACKUP_DIR/coolify-data.tar.gz" . 2>/dev/null || true
    echo "Backup skapad: $BACKUP_DIR/coolify-data.tar.gz"
else
    echo "Ingen /data/coolify katalog hittades, hoppar över backup"
fi
REMOTE

echo ""

# Steg 5: Uppdatera systempaket
info "Steg 4: Uppdaterar systempaket..."

ssh "$HOST" bash <<'REMOTE'
set -e
echo "Uppdaterar paketlistor..."
apt update

echo ""
echo "Kör säkerhetsuppdateringar..."
apt upgrade -y

echo ""
echo "Rensar oanvända paket..."
apt autoremove -y
apt autoclean

echo ""
echo "✅ Systemuppdateringar klara"
REMOTE

if [ $? -ne 0 ]; then
    error "Systemuppdateringar misslyckades"
    exit 1
fi

echo ""

# Steg 6: Kontrollera Docker
info "Steg 5: Kontrollerar Docker..."

ssh "$HOST" bash <<'REMOTE'
echo "Docker-version:"
docker --version || echo "Docker ej installerat"

echo ""
echo "Docker-status:"
systemctl status docker --no-pager -l | head -5 || echo "Docker-tjänst ej aktiv"

echo ""
echo "Körs Docker-containers efter uppdatering?"
docker ps --format "table {{.Names}}\t{{.Status}}" || echo "Inga containers körs"
REMOTE

echo ""

# Steg 7: Starta om Docker (om nödvändigt)
info "Steg 6: Startar om Docker (för att säkerställa att allt är uppdaterat)..."

ssh "$HOST" bash <<'REMOTE'
echo "🔄 Startar om Docker-tjänsten..."
echo "  (Detta stoppar alla containers tillfälligt)"
systemctl restart docker
sleep 3

echo ""
echo "✅ Docker omstartad"
echo "  Väntar 5 sekunder för att Docker ska starta klart..."
sleep 5

echo ""
echo "Docker-status efter omstart:"
systemctl is-active docker >/dev/null && echo "  ✅ Docker körs" || echo "  ❌ Docker körs inte"
REMOTE

echo ""

# Steg 8: Starta om Coolify
info "Steg 7: Startar om Coolify..."

ssh "$HOST" bash <<'REMOTE'
if [ -d "/data/coolify/source" ]; then
    echo "Coolify installation hittad i /data/coolify/source"
    cd /data/coolify/source
    
    echo ""
    echo "🔄 Startar om Coolify..."
    
    # Starta om Coolify med docker compose
    if docker compose version >/dev/null 2>&1; then
        docker compose down
        sleep 2
        docker compose up -d
    elif command -v docker-compose >/dev/null 2>&1; then
        docker-compose down
        sleep 2
        docker-compose up -d
    else
        echo "⚠️  Docker Compose ej tillgängligt, försöker starta containers manuellt..."
        docker ps -a --filter "name=coolify" --format '{{.Names}}' | xargs -r docker start
    fi
    
    echo ""
    echo "✅ Coolify omstartad"
    echo "  Väntar 10 sekunder för att Coolify ska starta klart..."
    sleep 10
    
    echo ""
    echo "Coolify containers status:"
    docker compose ps 2>/dev/null || docker-compose ps 2>/dev/null || docker ps --filter "name=coolify" --format "table {{.Names}}\t{{.Status}}"
else
    echo "⚠️  Coolify installation ej hittad i /data/coolify/source"
    echo "  Hoppar över Coolify-omstart"
fi
REMOTE

echo ""

# Steg 9: Starta om Services
info "Steg 8: Startar om alla services..."

ssh "$HOST" bash <<'REMOTE'
echo "🔄 Startar om services i Coolify..."
echo ""

if [ -d "/data/coolify/services" ]; then
    SERVICE_COUNT=$(find /data/coolify/services -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    echo "Hittade $SERVICE_COUNT service(s)"
    echo ""
    
    for service_dir in /data/coolify/services/*; do
        if [ -d "$service_dir" ] && [ -f "$service_dir/docker-compose.yml" ]; then
            SERVICE_NAME=$(basename "$service_dir")
            echo "📦 Startar om $SERVICE_NAME..."
            
            cd "$service_dir"
            
            # Starta om service
            if docker compose version >/dev/null 2>&1; then
                docker compose restart 2>/dev/null && echo "  ✅ $SERVICE_NAME omstartad" || echo "  ⚠️  Kunde inte starta om $SERVICE_NAME"
            elif command -v docker-compose >/dev/null 2>&1; then
                docker-compose restart 2>/dev/null && echo "  ✅ $SERVICE_NAME omstartad" || echo "  ⚠️  Kunde inte starta om $SERVICE_NAME"
            else
                # Fallback: starta containers manuellt
                CONTAINER_NAMES=$(grep -E "container_name:" "$service_dir/docker-compose.yml" | sed 's/.*container_name:[[:space:]]*//' | tr -d '"' || true)
                if [ -n "$CONTAINER_NAMES" ]; then
                    echo "$CONTAINER_NAMES" | while read -r container; do
                        docker restart "$container" 2>/dev/null && echo "  ✅ $container omstartad" || echo "  ⚠️  Kunde inte starta om $container"
                    done
                fi
            fi
        fi
    done
    
    echo ""
    echo "✅ Services omstartade"
    echo "  Väntar 5 sekunder för att services ska starta klart..."
    sleep 5
else
    echo "⚠️  /data/coolify/services/ katalog finns inte"
    echo "  Hoppar över service-omstart"
fi
REMOTE

echo ""

# Steg 10: Verifiera Coolify
info "Steg 9: Verifierar Coolify efter omstart..."

ssh "$HOST" bash <<'REMOTE'
if [ -d "/data/coolify/source" ]; then
    echo "Coolify installation hittad i /data/coolify/source"
    cd /data/coolify/source
    echo ""
    echo "Coolify containers:"
    docker compose ps 2>/dev/null || docker-compose ps 2>/dev/null || echo "Kunde inte lista containers"
else
    echo "Coolify installation ej hittad i /data/coolify/source"
fi
REMOTE

echo ""

# Steg 11: Slutlig status
info "Steg 10: Slutlig verifiering..."

ssh "$HOST" bash <<'REMOTE'
echo "📊 Efter uppdatering:"
echo "  Disk: $(df -h / | awk 'NR==2 {print $5 " used"}')"
echo "  Memory: $(free -h | awk 'NR==2 {print $3 "/" $2}')"
echo "  Uptime: $(uptime -p)"
echo ""
echo "🐳 Docker:"
systemctl is-active docker >/dev/null && echo "  Status: ✅ Körs" || echo "  Status: ❌ Stoppad"
CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)
echo "  Containers: $CONTAINERS körs"
REMOTE

echo ""
info "✅ Serveruppdatering klar!"
echo ""
echo "💡 Nästa steg:"
echo "  • Vänta 1-2 minuter för att alla services ska starta klart"
echo "  • Testa externa endpoints: ./scripts/diagnose.sh"
echo "  • Kontrollera Coolify dashboard: https://coolify.theunnamedroads.com"
echo "  • Om services ger 404: ./scripts/fix-404.sh"
echo "  • Övervaka logs: ssh $HOST 'docker logs -f <container-name>'"
echo ""

