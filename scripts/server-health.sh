#!/usr/bin/env bash
set -euo pipefail

# server-health.sh - Omfattande serverhälsokontroll
# Visar lagring, minne, CPU, Docker, containers, etc.

HOST="${1:-tha}"

echo "🏥 Server Health Check"
echo "======================"
echo ""

# Test SSH connection
if ! ssh -o ConnectTimeout=5 "$HOST" 'echo "OK"' &>/dev/null 2>&1; then
    echo "❌ Kan inte ansluta till $HOST"
    exit 1
fi

ssh "$HOST" bash <<'REMOTE'
set +u

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
status_ok() {
    echo -e "${GREEN}✅${NC} $1"
}

status_warn() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

status_error() {
    echo -e "${RED}❌${NC} $1"
}

info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

# ============================================================================
# 1. SYSTEM INFO
# ============================================================================
echo "📋 System Information"
echo "─────────────────────"
echo "  OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "N/A")"
echo "  Kernel: $(uname -r)"
echo "  Hostname: $(hostname)"
echo "  Uptime: $(uptime -p 2>/dev/null || uptime | awk '{print $3,$4}' | sed 's/,//')"
echo "  Load Average: $(uptime | awk -F'load average:' '{print $2}' | xargs)"
echo ""

# ============================================================================
# 2. DISK USAGE
# ============================================================================
echo "💾 Disk Usage"
echo "─────────────"

# Root filesystem
ROOT_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
ROOT_USED=$(df -h / | awk 'NR==2 {print $3}')
ROOT_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
ROOT_AVAIL=$(df -h / | awk 'NR==2 {print $4}')

if [ "$ROOT_USAGE" -gt 90 ]; then
    status_error "Root disk: ${ROOT_USAGE}% used (${ROOT_USED}/${ROOT_TOTAL}) - KRITISKT!"
elif [ "$ROOT_USAGE" -gt 80 ]; then
    status_warn "Root disk: ${ROOT_USAGE}% used (${ROOT_USED}/${ROOT_TOTAL}) - Högt!"
elif [ "$ROOT_USAGE" -gt 70 ]; then
    status_warn "Root disk: ${ROOT_USAGE}% used (${ROOT_USED}/${ROOT_TOTAL}) - Övervaka"
else
    status_ok "Root disk: ${ROOT_USAGE}% used (${ROOT_USED}/${ROOT_TOTAL})"
fi
echo "  Tillgängligt: ${ROOT_AVAIL}"

# Docker data directory
if [ -d "/var/lib/docker" ]; then
    DOCKER_USAGE=$(df -h /var/lib/docker 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//' || echo "0")
    DOCKER_USED=$(df -h /var/lib/docker 2>/dev/null | awk 'NR==2 {print $3}' || echo "N/A")
    echo "  Docker data: ${DOCKER_USED} (${DOCKER_USAGE}% used)"
fi

# Coolify data directory
if [ -d "/data/coolify" ]; then
    COOLIFY_SIZE=$(du -sh /data/coolify 2>/dev/null | awk '{print $1}' || echo "N/A")
    echo "  Coolify data: ${COOLIFY_SIZE}"
fi

echo ""

# ============================================================================
# 3. MEMORY & SWAP
# ============================================================================
echo "🧠 Memory & Swap"
echo "────────────────"

MEM_TOTAL=$(free -h | awk 'NR==2 {print $2}')
MEM_USED=$(free -h | awk 'NR==2 {print $3}')
MEM_AVAIL=$(free -h | awk 'NR==2 {print $7}')
MEM_PERCENT=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')

if [ "$MEM_PERCENT" -gt 95 ]; then
    status_error "Memory: ${MEM_PERCENT}% used (${MEM_USED}/${MEM_TOTAL}) - KRITISKT!"
elif [ "$MEM_PERCENT" -gt 85 ]; then
    status_warn "Memory: ${MEM_PERCENT}% used (${MEM_USED}/${MEM_TOTAL}) - Högt!"
elif [ "$MEM_PERCENT" -gt 70 ]; then
    status_warn "Memory: ${MEM_PERCENT}% used (${MEM_USED}/${MEM_TOTAL}) - Övervaka"
else
    status_ok "Memory: ${MEM_PERCENT}% used (${MEM_USED}/${MEM_TOTAL})"
fi
echo "  Tillgängligt: ${MEM_AVAIL}"

# Swap
SWAP_TOTAL=$(free -h | awk 'NR==3 {print $2}')
SWAP_USED=$(free -h | awk 'NR==3 {print $3}')
if [ "$SWAP_TOTAL" != "0B" ] && [ -n "$SWAP_TOTAL" ]; then
    SWAP_PERCENT=$(free | awk 'NR==3{printf "%.0f", ($3*100)/$2}' 2>/dev/null || echo "0")
    if [ "$SWAP_PERCENT" -gt 50 ]; then
        status_warn "Swap: ${SWAP_PERCENT}% used (${SWAP_USED}/${SWAP_TOTAL}) - Överväg mer RAM"
    else
        status_ok "Swap: ${SWAP_PERCENT}% used (${SWAP_USED}/${SWAP_TOTAL})"
    fi
else
    info "Swap: Ingen swap konfigurerad"
fi

echo ""

# ============================================================================
# 4. CPU
# ============================================================================
echo "⚡ CPU"
echo "─────"

CPU_CORES=$(nproc)
CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
CPU_LOAD_PERCENT=$(echo "$CPU_LOAD * 100 / $CPU_CORES" | bc 2>/dev/null | awk '{printf "%.0f", $1}' || echo "N/A")

if [ -n "$CPU_LOAD_PERCENT" ] && [ "$CPU_LOAD_PERCENT" != "N/A" ]; then
    if [ "$CPU_LOAD_PERCENT" -gt 100 ]; then
        status_warn "Load: ${CPU_LOAD} (${CPU_LOAD_PERCENT}% av ${CPU_CORES} cores) - Överbelastad"
    elif [ "$CPU_LOAD_PERCENT" -gt 80 ]; then
        status_warn "Load: ${CPU_LOAD} (${CPU_LOAD_PERCENT}% av ${CPU_CORES} cores) - Högt"
    else
        status_ok "Load: ${CPU_LOAD} (${CPU_LOAD_PERCENT}% av ${CPU_CORES} cores)"
    fi
else
    info "Load: ${CPU_LOAD} (${CPU_CORES} cores)"
fi

echo "  Cores: ${CPU_CORES}"
echo ""

# ============================================================================
# 5. DOCKER STATUS
# ============================================================================
echo "🐳 Docker Status"
echo "────────────────"

if systemctl is-active docker >/dev/null 2>&1; then
    status_ok "Docker service: Running"
    DOCKER_VERSION=$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',' || echo "N/A")
    echo "  Version: ${DOCKER_VERSION}"
