#!/usr/bin/env bash
set -euo pipefail

# check-minio-storage.sh - Kolla var MinIO sparar data och hur mycket utrymme det tar

HOST="${1:-tha}"

echo "📦 MinIO Storage Check"
echo "====================="
echo ""

ssh "$HOST" bash <<'REMOTE'
set +u

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Find MinIO container
MINIO_CONTAINER=$(docker ps --filter "name=minio" --format '{{.Names}}' 2>/dev/null | head -1)

if [ -z "$MINIO_CONTAINER" ]; then
    echo "❌ MinIO container hittades inte"
    echo ""
    echo "Körs MinIO? Kontrollera:"
    echo "  docker ps -a | grep minio"
    exit 1
fi

echo "✅ MinIO container: ${MINIO_CONTAINER}"
echo ""

# ============================================================================
# 1. VOLUME INFORMATION
# ============================================================================
echo "💾 Volume Information"
echo "─────────────────────"

# Get volume name
VOLUME_NAME=$(docker inspect "$MINIO_CONTAINER" --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Name}}{{end}}{{end}}' 2>/dev/null || echo "")

if [ -z "$VOLUME_NAME" ]; then
    echo "❌ Kunde inte hitta volume"
    exit 1
fi

echo "  Volume name: ${VOLUME_NAME}"

# Get volume mount point on host
VOLUME_MOUNT=$(docker volume inspect "$VOLUME_NAME" --format '{{.Mountpoint}}' 2>/dev/null || echo "")

if [ -n "$VOLUME_MOUNT" ]; then
    echo "  Mount point: ${VOLUME_MOUNT}"
    echo ""
    
    # Get size of volume
    if [ -d "$VOLUME_MOUNT" ]; then
        VOLUME_SIZE=$(du -sh "$VOLUME_MOUNT" 2>/dev/null | awk '{print $1}')
        VOLUME_SIZE_BYTES=$(du -sb "$VOLUME_MOUNT" 2>/dev/null | awk '{print $1}')
        echo "  📊 Total storlek: ${VOLUME_SIZE}"
        
        # Show breakdown if possible
        echo ""
        echo "  📁 Innehåll breakdown:"
        if [ -d "$VOLUME_MOUNT" ]; then
            # List top-level directories
            find "$VOLUME_MOUNT" -maxdepth 1 -type d ! -path "$VOLUME_MOUNT" | while read -r dir; do
                DIR_NAME=$(basename "$dir")
                DIR_SIZE=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
                echo "    • ${DIR_NAME}: ${DIR_SIZE}"
            done
            
            # Count files
            FILE_COUNT=$(find "$VOLUME_MOUNT" -type f 2>/dev/null | wc -l)
            DIR_COUNT=$(find "$VOLUME_MOUNT" -type d 2>/dev/null | wc -l)
            echo ""
            echo "  📈 Statistik:"
            echo "    Filer: ${FILE_COUNT}"
            echo "    Mappar: ${DIR_COUNT}"
        fi
    else
        echo "  ⚠️  Mount point finns inte: ${VOLUME_MOUNT}"
    fi
else
    echo "  ⚠️  Kunde inte hitta mount point"
fi

echo ""

# ============================================================================
# 2. DOCKER VOLUME SIZE (via docker system df)
# ============================================================================
echo "🐳 Docker Volume Size"
echo "─────────────────────"

# Try to get size from docker system df
VOLUME_SIZE_DF=$(docker system df -v 2>/dev/null | grep -A 5 "VOLUME NAME" | grep "$VOLUME_NAME" | awk '{print $3}' || echo "")

if [ -n "$VOLUME_SIZE_DF" ]; then
    echo "  Storlek (via docker): ${VOLUME_SIZE_DF}"
else
    echo "  ℹ️  Kör 'docker system df -v' för detaljerad info"
fi

echo ""

# ============================================================================
# 3. CONTAINER VOLUME MAPPING
# ============================================================================
echo "🔗 Container Volume Mapping"
echo "───────────────────────────"

docker inspect "$MINIO_CONTAINER" --format '{{range .Mounts}}{{if eq .Destination "/data"}}  Source: {{.Source}}{{"\n"}}  Destination: {{.Destination}}{{"\n"}}  Type: {{.Type}}{{end}}{{end}}' 2>/dev/null || echo "  Kunde inte hämta mapping"

