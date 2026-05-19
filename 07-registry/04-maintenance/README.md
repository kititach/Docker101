# Lab 04 — Delete & Garbage Collection

## Objective

ลบ image ที่ไม่ต้องการแล้ว reclaim disk space — สำคัญสำหรับ registry ที่รันนาน ๆ

---

## ทำไม Registry กิน Disk เพิ่มทุกวัน

```
push v1.0   → layer A + B + C → disk +50MB
push v1.1   → layer A + B + C' → disk +20MB (เฉพาะ C' ใหม่)
push v1.2   → layer A + B + C'' → disk +20MB

แม้ลบ tag v1.0 — layer C ยังอยู่บน disk (ถ้าไม่ run GC)
```

Registry **content-addressed** + **immutable** — ลบเฉพาะ tag pointer ไม่ลบ blob

---

## ผลวัดจริง

```
Before delete + GC:  10.3 MB
After delete + GC:   7.0 MB
Reclaimed:           ~3.3 MB (32%)
```

---

## Step 1 — Setup Registry พร้อม DELETE Enabled

`REGISTRY_STORAGE_DELETE_ENABLED=true` **จำเป็น** — default ปิด:

```yaml
# compose.yaml
environment:
  REGISTRY_STORAGE_DELETE_ENABLED: "true"
```

```bash
docker compose up -d
```

---

## Step 2 — Push หลาย Version

```bash
# pull alpine หลาย version แล้ว push เข้า registry
for v in 3.18 3.19 3.20; do
  docker pull -q alpine:$v
  docker tag alpine:$v localhost:5000/myapp:$v
  docker push -q localhost:5000/myapp:$v
done

curl -s http://localhost:5000/v2/myapp/tags/list
# {"name":"myapp","tags":["3.20","3.18","3.19"]}
```

---

## Step 3 — ลบ Tag ผ่าน API

API ต้องการ **digest** ของ manifest ไม่ใช่ tag name

**ขั้นที่ 1: ดึง digest จาก HEAD request**

```bash
DIGEST=$(curl -sI \
  -H "Accept: application/vnd.oci.image.manifest.v1+json" \
  -H "Accept: application/vnd.oci.image.index.v1+json" \
  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  http://localhost:5000/v2/myapp/manifests/3.18 \
  | grep -i "docker-content-digest" | awk '{print $2}' | tr -d '\r\n')

echo "digest: $DIGEST"
# digest: sha256:fd032399cd767f310a1d1274e81cab9f0fd8a49b3589eba2c3420228cd45b6a7
```

> **สำคัญ:** Alpine 3.18+ ใช้ OCI image index (multi-arch) — Accept header ต้องครอบคลุมทุก format

**ขั้นที่ 2: DELETE**

```bash
curl -sX DELETE -w "HTTP %{http_code}\n" \
  http://localhost:5000/v2/myapp/manifests/$DIGEST
# HTTP 202

# ตรวจสอบ — tag 3.18 หายแล้ว
curl -s http://localhost:5000/v2/myapp/tags/list
# {"name":"myapp","tags":["3.20","3.19"]}
```

> HTTP **202 Accepted** = manifest unreferenced แต่ **blob ยังอยู่บน disk**

---

## Step 4 — ดู Disk ก่อน GC

```bash
docker exec lab07-maint du -sh /var/lib/registry
# 10.3M    /var/lib/registry
```

ลบ tag แล้ว แต่ disk เท่าเดิม — ต้อง garbage collect

---

## Step 5 — Garbage Collect

```bash
docker exec lab07-maint registry garbage-collect \
  -m /etc/docker/registry/config.yml
```

`-m` = run in delete mode (ไม่มี = dry-run แสดงว่าจะลบอะไร)

ผล:
```
myapp: marking manifest sha256:c64...
myapp: marking blob sha256:25f...
...
6 blobs marked, 3 blobs and 0 manifests eligible for deletion
blob eligible for deletion: sha256:fd03...
blob eligible for deletion: sha256:44cf...
blob eligible for deletion: sha256:802c...
```

ตรวจสอบ disk หลัง GC:
```bash
docker exec lab07-maint du -sh /var/lib/registry
# 7.0M    /var/lib/registry  ← ลดลง 3.3 MB
```

---

## Step 6 — GC Mode: Read-Only Mode (Production)

GC ต้องการ registry ไม่ accept push ระหว่างทำงาน — มิฉะนั้น layer ที่ upload อยู่อาจถูกลบ

วิธีที่ปลอดภัยใน production:

```bash
# 1. ตั้ง registry เป็น read-only
docker compose exec registry \
  sh -c 'export REGISTRY_STORAGE_MAINTENANCE_READONLY=true; reload'

# หรือ restart พร้อม env var
# REGISTRY_STORAGE_MAINTENANCE_READONLY: '{enabled: true}'

# 2. run GC
docker compose exec registry registry garbage-collect -m /etc/docker/registry/config.yml

# 3. เปิด push กลับมา
```

---

## Step 7 — Automate Cleanup: Retention Policy

registry ไม่มี built-in retention — ต้องเขียน script เอง

ตัวอย่าง: ลบ tag ที่ไม่ใช่ N ตัวล่าสุด

```bash
#!/bin/sh
REPO=myapp
KEEP=5

# ดึง tags เรียงตามวันที่
TAGS=$(curl -s http://localhost:5000/v2/$REPO/tags/list | jq -r '.tags[]' | tail -n +$((KEEP+1)))

for tag in $TAGS; do
  DIGEST=$(curl -sI -H "Accept: application/vnd.oci.image.manifest.v1+json" \
    http://localhost:5000/v2/$REPO/manifests/$tag \
    | grep -i docker-content-digest | awk '{print $2}' | tr -d '\r\n')
  curl -X DELETE http://localhost:5000/v2/$REPO/manifests/$DIGEST
done
```

Harbor, Quay, GitLab Container Registry มี retention policy ในตัว

---

## Cleanup

```bash
docker compose down -v
```

---

## Maintenance Checklist

```
□ REGISTRY_STORAGE_DELETE_ENABLED=true ใน config
□ Delete ผ่าน API → ลบ tag/manifest
□ GC → reclaim disk จาก orphan blobs
□ Read-only mode ก่อน GC (production)
□ Schedule GC เป็น cron job (เช่นทุกสัปดาห์)
□ Retention policy ลบ tag เก่าอัตโนมัติ
□ Monitor disk usage — registry คือ stateful service ต้อง backup
```
