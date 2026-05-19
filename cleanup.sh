#!/bin/sh
# ใช้ก่อนเริ่ม lab ใหม่ — เคลียทุก resource จาก lab ก่อนหน้า
# ⚠️ จะลบ containers, networks, volumes ที่ไม่มี container ใช้

set -e

echo "[1/5] stop + remove ทุก container..."
docker ps -aq | xargs -r docker rm -f >/dev/null

echo "[2/5] remove networks (ยกเว้น default)..."
docker network ls --filter type=custom -q | xargs -r docker network rm >/dev/null 2>&1 || true

echo "[3/5] remove anonymous + unused volumes..."
docker volume prune -f >/dev/null

echo "[4/5] remove dangling images..."
docker image prune -f >/dev/null

echo "[5/5] สรุป disk usage หลังเคลีย:"
docker system df

echo ""
echo "✅ พร้อมเริ่ม lab ใหม่"
