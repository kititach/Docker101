# Lab 03 — Profiles

## Objective

ใช้ profiles เพื่อแยก services ตาม environment — รัน debug tools เฉพาะตอน dev โดยไม่แก้ compose.yaml

---

## Profiles คืออะไร

Profile คือ label บน service — service ที่มี `profiles:` จะ**ไม่รัน**เว้นแต่จะ activate profile นั้น  
Service ที่ไม่มี `profiles:` รันทุกครั้ง (base services)

```yaml
services:
  web:          # ไม่มี profiles → รันทุกครั้ง
    ...
  redis:        # ไม่มี profiles → รันทุกครั้ง
    ...
  redis-commander:
    profiles: [debug]    # รันเฉพาะเมื่อ --profile debug
  adminer:
    profiles: [debug]    # รันเฉพาะเมื่อ --profile debug
```

---

## Step 1 — รันแบบ Normal (ไม่มี debug tools)

```bash
docker compose up -d --build

docker compose ps
# web, redis  ← เห็นแค่สอง services
# redis-commander และ adminer ไม่รัน
```

ทดสอบ:
```bash
curl http://localhost:9080/
```

---

## Step 2 — รันพร้อม Debug Profile

```bash
docker compose down

docker compose --profile debug up -d

docker compose ps
# web, redis, redis-commander, adminer  ← ทั้ง 4 services
```

เปิด browser:
- `http://localhost:9080` — web app
- `http://localhost:8081` — Redis Commander (GUI สำหรับดู Redis)
- `http://localhost:8082` — Adminer (database GUI)

---

## Step 3 — หลาย Profiles

Service หนึ่งตัวมีได้หลาย profile:

```yaml
  debug-proxy:
    image: nginx:alpine
    profiles: [debug, staging]   # รันเมื่อ activate debug หรือ staging
```

Activate หลาย profiles พร้อมกัน:
```bash
docker compose --profile debug --profile monitoring up -d
# หรือใช้ env var
COMPOSE_PROFILES=debug,monitoring docker compose up -d
```

---

## Step 4 — Profile กับ depends_on

ถ้า service ที่มี profile ถูก depends โดย service อื่น → profile ต้องถูก activate ด้วย:

```yaml
  exporter:
    profiles: [monitoring]
  grafana:
    profiles: [monitoring]
    depends_on:
      - exporter   # ทั้งคู่ต้องอยู่ใน profile เดียวกัน
```

---

## Step 5 — Use Cases จริง

```yaml
services:
  app:          # base — รันทุก env
  db:           # base — รันทุก env

  # dev only
  mailhog:
    profiles: [dev]      # mock SMTP server

  # debug only
  jaeger:
    profiles: [debug]    # distributed tracing UI

  # monitoring
  prometheus:
    profiles: [monitoring]
  grafana:
    profiles: [monitoring]
```

---

## Cleanup

```bash
docker compose --profile debug down -v
```

---

## สรุป

```bash
# รัน base services เท่านั้น
docker compose up -d

# รัน base + debug services
docker compose --profile debug up -d

# รัน base + monitoring
docker compose --profile monitoring up -d

# ทุกอย่าง
docker compose --profile debug --profile monitoring up -d

# ด้วย env var (เหมาะกับ CI)
COMPOSE_PROFILES=debug docker compose up -d
```
