#!/usr/bin/env bash
set -euo pipefail

# quick-ssh.sh - Quick SSH connection and diagnostics for THA Coolify server

HOST="${1:-tha}"  # Use SSH config alias 'tha' by default

echo "🔌 Connecting to $HOST..."

# Quick ping check
if ! ping -c 1 -W 2 46.62.206.47 &>/dev/null; then
    echo "❌ Server not responding to ping"
    exit 1
fi

# Try SSH connection
if ! ssh -o ConnectTimeout=5 "$HOST" 'echo "SSH OK"' &>/dev/null; then
    echo "❌ SSH connection failed"
    echo "Troubleshooting:"
    echo "  1. Check if server is in rescue mode (Hetzner console)"
    echo "  2. Run: ssh -vvv $HOST"
    echo "  3. Check SSH key: ls -la ~/.ssh/id_ed25519_coolify"
    exit 1
fi

echo "✅ SSH connection successful"
echo ""

# Show quick diagnostics
ssh "$HOST" bash <<'REMOTE'
echo "📊 Quick Status:"
echo "  Disk: $(df -h / | awk 'NR==2 {print $5 " used"}')"
echo "  Memory: $(free -h | awk 'NR==2 {print $3 "/" $2}')"
echo "  Swap: $(free -h | awk 'NR==3 {print $3 "/" $2}')"
echo "  Uptime: $(uptime -p)"
echo "  Load: $(uptime | awk -F'load average:' '{print $2}')"
echo ""
echo "🐳 Docker Status:"
systemctl is-active docker >/dev/null && echo "  Docker: ✅ Running" || echo "  Docker: ❌ Stopped"
CONTAINERS=$(docker ps --format '{{.Status}}' 2>/dev/null | wc -l)
echo "  Containers running: $CONTAINERS"
echo ""
echo "💡 Quick commands:"
echo "  • Full diagnostics: cd /root && ./diagnose.sh"
echo "  • Docker logs: docker compose logs -f"
echo "  • Restart service: docker compose restart <service>"
REMOTE

echo ""
echo "🎯 To connect interactively: ssh $HOST"
echo "🔧 To open in VS Code: Command Palette → Remote-SSH: Connect to Host → $HOST"