else
    status_error "Docker service: Stopped"
    echo ""
    exit 1
fi

echo ""

# ============================================================================
# 6. DOCKER DISK USAGE
# ============================================================================
echo "📦 Docker Disk Usage"
echo "───────────────────"

docker system df 2>/dev/null | while IFS= read -r line; do
    if [[ "$line" =~ ^TYPE|Images|Containers|Local\ Volumes|Build\ Cache ]]; then
        echo "  $line"
    fi
done

# Detailed breakdown
echo ""
echo "  Detaljerad breakdown:"
docker system df -v 2>/dev/null | grep -E "^(REPOSITORY|TAG|IMAGE ID|CONTAINER ID|VOLUME NAME|CACHE ID)" | head -20 | sed 's/^/    /' || echo "    (kör 'docker system df -v' för full detalj)"

echo ""

# ============================================================================
# 7. CONTAINERS
# ============================================================================
echo "📋 Containers"
echo "─────────────"

RUNNING=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)
STOPPED=$(docker ps -a --format '{{.Names}}' 2>/dev/null | wc -l)
TOTAL=$((RUNNING + STOPPED))

if [ "$RUNNING" -eq 0 ]; then
    status_error "Inga containers körs!"
elif [ "$STOPPED" -gt 0 ]; then
    status_warn "Körs: ${RUNNING} / ${TOTAL} totalt (${STOPPED} stoppade)"
else
    status_ok "Körs: ${RUNNING} / ${TOTAL} totalt"
fi

echo ""
echo "  Aktiva containers:"
if [ "$RUNNING" -gt 0 ]; then
    docker ps --format "    • {{.Names}} ({{.Status}})" 2>/dev/null | head -15
    if [ "$RUNNING" -gt 15 ]; then
        echo "    ... och $((RUNNING - 15)) fler"
    fi
else
    echo "    (inga)"
fi

if [ "$STOPPED" -gt 0 ]; then
    echo ""
    echo "  Stoppade containers:"
    docker ps -a --filter "status=exited" --format "    • {{.Names}} ({{.Status}})" 2>/dev/null | head -10
    if [ "$STOPPED" -gt 10 ]; then
        echo "    ... och $((STOPPED - 10)) fler"
    fi
fi

echo ""

# ============================================================================
# 8. TOP PROCESSES (CPU & Memory)
# ============================================================================
echo "🔥 Top Processes"
echo "────────────────"

echo "  Top 5 CPU:"
ps aux --sort=-%cpu | head -6 | tail -5 | awk '{printf "    %-30s %5s%%\n", $11, $3}' | sed 's/\/.*\///g'

echo ""
echo "  Top 5 Memory:"
ps aux --sort=-%mem | head -6 | tail -5 | awk '{printf "    %-30s %5s%%\n", $11, $4}' | sed 's/\/.*\///g'

