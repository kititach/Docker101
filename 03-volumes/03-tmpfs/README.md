# Lab 03 — tmpfs

## Objective

ใช้ tmpfs สำหรับ in-memory storage — ข้อมูลไม่เขียนลง disk เลย และหายทันทีเมื่อ container หยุด

---

## tmpfs ทำงานอย่างไร

tmpfs mount เก็บข้อมูลใน **RAM** ของ host โดยตรง:

```
ปกติ (volume/bind):   container → filesystem layer → disk
tmpfs:               container → RAM (ไม่ผ่าน disk เลย)
```

ประโยชน์:
- ข้อมูล sensitive ไม่เขียนลง disk → ไม่มีใน logs, snapshot, หรือ disk forensics
- I/O เร็วกว่า disk มาก (เหมาะกับ temp cache)
- หายอัตโนมัติเมื่อ container stop → ไม่ต้อง cleanup เอง

---

## Step 1 — รัน Container ด้วย tmpfs

```bash
docker run -d \
  --name tmpfs-demo \
  --tmpfs /secrets \
  alpine sleep 300
```

เขียนข้อมูลลงไป:
```bash
docker exec tmpfs-demo sh -c "echo 'db-password-xyz' > /secrets/db_pass.txt"
docker exec tmpfs-demo cat /secrets/db_pass.txt
# db-password-xyz
```

ข้อมูลอยู่ใน RAM — ดู filesystem type:
```bash
docker exec tmpfs-demo mount | grep secrets
# tmpfs on /secrets type tmpfs ...
```

---

## Step 2 — ข้อมูลหายหลัง Container Restart

```bash
# restart container
docker restart tmpfs-demo
sleep 1

# ข้อมูลหายไปแล้ว
docker exec tmpfs-demo cat /secrets/db_pass.txt 2>&1
# cat: can't open '/secrets/db_pass.txt': No such file or directory

# แต่ /secrets directory ยังอยู่ (mount point)
docker exec tmpfs-demo ls /secrets
# (ว่างเปล่า)

docker rm -f tmpfs-demo
```

---

## Step 3 — กำหนด Size Limit

```bash
# จำกัด tmpfs ที่ 10 MB
docker run -d \
  --name tmpfs-limited \
  --tmpfs /tmp:size=10m \
  alpine sleep 300

# ลองเขียนเกิน limit
docker exec tmpfs-limited dd if=/dev/zero of=/tmp/bigfile bs=1M count=15 2>&1
# dd: /tmp/bigfile: No space left on device  ← ถูก limit

# เขียนไม่เกิน limit ได้
docker exec tmpfs-limited dd if=/dev/zero of=/tmp/smallfile bs=1M count=5
docker exec tmpfs-limited ls -lh /tmp/

docker rm -f tmpfs-limited
```

---

## Step 4 — tmpfs Options

```bash
# noexec: ป้องกัน execute ไฟล์ใน tmpfs (security)
docker run -d \
  --name tmpfs-noexec \
  --tmpfs /tmp:size=10m,noexec \
  alpine sleep 300

docker exec tmpfs-noexec sh -c "
  echo '#!/bin/sh' > /tmp/test.sh
  echo 'echo hello' >> /tmp/test.sh
  chmod +x /tmp/test.sh
  /tmp/test.sh
"
# /tmp/test.sh: Permission denied  ← noexec ทำงาน

docker rm -f tmpfs-noexec
```

Options ที่ใช้บ่อย:
- `size=10m` — จำกัดขนาด (bytes, k, m, g)
- `noexec` — ป้องกัน execute files
- `nosuid` — ป้องกัน setuid/setgid
- `nodev` — ป้องกัน device files

---

## Step 5 — Use Case จริง: Session Store

pattern สำหรับ web application ที่เก็บ session data ชั่วคราว:

```bash
docker run -d \
  --name web-app \
  --tmpfs /app/sessions:size=50m,noexec \
  --tmpfs /app/cache:size=100m,noexec \
  alpine sleep 300

# session เขียนลง RAM — เร็ว + ไม่เขียน disk
docker exec web-app sh -c "
  echo 'session-token-abc123' > /app/sessions/user-42.json
  echo 'cached-query-result' > /app/cache/query-1.json
"

docker exec web-app ls /app/sessions /app/cache

docker rm -f web-app
```

---

## Step 6 — --mount Syntax (verbose แต่ชัดเจนกว่า)

Docker รองรับสองรูปแบบ — `--tmpfs` และ `--mount`:

```bash
# --tmpfs (สั้น)
docker run --tmpfs /tmp:size=10m alpine sleep 5

# --mount (verbose แต่อ่านง่ายกว่าใน script)
docker run \
  --mount type=tmpfs,target=/tmp,tmpfs-size=10485760 \
  alpine sleep 5
```

`--mount` เป็น preferred syntax ใน Docker documentation ปัจจุบัน

---

## สรุปเปรียบเทียบ Mount Types

| | Named Volume | Bind Mount | tmpfs |
|-|-------------|------------|-------|
| เก็บที่ | /var/lib/docker/ | host path | RAM |
| persist หลัง stop | ✅ | ✅ | ❌ |
| persist หลัง rm | ✅ | ✅ | — |
| I/O speed | disk | disk | RAM (เร็วที่สุด) |
| ข้อมูลไม่ถึง disk | ❌ | ❌ | ✅ |
| ใช้กับ | production data | dev workflow | secrets, temp cache |
