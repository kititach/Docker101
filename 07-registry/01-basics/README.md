# Lab 01 — Deploy Registry + API

## Objective

รัน private registry แบบ minimal — push image, pull image, และเข้าใจ Registry HTTP API v2 พร้อม storage layout บน disk

---

## Step 1 — Deploy Registry

```bash
docker compose up -d

# ตรวจสอบ
curl http://localhost:5000/v2/
# {}    ← ตอบ JSON object ว่าง = registry พร้อมใช้
```

`{}` คือ minimal response ที่บอกว่า server พูด Registry API v2 ได้

---

## Step 2 — Push Image แรก

```bash
# tag image ที่มีอยู่
docker pull alpine:3.20
docker tag alpine:3.20 localhost:5000/myalpine:1.0

# push
docker push localhost:5000/myalpine:1.0
```

> **สำคัญ:** tag ต้องขึ้นต้นด้วย `host:port/` — Docker ใช้ส่วนนี้รู้ว่าจะ push ไป registry ไหน  
> `alpine:3.20` (ไม่มี host) → push ไป Docker Hub  
> `localhost:5000/myalpine:1.0` → push ไป registry ของเรา

---

## Step 3 — Registry HTTP API v2

ทุก operation ใน registry คือ REST API:

```bash
# list ทุก repository
curl -s http://localhost:5000/v2/_catalog
# {"repositories":["myalpine"]}

# list tags ของ repository
curl -s http://localhost:5000/v2/myalpine/tags/list
# {"name":"myalpine","tags":["1.0"]}

# ดู manifest (ต้องระบุ Accept header)
curl -s -H "Accept: application/vnd.oci.image.manifest.v1+json" \
  http://localhost:5000/v2/myalpine/manifests/1.0 | python3 -m json.tool | head -10

# ดู digest ของ manifest (จาก response header)
curl -sI \
  -H "Accept: application/vnd.oci.image.index.v1+json" \
  -H "Accept: application/vnd.oci.image.manifest.v1+json" \
  http://localhost:5000/v2/myalpine/manifests/1.0 | grep -i digest
# Docker-Content-Digest: sha256:c64c687cbea93001...
```

Endpoints หลัก:
| Endpoint | ใช้ทำอะไร |
|----------|-----------|
| `GET /v2/` | check ว่า registry API พร้อม |
| `GET /v2/_catalog` | list repositories |
| `GET /v2/<name>/tags/list` | list tags |
| `HEAD /v2/<name>/manifests/<tag>` | ดู metadata + digest |
| `GET /v2/<name>/manifests/<tag>` | ดู manifest JSON |
| `GET /v2/<name>/blobs/<digest>` | ดาวน์โหลด layer |
| `DELETE /v2/<name>/manifests/<digest>` | ลบ manifest (Lab 04) |

---

## Step 4 — Pull จาก Registry ของเรา

ลบ local image แล้ว pull กลับ:

```bash
docker rmi localhost:5000/myalpine:1.0
docker images | grep myalpine    # ไม่มีแล้ว

docker pull localhost:5000/myalpine:1.0
docker images | grep myalpine    # กลับมาแล้ว
```

---

## Step 5 — ดู Storage Layout

Registry เก็บข้อมูลใน `/var/lib/registry/docker/registry/v2/`:

```bash
docker exec lab07-registry find /var/lib/registry/docker/registry/v2/repositories -type d
```

```
repositories/myalpine/
├── _layers/sha256/<hash>/         ← references ไป blob layer
├── _manifests/
│   ├── revisions/sha256/<hash>/   ← manifest content
│   └── tags/1.0/
│       ├── current/               ← digest ที่ tag 1.0 ชี้
│       └── index/sha256/<hash>/   ← history ของ digests ที่เคยใช้ tag นี้
└── _uploads/                      ← partial uploads ที่ยังไม่เสร็จ
```

Blobs (layer data จริง) เก็บแยกที่:
```bash
docker exec lab07-registry ls /var/lib/registry/docker/registry/v2/blobs/sha256
```

Layers ที่ image หลายตัวใช้ร่วม → blob เดียวบน disk (content-addressed storage)

---

## Step 6 — Push หลาย Version

```bash
docker pull alpine:3.19
docker tag alpine:3.19 localhost:5000/myalpine:0.9
docker push localhost:5000/myalpine:0.9

curl -s http://localhost:5000/v2/myalpine/tags/list
# {"name":"myalpine","tags":["1.0","0.9"]}
```

---

## Step 7 — Cleanup

```bash
docker compose down -v   # ลบ registry-data volume ด้วย
docker rmi localhost:5000/myalpine:1.0 localhost:5000/myalpine:0.9 2>/dev/null
```

---

## สรุป

```
docker push localhost:5000/myapp:1.0
        │           │           │
        │           │           └── tag
        │           └── repository name
        └── registry host:port

curl http://localhost:5000/v2/_catalog            → list repos
curl http://localhost:5000/v2/<repo>/tags/list    → list tags
```

> **Limitation:** registry นี้ไม่มี authentication ใคร ๆ ก็ push ได้  
> → Lab 02 เพิ่ม htpasswd auth
