# Lab 05 — Override Files

## Objective

แยก config ตาม environment ด้วย override files — base config ร่วมกัน dev/prod config แตกต่างกัน โดยไม่ duplicate YAML

---

## Files

```
05-override/
├── compose.yaml           — base: services ทุก env ใช้ร่วมกัน
├── compose.override.yaml  — dev: bind mount, hot-reload, expose debug ports
├── compose.prod.yaml      — prod: resource limits, restart policy, logging
└── README.md
```

---

## ทำไมต้องมี Override?

```
ปัญหาถ้าใช้ compose.yaml เดียว:
  - dev ต้องการ bind mount (hot-reload)
  - prod ต้องการ resource limits
  - dev ต้องการ expose debug ports
  - prod ไม่ต้องการ

ถ้า copy compose.yaml เป็นหลายไฟล์ → duplicate + maintenance nightmare
```

Override file **merge** กับ base โดยอัตโนมัติ — เขียนแค่ส่วนที่ต่างกัน

---

## Step 1 — ดูไฟล์ทั้งสาม

```bash
cat compose.yaml           # base
cat compose.override.yaml  # dev additions
cat compose.prod.yaml      # prod additions
```

---

## Step 2 — Dev Mode (auto-merge)

`compose.override.yaml` ถูก merge อัตโนมัติเมื่ออยู่ใน directory เดียวกับ `compose.yaml`:

```bash
docker compose up -d --build

# ผล: compose.yaml + compose.override.yaml merged
# web: bind mount + hot-reload + port 9080
# redis: port 6379 exposed
```

ดู merged config:
```bash
docker compose config
# เห็น config ที่ merge แล้ว: มี bind mount + ports จาก override
```

ทดสอบ hot-reload:
```bash
# แก้ source code
sed -i 's/Hello from container!/Dev hot-reload!/' ../01-basics/app/app.py

# รอสักครู่แล้ว curl
curl http://localhost:9080/

# revert
sed -i 's/Dev hot-reload!/Hello from container!/' ../01-basics/app/app.py
```

```bash
docker compose down -v
```

---

## Step 3 — Prod Mode (explicit -f)

Production ต้องระบุ files เองเพราะ override.yaml ไม่ควรถูก auto-merge:

```bash
docker compose -f compose.yaml -f compose.prod.yaml up -d --build

# ผล: base + prod config
# web: port 80, restart: always, resource limits
# redis: restart: always, memory limit
```

ดู config ที่ merge:
```bash
docker compose -f compose.yaml -f compose.prod.yaml config | grep -A5 "resources\|restart\|ports"
```

```bash
docker compose -f compose.yaml -f compose.prod.yaml down -v
```

---

## Step 4 — กฎ Merge

Compose merge ค่าตามกฎเหล่านี้:

```yaml
# base
services:
  web:
    environment:
      - DEBUG=false
    ports:
      - "80:8080"

# override
services:
  web:
    environment:
      - DEBUG=true      # ← override ค่าเดิม
      - LOG_LEVEL=debug # ← เพิ่มใหม่
    ports:
      - "9090:9090"     # ← เพิ่ม port (ไม่ทับ port เดิม)
```

ผลลัพธ์หลัง merge:
```yaml
environment:
  - DEBUG=true        # overridden
  - LOG_LEVEL=debug   # added
ports:
  - "80:8080"         # from base
  - "9090:9090"       # from override (appended)
```

> `lists` (ports, volumes, environment) → append  
> `mappings` (build, logging) → override

---

## Step 5 — Pattern ที่แนะนำสำหรับ Team

```
compose.yaml              ← commit ✅ (base, no secrets)
compose.override.yaml     ← .gitignore ❌ หรือ commit ✅ ถ้าไม่มี secrets
compose.prod.yaml         ← commit ✅
compose.staging.yaml      ← commit ✅
secrets/                  ← .gitignore ❌ ไม่ commit เด็ดขาด
```

ใน CI/CD:
```bash
# staging
docker compose -f compose.yaml -f compose.staging.yaml up -d

# production
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

---

## Cleanup

```bash
docker compose down -v 2>/dev/null
docker compose -f compose.yaml -f compose.prod.yaml down -v 2>/dev/null
```

---

## สรุป

| File | auto-merge | ใช้กับ |
|------|-----------|--------|
| `compose.yaml` | base | ทุก env |
| `compose.override.yaml` | ✅ อัตโนมัติ | local dev |
| `compose.prod.yaml` | ❌ ต้องระบุ `-f` | production |
| `compose.staging.yaml` | ❌ ต้องระบุ `-f` | staging |
