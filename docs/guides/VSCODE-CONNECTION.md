# VS Code Connection Guide

## Quick Start

### 1. SSH Config (Already Set Up ✓)

Your `~/.ssh/config` now has:
```
Host tha
    HostName 46.62.206.47
    User root
    IdentityFile ~/.ssh/id_ed25519_coolify
```

### 2. Connect from Terminal
```bash
ssh tha
```

### 3. Connect from VS Code

**Option A: Command Palette (Recommended)**
1. Open VS Code
2. Press `Cmd+Shift+P`
3. Type: `Remote-SSH: Connect to Host`
4. Select `tha`
5. New VS Code window opens connected to server

**Option B: Status Bar**
1. Click green remote icon in bottom-left corner
2. Select `Connect to Host...`
3. Choose `tha`

## Extensions to Install on Remote

Once connected, install these on the server:
- **Docker** - Container management
- **YAML** - Compose file editing
- **GitLens** (optional) - Git visualization

## Quick Scripts

### Health Check
```bash
./quick-ssh.sh
```
Shows: disk, memory, Docker status, container count

### Full Diagnostics
```bash
./diagnose.sh
```
Tests: DNS, HTTPS, Coolify health

### Recovery
```bash
./post-reboot-recover.sh
```
Automated post-reboot diagnostics and fixes

## Docker MCP Integration

GitHub Copilot can now manage Docker directly:
- "Show running containers"
- "Stop container X"
- "List Docker volumes"
- "Inspect container logs for coolify"

## Troubleshooting

### Can't connect via SSH
```bash
ping 46.62.206.47              # Check network
ssh -vvv tha                   # Verbose debug
./quick-ssh.sh                 # Automated check
```

### VS Code "Could not establish connection"
1. Check SSH works: `ssh tha`
2. Check VS Code SSH extension installed
3. Clear remote cache: `Cmd+Shift+P` → `Remote-SSH: Kill VS Code Server on Host`

### Server not responding
See `EMERGENCY-RECOVERY.md` for Hetzner console access
