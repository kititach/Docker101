# Lab 01 — Compose Basics

## Objective

เข้าใจโครงสร้าง compose.yaml และ commands ที่ใช้บ่อยทั้งหมด — รัน multi-container stack ด้วยคำสั่งเดียว

---

## Files

```
01-basics/
├── compose.yaml      — กำหนด web + redis stack
├── app/
│   ├── app.py        — Flask hit counter ใช้ Redis
│   ├── Dockerfile
│   └── requirements.txt
└── README.md
```

---

## Step 1 — ดู compose.yaml และทำความเข้าใจโครงสร้าง

```bash
cat compose.yaml
```

แต่ละส่วน:

```yaml
services:          # containers ที่จะรัน
  web:
    build: ./app   # build จาก Dockerfile ใน ./app
    ports:
      - "9080:8080"
    environment:
      - REDIS_HOST=redis   # ชื่อ service = DNS name อัตโนมัติ
    depends_on:
      - redis        # รอให้ redis container start ก่อน (แต่ไม่รอ ready)
    networks:
      - frontend
      - backend
    restart: unless-stopped

  redis:
    image: redis:7-alpine   # ใช้ official image โดยตรง
    volumes:
      - redis-data:/data   # named volume สำหรับ persistence
    networks:
      - backend
    restart: unless-stopped

volumes:
  redis-data:    # Docker manage volume นี้

networks:
  frontend:
  backend:
    internal: true   # backend network ไม่มี internet access
```

---

## Step 2 — รัน Stack

```bash
# build images + start containers ใน background
docker compose up -d --build

# ดูสถานะ
docker compose ps
```

ทดสอบ:
```bash
curl http://localhost:9080/
# {"hits":1,"host":"abc123..."}

curl http://localhost:9080/
# {"hits":2,"host":"abc123..."}
```

hits เพิ่มทุก request — Flask อ่านจาก Redis ซึ่งอยู่ใน backend network

---

## Step 3 — Logs

```bash
# ดู logs ทุก service
docker compose logs

# ดู logs service เดียว + follow
docker compose logs -f web

# ดู logs ย้อนหลัง 20 บรรทัด
docker compose logs --tail 20
```

---

## Step 4 — Exec เข้า Container

```bash
# เข้า shell ใน web container
docker compose exec web sh

# รัน command เดียว
docker compose exec web python -c "import redis; print(redis.__version__)"

# เข้า redis-cli
docker compose exec redis redis-cli ping
docker compose exec redis redis-cli get hits
```

---

## Step 5 — Scale Service

```bash
# รัน web หลาย instance
docker compose up -d --scale web=3

docker compose ps
# web-1, web-2, web-3 ทั้งสามตัวอยู่ใน network เดียวกัน

# ลอง curl หลาย ๆ ครั้ง สังเกต hostname ที่เปลี่ยน
for i in $(seq 1 9); do curl -s http://localhost:9080/ | python3 -m json.tool; done
```

> เมื่อ scale > 1 ต้องระวัง port conflict — Compose จะ error ถ้า host port ซ้ำกัน
> แก้ด้วยการไม่ระบุ host port: `- "8080"` แทน `- "9080:8080"`

Scale กลับ:
```bash
docker compose up -d --scale web=1
```

---

## Step 6 — คำสั่ง Compose ที่ใช้บ่อย

```bash
docker compose up -d            # start (background)
docker compose up -d --build    # rebuild images + start
docker compose down             # stop + remove containers + networks
docker compose down -v          # รวมลบ volumes ด้วย
docker compose ps               # ดูสถานะ
docker compose logs -f          # ดู logs แบบ follow
docker compose exec svc cmd     # รัน command ใน container
docker compose build            # build images เท่านั้น
docker compose pull             # pull latest images
docker compose restart web      # restart service เดียว
docker compose stop             # stop (ไม่ remove)
docker compose start            # start containers ที่ stop ไว้
docker compose config           # validate + print merged config
```

---

## Step 7 — Cleanup

```bash
docker compose down -v
```

---

## compose.yaml vs docker-compose.yml

| | compose.yaml | docker-compose.yml |
|-|-|-|
| Format | Compose spec (current) | Legacy v2/v3 |
| Command | `docker compose` (V2) | `docker-compose` (V1, deprecated) |
| แนะนำ | ✅ | ❌ |

ใช้ `compose.yaml` + `docker compose` เสมอ
