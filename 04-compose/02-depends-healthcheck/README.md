# Lab 02 — depends_on + Healthcheck

## Objective

แก้ปัญหา startup race condition — ทำให้ web รอจน database พร้อมจริง ๆ ก่อน connect

---

> 📝 **เกี่ยวกับ `POSTGRES_PASSWORD=secret` ใน compose:**
> Lab นี้ใช้ password เป็น plaintext ใน env เพื่อโฟกัสที่ topic หลัก (depends_on + healthcheck) — **อย่าทำแบบนี้ใน production** ดู `04-compose/04-secrets/` สำหรับ pattern ที่ถูกต้อง (`POSTGRES_PASSWORD_FILE` + Docker secrets)

---

## ปัญหา: Race Condition

```
depends_on: [db]   ← รอแค่ container "started" ไม่ได้รอให้ postgres accept connections

Timeline:
  t=0s  db container started (postgres กำลัง initialize)
  t=0s  web container started → พยายาม connect db → CONNECTION REFUSED
  t=5s  postgres ready รับ connections
        แต่ web ได้ crash ไปแล้ว!
```

---

## Files

```
02-depends-healthcheck/
├── compose.yaml          — แก้แล้ว: condition: service_healthy
├── compose.broken.yaml   — ปัญหา: depends_on แบบ list
├── app/
│   ├── app.py            — Flask + Postgres
│   ├── Dockerfile
│   └── requirements.txt
└── README.md
```

---

## Step 1 — สาธิต Race Condition (compose.broken.yaml)

```bash
docker compose -f compose.broken.yaml up -d --build
docker compose -f compose.broken.yaml logs web
```

สังเกต:
```
web-1  | could not connect to server: Connection refused
web-1  | Is the server running on host "db" (172.x.x.x) and accepting
web-1  | TCP/IP connections on port 5432?
```

web crash แล้ว restart หลายรอบก่อนที่ db จะพร้อม

```bash
docker compose -f compose.broken.yaml ps
# web: Restarting   ← กำลัง crash loop

docker compose -f compose.broken.yaml down -v
```

---

## Step 2 — แก้ด้วย condition: service_healthy

เปรียบเทียบสองวิธี:

```yaml
# compose.broken.yaml — รอแค่ container start
depends_on:
  - db

# compose.yaml — รอจน healthcheck ผ่าน
depends_on:
  db:
    condition: service_healthy
```

healthcheck บน db service:
```yaml
db:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U app -d app"]
    interval: 5s
    timeout: 3s
    retries: 10
    start_period: 10s   # ให้เวลา postgres initialize ก่อนเริ่มนับ retry
```

`pg_isready` คือ command ที่ postgres มาให้ — return 0 เมื่อพร้อมรับ connections

---

## Step 3 — รัน Fixed Version

```bash
docker compose up -d --build
```

ดู Compose รอ db healthy:
```bash
docker compose logs -f
# db-1   | PostgreSQL init process complete; ready for start up.
# db-1   | database system is ready to accept connections
# web-1  | (เริ่มขึ้น หลังจาก db healthy)
```

ดู healthcheck status:
```bash
docker compose ps
# db:  Up (healthy)
# web: Up (health: starting)
```

ทดสอบ:
```bash
curl http://localhost:8081/
# {"host":"...","ts":"2026-05-19T...","visit_id":1}

curl http://localhost:8081/
# {"visit_id":2,...}
```

---

## Step 4 — ดู Health History

```bash
docker inspect 02-depends-healthcheck-db-1 \
  --format '{{json .State.Health}}' | python3 -m json.tool

# แสดง history ของ healthcheck แต่ละครั้ง:
# "Status": "healthy"
# "Log": [{"ExitCode": 0, "Output": "..."}, ...]
```

---

## Step 5 — Healthcheck Conditions

```yaml
depends_on:
  db:
    condition: service_started    # รอแค่ container started (default)
  cache:
    condition: service_healthy    # รอจน healthcheck ผ่าน ✅
  migrate:
    condition: service_completed_successfully  # รอจน container exit 0
```

`service_completed_successfully` ใช้กับ migration container:
```yaml
  migrate:
    image: myapp:1.0
    command: python manage.py migrate
    depends_on:
      db:
        condition: service_healthy
```

---

## Step 6 — Cleanup

```bash
docker compose down -v
```

---

## สรุป

| depends_on | รอจนถึง | เหมาะกับ |
|-----------|---------|---------|
| `condition: service_started` | container process เริ่มรัน | service ที่ไม่ต้องรอ init |
| `condition: service_healthy` | healthcheck ผ่าน | database, cache |
| `condition: service_completed_successfully` | container exit 0 | migration, seed data |
