#!/bin/bash
set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: ./restore.sh <path_to_backup_file.sql>"
    exit 1
fi

BACKUP_FILE=$1

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ File not found: $BACKUP_FILE"
    exit 1
fi

echo "Restoring database from $BACKUP_FILE..."

# ON_ERROR_STOP=1      → เจอ error บรรทัดเดียวก็หยุด ไม่รันต่อแบบครึ่งๆ กลางๆ
# --single-transaction → ห่อทั้งไฟล์ใน BEGIN/COMMIT — error เมื่อไหร่ rollback ทั้งหมด
# set -e ด้านบนจะทำให้ exit code ของ psql ส่งต่อมาได้ตรงๆ
cat "$BACKUP_FILE" | docker compose exec -T db \
    psql -U user -d mydatabase \
    -v ON_ERROR_STOP=1 \
    --single-transaction

echo "✅ Restore completed successfully."
