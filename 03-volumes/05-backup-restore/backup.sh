#!/bin/bash
set -euo pipefail

mkdir -p backups

BACKUP_FILE="backups/backup_$(date +%Y%m%d_%H%M%S).sql"

echo "Starting backup..."

# ใช้ docker compose exec -T (no TTY) เพื่อ pipe output ออกมาได้สะอาด
# ไม่ผูกกับ container_name — ใช้ service name ของ compose แทน
docker compose exec -T db pg_dump -U user -d mydatabase --clean --if-exists > "$BACKUP_FILE"

echo "✅ Backup successful: $BACKUP_FILE"
