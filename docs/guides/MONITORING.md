# Monitoring Setup Guide

## Automated Health Monitoring

### Overview
Keep track of server health and get notified before issues become critical.

## Quick Scripts

### 1. Quick SSH Health Check
**File**: `quick-ssh.sh`

**Usage**:
```bash
./quick-ssh.sh
```

**What it checks**:
- SSH connectivity
- Disk usage (warns if >80%)
- Memory and swap status
- Docker daemon health
- Container count

**When to use**: Daily spot checks, before/after deployments

### 2. Full Diagnostics
**File**: `diagnose.sh`

**Usage**:
```bash
./diagnose.sh
```

**What it checks**:
- DNS resolution for all domains
- HTTPS connectivity to services
- Server network reachability
- Coolify dashboard access

**When to use**: After DNS changes, SSL issues, external access problems

### 3. Post-Reboot Recovery
**File**: `post-reboot-recover.sh`

**Usage**:
```bash
./post-reboot-recover.sh
```

**What it does**:
- Waits for SSH to become available
- Gathers comprehensive diagnostics
- Creates swap if missing
- Configures Docker log limits
- Sets up service auto-restart
- Removes problematic containers (optional)

**When to use**: After server reboot, OOM events, rescue mode recovery

## Server Resource Monitoring

### Check Current Status
```bash
# Comprehensive status
./quick-ssh.sh

# Just disk usage
ssh tha 'df -h /'

# Memory + swap
ssh tha 'free -h'

# Docker resource usage
ssh tha 'docker system df'
```

### Historical Logs
```bash
# System logs (OOM kills, crashes)
ssh tha 'dmesg | tail -100'

# Docker service logs
ssh tha 'journalctl -u docker --since "1 hour ago"'

# Specific container logs
ssh tha 'docker logs --tail 100 <container-name>'
```

## Alert Thresholds

### Critical Issues (Immediate Action Required)
- Disk usage >90%
- Memory usage >95% with no swap
- Docker daemon stopped
- All containers down
- SSH unresponsive

### Warning Signs (Monitor Closely)
- Disk usage >70%
- Memory usage >80%
- Single service down
- High load average (>4.0)
- Swap in use

### Normal Operations
- Disk usage 20-50%
- Memory usage 30-70%
- All containers healthy
- Load average <1.0

## Setting Up Automated Monitoring

### Option 1: Simple Cron Job (Local)

Create `~/monitor-tha.sh`:
```bash
#!/bin/bash
cd /path/to/tur-coolify-setup
./quick-ssh.sh > /tmp/tha-status.txt 2>&1

# Check for critical issues
if grep -q "❌" /tmp/tha-status.txt; then
  echo "THA Server Issues Detected!"
  cat /tmp/tha-status.txt
  # Optional: Send email/notification here
fi
```

Add to crontab:
```bash
crontab -e
# Add line:
*/30 * * * * /Users/emilkarlsson/monitor-tha.sh
```

### Option 2: Server-Side Monitoring (Netdata)

Deploy Netdata via Coolify:
```yaml
# netdata/docker-compose.yml
version: '3.8'
services:
  netdata:
    image: netdata/netdata:latest
    hostname: tha-coolify
    cap_add:
      - SYS_PTRACE
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined
    volumes:
      - netdataconfig:/etc/netdata
      - netdatalib:/var/lib/netdata
      - netdatacache:/var/cache/netdata
      - /etc/passwd:/host/etc/passwd:ro
      - /etc/group:/host/etc/group:ro
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.netdata.rule=Host(`monitor.thehockeyanalytics.com`)"
      - "traefik.http.services.netdata.loadbalancer.server.port=19999"

volumes:
  netdataconfig:
  netdatalib:
  netdatacache:
```

### Option 3: External Monitoring (UptimeRobot/Hetrix)

Free services that ping your endpoints:
- **UptimeRobot**: https://uptimerobot.com (50 monitors free)
- **Hetrix Tools**: https://hetrixtools.com (15 monitors free)

Monitor:
- `https://coolify.theunnamedroads.com` (every 5 min)
- `https://analytics.thehockeyanalytics.com` (every 5 min)

## Docker Container Health

### View All Container Status
```bash
ssh tha 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"'
```

### Check Specific Service Logs
```bash
# Last 100 lines
ssh tha 'docker logs --tail 100 coolify'

# Follow logs (Ctrl+C to exit)
ssh tha 'docker logs -f coolify'

# Last hour with timestamps
ssh tha 'docker logs --since 1h -t coolify'
```

### Inspect Container Health
```bash
ssh tha 'docker inspect coolify | grep -A 10 Health'
```

## Disk Space Management

### Automated Cleanup (Server-Side)

Create `/root/cleanup-docker.sh` on server:
```bash
#!/bin/bash
DISK_USAGE=$(df / | awk 'NR==2 {print int($5)}')

if [ $DISK_USAGE -gt 70 ]; then
  echo "Disk usage at ${DISK_USAGE}%, running cleanup..."
  docker system prune -f
  docker volume prune -f
  echo "Cleanup completed"
fi
```

Add to crontab on server:
```bash
ssh tha 'crontab -e'
# Add:
0 2 * * * /root/cleanup-docker.sh >> /var/log/docker-cleanup.log 2>&1
```

## Notification Setup (Optional)

### Email Alerts via Mailgun/SendGrid

Add to monitoring script:
```bash
send_alert() {
  curl -s --user "api:YOUR_MAILGUN_KEY" \
    https://api.mailgun.net/v3/YOUR_DOMAIN/messages \
    -F from="THA Monitor <monitor@yourdomain.com>" \
    -F to="your@email.com" \
    -F subject="THA Server Alert" \
    -F text="$1"
}

if grep -q "❌" /tmp/tha-status.txt; then
  send_alert "$(cat /tmp/tha-status.txt)"
fi
```

### Slack Notifications

```bash
send_slack() {
  curl -X POST YOUR_WEBHOOK_URL \
    -H 'Content-Type: application/json' \
    -d "{\"text\":\"$1\"}"
}

send_slack "THA Server: Critical issue detected"
```

## Best Practices

1. **Run quick-ssh.sh daily** (manually or automated)
2. **Full diagnose.sh after any infrastructure change**
3. **Monitor disk usage trend** - if growing steadily, investigate
4. **Keep swap active** - early warning for memory pressure
5. **Review logs weekly** for patterns/warnings
6. **Test recovery procedures monthly** - ensure scripts work
7. **Document any manual fixes** in service README
8. **Keep backup of working configs** before changes

## Emergency Contacts

- **Hetzner Support**: https://console.hetzner.cloud (for server access)
- **Cloudflare Dashboard**: https://dash.cloudflare.com (for DNS/SSL)
- **Coolify Docs**: https://coolify.io/docs (for platform issues)

## Common Monitoring Commands Cheatsheet

```bash
# Server health
./quick-ssh.sh                           # Quick snapshot
ssh tha 'top -b -n1 | head -20'         # CPU/memory processes
ssh tha 'iostat -x 1 3'                 # Disk I/O

# Docker
ssh tha 'docker stats --no-stream'      # Container resource usage
ssh tha 'docker ps -a'                  # All containers (including stopped)
ssh tha 'docker system df -v'           # Detailed disk usage

# Logs
ssh tha 'journalctl -xe | tail -50'     # System logs
ssh tha 'dmesg -T | tail -50'           # Kernel messages

# Network
ssh tha 'ss -tulpn'                     # Open ports
ssh tha 'netstat -s'                    # Network statistics
```
