#!/bin/bash

# Docker Disk Space Monitor & Cleanup
# Run this weekly via cron

DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
LOG_FILE="/var/log/docker-cleanup.log"

echo "$(date): Disk usage at ${DISK_USAGE}%" >> $LOG_FILE

# If disk usage > 80%, start cleanup
if [ $DISK_USAGE -gt 80 ]; then
    echo "$(date): Disk usage high (${DISK_USAGE}%), starting cleanup..." >> $LOG_FILE
    
    # Remove unused containers, networks, images
    docker system prune -f >> $LOG_FILE 2>&1
    
    # Remove unused volumes (BE CAREFUL - this removes data!)
    # docker volume prune -f >> $LOG_FILE 2>&1
    
    # Clean logs older than 7 days
    journalctl --vacuum-time=7d >> $LOG_FILE 2>&1
    
    # Check disk usage after cleanup
    NEW_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    echo "$(date): Cleanup completed. Usage: ${DISK_USAGE}% -> ${NEW_USAGE}%" >> $LOG_FILE
fi