echo ""

# ============================================================================
# 9. DOCKER VOLUMES SIZE
# ============================================================================
echo "💿 Docker Volumes"
echo "─────────────────"

VOLUME_COUNT=$(docker volume ls -q 2>/dev/null | wc -l)
if [ "$VOLUME_COUNT" -gt 0 ]; then
    echo "  Antal volumes: ${VOLUME_COUNT}"
    echo ""
    echo "  Största volumes (top 5):"
    docker volume ls -q 2>/dev/null | while read -r vol; do
        SIZE=$(docker system df -v 2>/dev/null | grep "$vol" | awk '{print $3}' || echo "N/A")
        if [ -n "$SIZE" ] && [ "$SIZE" != "N/A" ]; then
            echo "    • ${vol}: ${SIZE}"
        fi
    done | head -5
else
    info "Inga volumes"
fi

echo ""

# ============================================================================
# 10. NETWORK
# ============================================================================
echo "🌐 Network"
echo "──────────"

# Active connections
CONNECTIONS=$(ss -tun | grep ESTAB | wc -l)
echo "  Aktiva connections: ${CONNECTIONS}"

# Docker networks
NETWORK_COUNT=$(docker network ls -q 2>/dev/null | wc -l)
echo "  Docker networks: ${NETWORK_COUNT}"

echo ""

# ============================================================================
# 11. SYSTEM HEALTH CHECKS
# ============================================================================
echo "🏥 System Health"
echo "────────────────"

# Zombie processes
ZOMBIES=$(ps aux | awk '$8 ~ /^Z/ {print $2}' | wc -l)
if [ "$ZOMBIES" -gt 0 ]; then
    status_warn "${ZOMBIES} zombie processes (normalt efter uppdateringar)"
else
    status_ok "Inga zombie processes"
fi

# Failed systemd services
FAILED=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
if [ "$FAILED" -gt 0 ]; then
    status_warn "${FAILED} failed systemd services"
    systemctl --failed --no-legend 2>/dev/null | head -5 | sed 's/^/    /'
else
    status_ok "Inga failed systemd services"
fi

# Recent OOM kills
OOM_COUNT=$(dmesg 2>/dev/null | grep -i "out of memory" | wc -l)
if [ "$OOM_COUNT" -gt 0 ]; then
    status_warn "${OOM_COUNT} OOM (Out of Memory) events i loggen"
else
    status_ok "Inga OOM events"
fi

echo ""

# ============================================================================
# SUMMARY
# ============================================================================
echo "📊 Summary"
echo "──────────"

# Calculate overall health score
HEALTH_SCORE=100

# Deduct points for issues
if [ "$ROOT_USAGE" -gt 90 ]; then HEALTH_SCORE=$((HEALTH_SCORE - 30)); fi
if [ "$ROOT_USAGE" -gt 80 ]; then HEALTH_SCORE=$((HEALTH_SCORE - 15)); fi
if [ "$MEM_PERCENT" -gt 95 ]; then HEALTH_SCORE=$((HEALTH_SCORE - 30)); fi
if [ "$MEM_PERCENT" -gt 85 ]; then HEALTH_SCORE=$((HEALTH_SCORE - 15)); fi
if [ "$RUNNING" -eq 0 ]; then HEALTH_SCORE=$((HEALTH_SCORE - 20)); fi
if [ "$FAILED" -gt 0 ]; then HEALTH_SCORE=$((HEALTH_SCORE - 10)); fi

if [ "$HEALTH_SCORE" -ge 90 ]; then
    status_ok "Overall Health: ${HEALTH_SCORE}/100 - Utmärkt!"
elif [ "$HEALTH_SCORE" -ge 70 ]; then
    status_warn "Overall Health: ${HEALTH_SCORE}/100 - Bra, men övervaka"
elif [ "$HEALTH_SCORE" -ge 50 ]; then
    status_warn "Overall Health: ${HEALTH_SCORE}/100 - Varningar finns"
else
    status_error "Overall Health: ${HEALTH_SCORE}/100 - KRITISKT - Åtgärda omedelbart!"
fi

echo ""
echo "💡 Tips:"
echo "  • Rensa Docker: docker system prune -a (tar bort oanvända images/containers)"
echo "  • Se detaljerad disk: docker system df -v"
echo "  • Se container stats: docker stats --no-stream"
echo "  • Se system logs: journalctl -xe | tail -50"
REMOTE

echo ""
echo "✅ Health check klar!"
echo ""
echo "💡 För mer detaljer:"
echo "  • Docker stats: ssh $HOST 'docker stats --no-stream'"
echo "  • Disk detaljer: ssh $HOST 'df -h'"
echo "  • Memory detaljer: ssh $HOST 'free -h'"

