# Lab 03 — Read-Only Root Filesystem

## Objective

ทำให้ container filesystem เป็น read-only ทั้งหมด — attacker เขียนไฟล์ใด ๆ ลง image ไม่ได้

---

## ทำไม Read-Only Rootfs?

```
Attacker compromise application → ทำอะไรได้บ้าง?

Writable rootfs:
  ✓ apk add malware
  ✓ แก้ /usr/local/bin/* แทน binary จริง
  ✓ ฝัง backdoor ใน /etc/cron.d
  ✓ persist หลัง container restart (ถ้ามี volume)

Read-only rootfs:
  ✗ ทำอะไรไม่ได้เลย ยกเว้น path ที่กำหนดเป็น tmpfs / volume
```

---

## Step 1 — ลอง --read-only กับ nginx (จะ fail)

```bash
docker run --rm --read-only nginx:1.27-alpine
# nginx: [emerg] mkdir() "/var/cache/nginx/client_temp" failed
#        (30: Read-only file system)
```

nginx ต้องเขียน:
- `/var/cache/nginx/` — proxy/fastcgi temp files
- `/var/run/nginx.pid` — PID file
- `/tmp` — บางสถานการณ์

---

## Step 2 — แก้ด้วย --tmpfs (writable in-memory paths)

```bash
docker run -d --name ro-nginx \
  --read-only \
  --tmpfs /var/cache/nginx:size=10m \
  --tmpfs /var/run:size=1m \
  --tmpfs /tmp:size=10m \
  -p 9094:80 \
  nginx:1.27-alpine

# nginx ทำงานปกติ
curl -sI http://localhost:9094/ | head -1
# HTTP/1.1 200 OK
```

---

## Step 3 — ยืนยันว่า Read-Only ใช้งานจริง

```bash
# attacker พยายามแก้ไฟล์ใน image — fail
docker exec ro-nginx sh -c 'echo "x" > /usr/share/nginx/html/test.html' 2>&1
# Read-only file system

# พยายาม install package — fail
docker exec ro-nginx apk add curl 2>&1 | tail -2
# ERROR: Unable to lock database: Read-only file system

# tmpfs paths ยังเขียนได้
docker exec ro-nginx sh -c 'echo "x" > /tmp/test && cat /tmp/test'
# x

docker rm -f ro-nginx
```

---

## Step 4 — รู้ว่า App ต้องเขียนที่ไหนบ้าง

audit ด้วยการรัน `--read-only` แล้วดู error:

```bash
docker run --rm --read-only myapp 2>&1 | grep -i "read-only\|permission"
```

หรือ trace ด้วย `strace`:
```bash
docker run --rm --cap-add SYS_PTRACE myapp strace -e openat 2>&1 | grep "O_WRONLY\|O_RDWR"
```

**Paths ที่ apps ส่วนใหญ่ต้องเขียน:**
- `/tmp` — temp files
- `/var/run` — PID files, sockets
- `/var/log` — logs (ควรเปลี่ยนเป็น stdout/stderr แทน)
- `/var/cache/<app>/` — app-specific cache
- `~/.cache` — user cache

---

## Step 5 — Postgres ใน Read-Only

Database ต้องการเขียนข้อมูล — ใช้ volume สำหรับ data + tmpfs สำหรับ temp

```bash
docker volume create pg-readonly-test

docker run -d --name ro-pg \
  --read-only \
  --tmpfs /tmp:size=64m \
  --tmpfs /var/run/postgresql:size=64m \
  -v pg-readonly-test:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secret \
  postgres:16-alpine

sleep 5
docker exec ro-pg psql -U postgres -c "SELECT version()" | head -3
docker rm -f ro-pg
docker volume rm pg-readonly-test
```

> **หลักการ:** data → volume, temp → tmpfs, ส่วนที่เหลือ → read-only

---

## Step 6 — Compose Syntax

```yaml
services:
  web:
    image: nginx:1.27-alpine
    read_only: true
    tmpfs:
      - /var/cache/nginx:size=10m
      - /var/run:size=1m
      - /tmp:size=10m
    ports:
      - "80:80"
```

---

## ปัญหาที่อาจเจอ

| ปัญหา | สาเหตุ | วิธีแก้ |
|--------|--------|--------|
| app crash on startup | เขียน PID/lock file ไม่ได้ | tmpfs สำหรับ `/var/run` |
| log silent | เขียน log file ไม่ได้ | ส่ง log ไป stdout แทน |
| upload fail | เขียน temp file ไม่ได้ | tmpfs สำหรับ `/tmp` |
| migration fail | สร้าง schema file ไม่ได้ | run migration separate container (ไม่ใช้ read-only) |

---

## Read-Only Checklist

```
□ ตั้ง --read-only หรือ read_only: true
□ tmpfs สำหรับ /tmp, /var/run, app cache
□ Volume สำหรับ persistent data
□ Logs ส่งไป stdout/stderr ไม่ใช่ไฟล์
□ Migration / init scripts รันใน container แยก (writable)
```
