# Lab 04 — Swarm Secrets & Configs

## Objective

จัดการ sensitive data + config files ด้วย Swarm built-in store — **encrypted at rest** ใน Raft log + **encrypted in transit** ระหว่าง nodes

---

## Swarm Secrets vs Compose File Secrets

| | Compose file secret (Module 04 Lab 04) | Swarm secret |
|-|---------------------------------------|--------------|
| Store | ไฟล์บน host filesystem | Raft store (encrypted) |
| Transit encryption | ❌ (อ่านไฟล์โดยตรง) | ✅ TLS ระหว่าง manager↔worker |
| At-rest encryption | ❌ (ขึ้นกับ disk) | ✅ AES-GCM |
| Multi-host | ❌ ต้อง sync ไฟล์เอง | ✅ Raft replicate ให้ |
| Mount point | `/run/secrets/<name>` | `/run/secrets/<name>` (เหมือนกัน) |
| Compose v2 syntax | ✅ | ✅ (ผ่าน `external: true`) |

---

## Step 1 — สร้าง Secrets

```bash
# 1) จาก stdin
echo -n "supersecretpassword123" | docker secret create db_password -

# 2) จากไฟล์
echo "abc123" > /tmp/apikey
docker secret create api_key /tmp/apikey
rm /tmp/apikey
```

> `-n` ใน echo สำคัญ — ไม่งั้นมี newline ติดท้าย password

```bash
docker secret ls
# ID         NAME          CREATED
# jhdjr...   db_password   Less than a second ago
# ekbwo...   api_key       Less than a second ago

docker secret inspect db_password
# ดู metadata ได้ — แต่ ดู content ไม่ได้
```

> **สำคัญ:** หลังจาก create แล้ว ดู content ของ secret ผ่าน CLI ไม่ได้ — มีแต่ container ที่ได้รับ secret เท่านั้นที่ mount เห็น

---

## Step 2 — สร้าง Config

```bash
echo "log_level=debug
max_connections=100
cache_ttl=300" | docker config create app_config -

docker config ls
# ID         NAME         CREATED
# b3tjek...  app_config   Less than a second ago
```

**Config = secret ที่ไม่เป็นความลับ** — ใช้กับ config files, public certs, etc.  
ต่างกันที่ Swarm ไม่ encrypt config (แต่ยังจัด distribute ให้)

---

## Step 3 — ใช้ใน Service (CLI)

```bash
docker service create --name testapp \
  --secret db_password \
  --secret api_key \
  --config source=app_config,target=/etc/app/config.conf \
  alpine:3.20 sleep 600
```

ดูว่า mount ที่ไหน:
```bash
TASK=$(docker ps -q -f "label=com.docker.swarm.service.name=testapp")

docker exec $TASK ls -la /run/secrets/
# -r--r--r--    1 root     root            19 ... api_key
# -r--r--r--    1 root     root            22 ... db_password

docker exec $TASK cat /run/secrets/db_password
# supersecretpassword123

docker exec $TASK cat /etc/app/config.conf
# log_level=debug
# max_connections=100
# cache_ttl=300
```

> Secret/config ถูก mount เป็น **tmpfs** read-only — ไม่ถูก write ลง disk ใน container เลย

---

## Step 4 — ใช้ใน Stack (compose.yaml)

```yaml
services:
  app:
    image: alpine:3.20
    secrets:
      - db_password
      - api_key
    configs:
      - source: app_config
        target: /etc/app/config.conf
        mode: 0644

secrets:
  db_password:
    external: true      # ต้องสร้างผ่าน docker secret create ก่อน
  api_key:
    external: true

configs:
  app_config:
    external: true      # หรือใช้ file: ./app.conf เพื่อ create จาก file
```

```bash
docker stack deploy -c compose.yaml secretsdemo
```

---

## Step 5 — Postgres ที่ใช้ Secret

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password    # ← อ่านจาก file
      POSTGRES_DB: app
    secrets:
      - db_password
    volumes:
      - pgdata:/var/lib/postgresql/data

secrets:
  db_password:
    external: true
```

`POSTGRES_PASSWORD_FILE` แทน `POSTGRES_PASSWORD` — postgres image อ่าน password จากไฟล์เอง

---

## Step 6 — Rotate Secret

secrets เป็น **immutable** — ไม่มี `docker secret update`  
วิธี rotate:

```bash
# 1. สร้าง secret ใหม่ด้วยชื่อใหม่
echo -n "newpassword456" | docker secret create db_password_v2 -

# 2. update service ใช้ secret ใหม่ + remove ตัวเก่า
docker service update \
  --secret-rm db_password \
  --secret-add db_password_v2 \
  testapp

# 3. ตรวจสอบว่า rolling update เสร็จ แล้วลบ secret เก่า
docker secret rm db_password
```

> Rolling update ที่ rotate secret = downtime-free password change

---

## Step 7 — Inspect Encrypted Store

Raft store ของ Swarm อยู่ที่ host:
```bash
sudo ls /var/lib/docker/swarm/raft/
# wal-v3-encrypted/   ← encrypted log
# snap-v3-encrypted/

sudo ls /var/lib/docker/swarm/
# certificates/   ← TLS certs สำหรับ node-to-node
# raft/
# state.json
# worker/
```

ถ้าใครได้ disk → ยังต้อง break AES-GCM ก่อน → secrets ปลอดภัย

---

## Cleanup

```bash
docker service rm testapp 2>/dev/null
docker secret rm db_password api_key 2>/dev/null
docker config rm app_config 2>/dev/null

# leave swarm (optional — ถ้าจบ module นี้)
docker swarm leave --force
```

---

## Secrets/Configs Best Practices

```
□ ใช้ Swarm secret แทน env var สำหรับ password/key
□ ใช้ Swarm config สำหรับ config files (nginx.conf, app.yaml)
□ POSTGRES_PASSWORD_FILE / MYSQL_PASSWORD_FILE pattern
□ rotate ผ่าน new secret + update service (immutable design)
□ ตรวจสอบ container ว่าอ่านจาก /run/secrets/ จริง ไม่ใช่ ENV
□ external: true ใน production — แยกการ provision secret ออกจาก deploy
```