echo ""

# ============================================================================
# 4. MINIO BUCKETS (if accessible)
# ============================================================================
echo "🪣 MinIO Buckets"
echo "───────────────"

# Try to list buckets using MinIO client (mc) inside container
if docker exec "$MINIO_CONTAINER" mc --version >/dev/null 2>&1; then
    echo "  Försöker lista buckets..."
    
    # Try to list buckets (this might fail if credentials are needed)
    BUCKETS=$(docker exec "$MINIO_CONTAINER" mc ls local 2>/dev/null | awk '{print $5}' | grep -v "^$" || echo "")
    
    if [ -n "$BUCKETS" ]; then
        echo "  Hittade buckets:"
        echo "$BUCKETS" | while read -r bucket; do
            if [ -n "$bucket" ]; then
                echo "    • ${bucket}"
                
                # Try to get bucket size (might require credentials)
                BUCKET_SIZE=$(docker exec "$MINIO_CONTAINER" mc du "local/${bucket}" 2>/dev/null | tail -1 | awk '{print $1}' || echo "N/A")
                if [ "$BUCKET_SIZE" != "N/A" ] && [ -n "$BUCKET_SIZE" ]; then
                    echo "      Storlek: ${BUCKET_SIZE}"
                fi
            fi
        done
    else
        echo "  ℹ️  Kunde inte lista buckets (kräver autentisering eller inga buckets ännu)"
        echo "     Logga in på MinIO Console för att se buckets"
    fi
else
    echo "  ℹ️  MinIO client (mc) inte tillgänglig i container"
fi

echo ""

# ============================================================================
# 5. DISK SPACE ON HOST
# ============================================================================
echo "💿 Disk Space (Host)"
echo "────────────────────"

if [ -n "$VOLUME_MOUNT" ] && [ -d "$VOLUME_MOUNT" ]; then
    # Get filesystem info for the mount point
    FS_INFO=$(df -h "$VOLUME_MOUNT" 2>/dev/null | tail -1)
    FS_USED=$(echo "$FS_INFO" | awk '{print $3}')
    FS_AVAIL=$(echo "$FS_INFO" | awk '{print $4}')
    FS_TOTAL=$(echo "$FS_INFO" | awk '{print $2}')
    FS_PERCENT=$(echo "$FS_INFO" | awk '{print $5}' | sed 's/%//')
    
    echo "  Filesystem: ${FS_TOTAL} totalt"
    echo "  Använt: ${FS_USED}"
    echo "  Tillgängligt: ${FS_AVAIL}"
    echo "  Användning: ${FS_PERCENT}%"
    
    if [ "$FS_PERCENT" -gt 90 ]; then
        echo -e "  ${YELLOW}⚠️  KRITISKT: Lågt utrymme!${NC}"
    elif [ "$FS_PERCENT" -gt 80 ]; then
        echo -e "  ${YELLOW}⚠️  Varning: Högt utrymme använt${NC}"
    fi
fi

echo ""

# ============================================================================
# SUMMARY
# ============================================================================
echo "📊 Summary"
echo "──────────"
echo ""
echo "  MinIO container: ${MINIO_CONTAINER}"
if [ -n "$VOLUME_NAME" ]; then
    echo "  Volume: ${VOLUME_NAME}"
fi
if [ -n "$VOLUME_MOUNT" ] && [ -d "$VOLUME_MOUNT" ]; then
    echo "  Data location: ${VOLUME_MOUNT}"
    echo "  Total storlek: ${VOLUME_SIZE}"
fi
echo ""
echo "💡 Tips:"
echo "  • Se MinIO Console för bucket-detaljer: MinIO service URL + /console"
echo "  • Rensa gamla filer: Logga in på MinIO Console → Buckets → Ta bort filer"
echo "  • Backup: Kopiera ${VOLUME_MOUNT} till backup-location"
echo "  • Se alla Docker volumes: docker volume ls"
echo "  • Se detaljerad disk usage: docker system df -v"
REMOTE

echo ""
echo "✅ Check klar!"

