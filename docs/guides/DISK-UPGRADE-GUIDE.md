# Hetzner Disk Upgrade Guide

## Option 1: Resize Current Disk (Rekommenderat)
1. Gå till Hetzner Cloud Console
2. Välj din server
3. Gå till "Volumes" eller "Storage" 
4. Resize till 150GB-200GB
5. Starta om servern
6. Expandera filesystemet:
   ```bash
   resize2fs /dev/sda1
   ```

## Option 2: Lägg till Extra Volume
1. Skapa nytt volume (100GB)
2. Attach till servern  
3. Montera på /data/clickhouse
4. Flytta ClickHouse data dit

## Cost Comparison:
- 75GB → 150GB: ~€3-5/månad extra
- Extra 100GB volume: ~€5/månad

## Immediate Actions:
1. Resize to 150GB (tar ~5min)
2. Restart server
3. Run: resize2fs /dev/sda1
4. Verify: df -h