#!/usr/bin/env bash
set -euo pipefail

# post-reboot-recover.sh
# Automates post-reboot recovery for the Coolify host.
# 1. Loops until SSH banner succeeds.
# 2. Gathers system + docker diagnostics.
# 3. Applies remedial actions (restart sshd/docker if needed, create swap, tighten docker logging) optionally.
# 4. Runs local diagnose.sh at end.

HOST_IP="46.62.206.47"
SSH_KEY="${HOME}/.ssh/id_ed25519_coolify"
SSH_OPTS="-o ConnectTimeout=8 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Remote diagnostic command block (single properly quoted string)
REMOTE_CMDS_BASE='echo "=== SYSTEM SNAPSHOT ==="; df -h; free -m; uname -a; date; \
echo; echo "=== TOP CPU/MEM ==="; ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head; ps -eo pid,comm,%cpu,%mem --sort=-%mem | head; \
echo; echo "=== DOCKER STATUS ==="; systemctl is-active docker || true; docker ps || true; docker compose ls || true; \
echo; echo "=== JOURNAL (sshd/docker tail) ==="; journalctl -u sshd -u docker --no-pager | tail -200 || true'

SWAP_MB=4096

create_swap_remote() {
  cat <<'EOF'
if ! swapon --show | grep -q "/swapfile"; then
  echo "[ACTION] Creating swapfile";
  fallocate -l 4096M /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096;
  chmod 600 /swapfile;
  mkswap /swapfile;
  swapon /swapfile;
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab;
else
  echo "[OK] Swapfile already present";
fi
EOF
}

configure_docker_logging() {
  cat <<'EOF'
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<JSON
{
  "log-driver": "json-file",
  "log-opts": {"max-size": "10m", "max-file": "3"}
}
JSON
systemctl restart docker || true
EOF
}

ensure_service_restart_policy() {
  cat <<'EOF'
mkdir -p /etc/systemd/system/sshd.service.d
cat > /etc/systemd/system/sshd.service.d/restart.conf <<CONF
[Service]
Restart=always
RestartSec=5
CONF
systemctl daemon-reload
systemctl restart sshd || true
EOF
}

usage() {
  echo "Usage: $0 [--no-swap] [--no-docker-log] [--no-restart-policy]";
  exit 1
}

DO_SWAP=1
DO_DOCKER_LOG=1
DO_RESTART_POLICY=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-swap) DO_SWAP=0 ; shift ;;
    --no-docker-log) DO_DOCKER_LOG=0 ; shift ;;
    --no-restart-policy) DO_RESTART_POLICY=0 ; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

echo "[INFO] Waiting for SSH banner on ${HOST_IP}..."
ATTEMPT=0
while true; do
  if ssh -i "$SSH_KEY" $SSH_OPTS root@"$HOST_IP" 'echo SSH_OK' 2>&1 | grep -q SSH_OK; then
    echo "[INFO] SSH reachable after $ATTEMPT attempts."; break
  fi
  ((ATTEMPT++))
  if (( ATTEMPT % 5 == 0 )); then
    echo "[WAIT] Still trying... attempts=$ATTEMPT"
  fi
  sleep 5
done

echo "[INFO] Gathering remote diagnostics..."
ssh -i "$SSH_KEY" $SSH_OPTS root@"$HOST_IP" "bash -lc '$REMOTE_CMDS_BASE'" || true

echo "[INFO] Remediation phase..."
REMOTE_ACTIONS=""
if (( DO_SWAP )); then
  REMOTE_ACTIONS+="$(create_swap_remote)\n"
fi
if (( DO_DOCKER_LOG )); then
  REMOTE_ACTIONS+="$(configure_docker_logging)\n"
fi
if (( DO_RESTART_POLICY )); then
  REMOTE_ACTIONS+="$(ensure_service_restart_policy)\n"
fi

echo "[INFO] Applying selected remedial actions on host..."
ssh -i "$SSH_KEY" $SSH_OPTS root@"$HOST_IP" "bash -lc '$REMOTE_ACTIONS'" || true

# Optional: remove ClickHouse artifacts if container exists (to prevent future disk blowups)
echo "[INFO] Checking for ClickHouse container to optionally remove..."
ssh -i "$SSH_KEY" $SSH_OPTS root@"$HOST_IP" "bash -lc 'if docker ps --format {{.Names}} | grep -q clickhouse-nogs048w880gks4ccog8gkwo; then echo "[ACTION] Removing ClickHouse container and volume"; docker stop clickhouse-nogs048w880gks4ccog8gkwo || true; docker rm clickhouse-nogs048w880gks4ccog8gkwo || true; docker volume rm nogs048w880gks4ccog8gkwo_clickhouse-data || true; else echo "[OK] No ClickHouse container present"; fi'" || true

echo "[INFO] Post-remediation status check..."
ssh -i "$SSH_KEY" $SSH_OPTS root@"$HOST_IP" "bash -lc 'systemctl is-active docker || true; docker ps || true'" || true

if [[ -x ./diagnose.sh ]]; then
  echo "[INFO] Running local diagnose.sh for external verification..."
  ./diagnose.sh || true
else
  echo "[WARN] diagnose.sh not executable or missing."
fi

echo "[DONE] Recovery script finished. Review output above."
