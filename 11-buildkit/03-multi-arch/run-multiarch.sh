#!/bin/bash
# สาธิตการ build image เดียวให้รันได้ทั้ง linux/amd64 และ linux/arm64
# โดยใช้ local registry บน localhost:5000 (ไม่ต้องการ Docker Hub)
set -euo pipefail

REGISTRY=localhost:5000
IMAGE="$REGISTRY/multiarch-demo:v1"
BUILDER=lab-multiarch-builder
APP_DIR="$(dirname "$0")/app"

echo "════════════════════════════════════════════════════════════════"
echo "[1/7] เปิด local registry (localhost:5000)"
echo "════════════════════════════════════════════════════════════════"
if ! docker ps --format '{{.Names}}' | grep -q '^lab-multiarch-registry$'; then
    docker run -d --rm --name lab-multiarch-registry -p 5000:5000 registry:2 >/dev/null
fi
sleep 1
echo "✅ registry up"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "[2/6] ติดตั้ง QEMU binfmt emulators (เพื่อรัน arm64 บน amd64 host)"
echo "════════════════════════════════════════════════════════════════"
docker run --privileged --rm tonistiigi/binfmt:qemu-v8.1.5 --install arm64 >/dev/null 2>&1 || true
echo "✅ binfmt registered"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "[3/6] สร้าง buildx builder (driver: docker-container)"
echo "════════════════════════════════════════════════════════════════"
# default builder ใช้ docker driver — multi-arch ไม่ได้ ต้อง docker-container driver
if ! docker buildx ls | grep -q "$BUILDER"; then
    docker buildx create \
        --name "$BUILDER" \
        --driver docker-container \
        --driver-opt network=host \
        --use >/dev/null
fi
docker buildx use "$BUILDER"
docker buildx inspect --bootstrap >/dev/null
echo "✅ builder พร้อม"
docker buildx ls | grep -A 1 "$BUILDER" || true

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "[4/7] Build multi-arch image แล้ว push ขึ้น local registry"
echo "════════════════════════════════════════════════════════════════"
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --tag "$IMAGE" \
    --push \
    "$APP_DIR"
echo "✅ build + push เสร็จ"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "[5/7] ดู manifest (manifest list ที่ index หลายๆ architecture)"
echo "════════════════════════════════════════════════════════════════"
docker buildx imagetools inspect "$IMAGE"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "[6/7] Pull + run arch ของเครื่องนี้ (เลือก variant ให้อัตโนมัติ)"
echo "════════════════════════════════════════════════════════════════"
docker pull "$IMAGE" >/dev/null
docker rm -f multiarch-test 2>/dev/null || true
docker run -d --rm -p 18080:8080 --name multiarch-test "$IMAGE" >/dev/null
sleep 2
curl -s http://localhost:18080/
docker rm -f multiarch-test >/dev/null

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "[7/7] Pull arm64 variant แล้วลองรัน (ใช้ QEMU emulation จากขั้น [2])"
echo "════════════════════════════════════════════════════════════════"
docker pull --platform linux/arm64 "$IMAGE" >/dev/null
docker run -d --rm --platform linux/arm64 -p 18081:8080 --name multiarch-arm64 "$IMAGE" >/dev/null
sleep 3
curl -s http://localhost:18081/
docker rm -f multiarch-arm64 >/dev/null

echo ""
echo "✅ เสร็จแล้ว — สังเกตค่า 'architecture' ของ 2 ครั้งที่รัน ต่างกัน"
echo ""
echo "🧹 ลบ registry + builder:"
echo "   docker rm -f lab-multiarch-registry"
echo "   docker buildx rm $BUILDER"
