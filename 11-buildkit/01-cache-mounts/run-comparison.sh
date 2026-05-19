#!/bin/bash
# วัดเวลา rebuild ของ Dockerfile แบบมี/ไม่มี cache mount
#
# กลไก:
#   1. Cold build ทั้งคู่ — ดาวน์โหลด apt + pip จาก network
#   2. แก้ requirements.txt (เพิ่ม comment) → invalidate "RUN pip install" layer
#      ทำให้ Docker layer cache ใช้ไม่ได้ ต้องรัน pip install ใหม่
#   3. Warm build:
#        - no-cache:  pip ต้องดาวน์โหลด wheels ใหม่จาก PyPI ทั้งหมด
#        - cache:     pip หา wheels ใน /root/.cache/pip ที่ mount ไว้ → ติดตั้งทันที
set -euo pipefail

cd "$(dirname "$0")/app"

NOCACHE_TAG=lab-buildkit-nocache:test
CACHE_TAG=lab-buildkit-cache:test

measure() {
    local label=$1; shift
    local start end
    start=$(date +%s.%N)
    "$@" >/dev/null 2>&1
    end=$(date +%s.%N)
    printf "  %s: %ss\n" "$label" "$(awk "BEGIN{printf \"%.2f\", $end - $start}")"
}

echo "=========================================="
echo "[1/3] ลบ builder cache ทั้งหมด (cold start)"
echo "=========================================="
docker buildx prune -af >/dev/null 2>&1 || true
docker rmi -f "$NOCACHE_TAG" "$CACHE_TAG" 2>/dev/null || true

echo ""
echo "=========================================="
echo "[2/3] Build #1 (cold) — ดาวน์โหลดจาก network ทั้งคู่"
echo "=========================================="
measure "no-cache (cold)" docker build -f Dockerfile.no-cache -t "$NOCACHE_TAG" .
measure "cache    (cold)" docker build -f Dockerfile.cache    -t "$CACHE_TAG"   .

echo ""
echo "=========================================="
echo "[3/3] แก้ requirements.txt → invalidate pip layer → rebuild"
echo "=========================================="
echo "# bump-$(date +%s)" >> requirements.txt
echo "requirements.txt: ต่อท้าย comment เพื่อเปลี่ยน hash"

echo ""
echo "▶ Warm build (RUN pip install ต้องรันใหม่):"
measure "no-cache (warm — ดาวน์โหลด PyPI ใหม่)" docker build -f Dockerfile.no-cache -t "$NOCACHE_TAG" .
measure "cache    (warm — ใช้ wheels จาก cache mount)" docker build -f Dockerfile.cache -t "$CACHE_TAG" .

# คืน requirements.txt
sed -i '/^# bump-/d' requirements.txt

echo ""
echo "✅ เสร็จแล้ว — เทียบเวลา warm build:"
echo "   ตัว 'no-cache' ดาวน์โหลด wheels จาก PyPI ทุกครั้งที่ layer invalidate"
echo "   ตัว 'cache'   หยิบจาก /root/.cache/pip ที่ persist ข้าม build"
