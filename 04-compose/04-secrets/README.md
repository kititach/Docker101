# Lab 04 — Secrets

## Objective

จัดการ sensitive data ด้วย Docker secrets — password ไม่ปรากฏใน environment variables, logs, หรือ `docker inspect`

---

## ปัญหาของการใส่ Secret ใน ENV

```yaml
# BAD — password อยู่ใน compose.yaml, env vars, docker inspect
environment:
  - POSTGRES_PASSWORD=my-secret-password
```

ปัญหา:
- `docker inspect db` แสดง password ในชัดเจน
- `docker compose config` print password ออกมา
- ถ้า commit compose.yaml ขึ้น git → password รั่ว
- `docker logs` อาจบันทึก env vars เมื่อ crash

---

## Files

```
04-secrets/
├── compose.yaml
├── secrets/
│   └── db_password.txt   — secret file (ไม่ควร commit ขึ้น git)
└── README.md
```

---

## Step 0 — Setup secret file

ไฟล์ `secrets/db_password.txt` **ไม่ได้อยู่ใน repo** (อยู่ใน `.gitignore`) — copy จาก `.example` แล้วเปลี่ยนค่าก่อนรัน lab:

```bash
cp secrets/db_password.txt.example secrets/db_password.txt
# (optional) ตั้งรหัสจริง: openssl rand -base64 24 > secrets/db_password.txt
```

---

## Step 1 — ดู Secret File และ compose.yaml

```bash
cat secrets/db_password.txt
# CHANGE_ME_before_running_lab   (หรือค่าที่ตั้งไว้)

cat compose.yaml
```

โครงสร้าง secrets ใน compose.yaml:
```yaml
secrets:
  db_password:
    file: ./secrets/db_password.txt   # อ่านจากไฟล์บน host

services:
  db:
    secrets:
      - db_password   # mount เข้า /run/secrets/db_password
    environment:
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
```

---

## Step 2 — รัน Stack

```bash
docker compose up -d --build
```

ดูว่า secret ถูก mount ที่ไหนใน container:
```bash
docker compose exec db cat /run/secrets/db_password
# secret-db-password-123   ← อยู่เป็น file ไม่ใช่ env var
```

ยืนยันว่า env var ไม่มี plaintext password:
```bash
docker compose exec db env | grep -i password
# POSTGRES_PASSWORD_FILE=/run/secrets/db_password   ← แค่ path ไม่ใช่ value
```

---

## Step 3 — เปรียบเทียบ: ENV vs Secret ใน docker inspect

```bash
# ดู env vars ของ container
docker inspect 04-secrets-db-1 --format '{{json .Config.Env}}' | python3 -m json.tool
# ["POSTGRES_PASSWORD_FILE=/run/secrets/db_password", ...]
# ← ไม่มี plaintext password!

# เปรียบเทียบกับแบบ plain env (ถ้าใส่ใน environment โดยตรง)
# ["POSTGRES_PASSWORD=secret-db-password-123", ...]
# ← password โผล่ออกมาเลย
```

---

## Step 4 — ใช้ Secret ใน App

แอป (Python) อ่าน secret จาก file แทน env var:

```python
import os

def get_db_password():
    # อ่านจาก secret file ถ้ามี
    secret_file = os.environ.get("DB_PASSWORD_FILE")
    if secret_file and os.path.exists(secret_file):
        with open(secret_file) as f:
            return f.read().strip()
    # fallback → env var (dev only)
    return os.environ.get("DB_PASSWORD", "")
```

> **หมายเหตุ:** compose.yaml ใน lab นี้ใช้ `DB_PASSWORD_FILE` แต่ app.py ยังอ่านจาก `DB_PASSWORD` ตรง ๆ อยู่ (เป็น simplification สำหรับ lab) ใน production ควรอ่านจาก file เสมอ

---

## Step 5 — .gitignore สำหรับ Secret Files

```bash
cat >> .gitignore << 'EOF'
secrets/
*.secret
*.key
.env
EOF
```

---

## Step 6 — Secret ใน Docker Swarm

ใน Swarm mode secrets มีการ encrypt ระหว่าง transfer ด้วย:

```bash
# สร้าง secret ใน Swarm (encrypt ด้วย TLS)
echo "my-password" | docker secret create db_password -

# ใช้ใน stack
docker stack deploy -c compose.yaml mystack
```

Compose file-based secrets เหมาะกับ single-host development  
Swarm secrets เหมาะกับ production cluster

---

## Cleanup

```bash
docker compose down -v
```

---

## สรุป

| วิธี | ปลอดภัย | ใช้งาน |
|------|---------|--------|
| ENV plaintext | ❌ | ง่าย แต่อย่าใช้ใน production |
| Secret file (Compose) | ✅ | mount ที่ `/run/secrets/name` |
| Docker Swarm secret | ✅✅ | encrypted, ใช้กับ cluster |
| External vault (Vault, AWS SSM) | ✅✅✅ | production-grade |
