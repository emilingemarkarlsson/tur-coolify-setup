# Scripts

Operational automation scripts for The Unnamed Roads infrastructure.

## Diagnostics & Monitoring

### `quick-ssh.sh`

Quick health check for the Coolify server. Displays:

- Server connectivity status
- Disk usage
- Memory and swap status
- Docker status
- Container count

**Usage**:

```bash
./scripts/quick-ssh.sh
```

### `diagnose.sh`

External endpoint verification. Tests:

- DNS resolution for all domains
- HTTPS connectivity
- SSL certificate validity
- Response times

**Usage**:

```bash
./scripts/diagnose.sh
```

### `quick-test.sh`

Quick test suite for verifying service endpoints.

**Usage**:

```bash
./scripts/quick-test.sh
```

## Maintenance

### `docker-cleanup.sh`

Removes unused Docker resources to free up disk space:

- Stopped containers
- Unused images
- Dangling volumes
- Build cache

**Usage**:

```bash
./scripts/docker-cleanup.sh
```

**⚠️ Warning**: This will remove ALL unused Docker resources. Make sure you have backups of important data.

### `post-reboot-recover.sh`

Recovery script to run after server reboot. Ensures:

- Docker daemon is running
- All services are restarted
- Health checks pass

**Usage**:

```bash
./scripts/post-reboot-recover.sh
```

## Environment Validation

### `validate-env.sh`

Validates `.env` file before deployment. Checks for:

- Missing required variables
- CHANGEME placeholders
- Empty values

**Usage**:

```bash
./scripts/validate-env.sh
```

**Exit codes**:

- `0` - All checks passed
- `1` - Missing .env file
- `2` - Validation failed (missing or placeholder values)

## Best Practices

1. **Always run diagnostics** before making infrastructure changes
2. **Use quick-ssh.sh daily** to catch issues early
3. **Run docker-cleanup.sh monthly** to prevent disk space issues
4. **Validate environment** with validate-env.sh before deploying new services
5. **Keep scripts executable**: `chmod +x scripts/*.sh`
