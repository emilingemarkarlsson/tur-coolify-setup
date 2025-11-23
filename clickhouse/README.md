# ClickHouse Service

Docker Compose configuration for ClickHouse deployment with disk space optimization.

## Important Notes

This configuration includes profiling disabled to prevent disk space issues.
The previous installation had 57GB of profiling data that filled the disk.

## Deploy

1. Upload both `docker-compose.yml` and `config.xml` to Coolify
2. Configure environment variables
3. Deploy the service

## Features

- Profiling disabled to save disk space
- Minimal logging configuration  
- TTL settings for system logs
- Production-ready security settings
