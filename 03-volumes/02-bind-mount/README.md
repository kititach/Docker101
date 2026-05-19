# Lab 02 — Bind Mounts

## Objective

ใช้ bind mount สำหรับ dev workflow — เห็นการเปลี่ยนแปลง source code ใน container ทันทีโดยไม่ต้อง rebuild image

---

## Files

```
02-bind-mount/
├── image/
│   └── Dockerfile   — Flask dev server (flask + --reload)
├── src/
│   └── server.py    — source code ที่จะ mount เข้า container
└── README.md
```

---

## Bind Mount คืออะไร

Bind mount เชื่อม path บน host เข้ากับ path ใน container โดยตรง — ไม่ผ่าน Docker volume layer

```
Host filesystem          Container filesystem
/home/user/project  ──▶  /app
       │                      │
       └── server.py ◀───────▶ server.py  (เป็น file เดียวกัน)
```

แก้ไขบน host → container เห็นทันที และในทางกลับกัน

---

## Step 1 — Bind Mount พื้นฐาน

```bash
# รัน alpine และ mount /etc/hosts ของ host เข้าไปดู
docker run --rm \
  -v /etc/hosts:/mnt/hosts:ro \
  alpine cat /mnt/hosts

# mount directory
docker run --rm \
  -v $(pwd)/src:/app \
  alpine ls -la /app
```

---

## Step 2 — Hot-Reload Dev Workflow

Build dev image (มีแค่ Flask runtime — source code ไม่อยู่ใน image):

```bash
docker build -t vol-dev:1.0 image/
```

รัน dev server พร้อม bind mount:

```bash
docker run -d \
  --name dev-server \
  -v $(pwd)/src:/app \
  -p 5001:5000 \
  vol-dev:1.0
```

ทดสอบ initial response:
```bash
curl http://localhost:5001/
# {"message":"Hello from container!","time":"..."}
```

**แก้ source code บน host ขณะ container รัน:**

```bash
# เปิด src/server.py แล้วเปลี่ยน MESSAGE เป็นอะไรก็ได้
# หรือใช้ sed:
sed -i 's/Hello from container!/Hot-reload works!/' src/server.py
```

รอสักครู่ Flask auto-reload → ทดสอบอีกครั้ง:
```bash
curl http://localhost:5001/
# {"message":"Hot-reload works!","time":"..."}  ← เปลี่ยนทันที ไม่ต้อง rebuild!
```

ดู logs เพื่อยืนยัน Flask reload:
```bash
docker logs dev-server | tail -5
#  * Detected change in '/app/server.py', reloading
#  * Restarting with stat
#  * Debugger is active!
```

Revert:
```bash
sed -i 's/Hot-reload works!/Hello from container!/' src/server.py
docker rm -f dev-server
```

---

## Step 3 — Read-Only Bind Mount

ป้องกัน container เขียนทับ source code:

```bash
docker run --rm \
  -v $(pwd)/src:/app:ro \
  alpine sh -c "cat /app/server.py"  # อ่านได้

docker run --rm \
  -v $(pwd)/src:/app:ro \
  alpine sh -c "echo 'oops' > /app/server.py"
# /app/server.py: Read-only file system  ← ป้องกันได้
```

pattern นี้ดีสำหรับ: config files, secrets ที่ mount เข้า container แต่ไม่ให้แก้ได้

---

## Step 4 — Mount ไฟล์เดี่ยว (ไม่ใช่ directory)

```bash
# inject config ไฟล์เดียว
echo '{"debug": true, "port": 8080}' > /tmp/config.json

docker run --rm \
  -v /tmp/config.json:/app/config.json:ro \
  alpine cat /app/config.json
```

ใช้กับ: nginx.conf, prometheus.yml, .env files

---

## Step 5 — Named Volume vs Bind Mount

```bash
# Named Volume: Docker manage path
docker run --rm \
  -v mydata:/data \
  alpine sh -c "pwd && ls /data"
# Docker เลือก path ให้: /var/lib/docker/volumes/mydata/_data

# Bind Mount: คุณ control path
docker run --rm \
  -v $(pwd)/src:/data \
  alpine sh -c "ls /data"
# ไฟล์จาก $(pwd)/src ปรากฏใน /data
```

| | Named Volume | Bind Mount |
|-|-------------|------------|
| Path management | Docker | คุณ |
| Portability | ✅ ย้ายเครื่องได้ง่าย | ❌ path ต้องตรงกัน |
| Dev workflow | ❌ | ✅ hot-reload |
| Production data | ✅ | ✅ (แต่ต้องระวัง path) |
| Permissions | Docker จัดการ | ขึ้นกับ host file permissions |

---

## Step 6 — ระวัง: Container เขียนทับ Host

bind mount เป็นสองทิศทาง — container **เขียนไฟล์บน host ได้**:

```bash
mkdir -p /tmp/test-mount
docker run --rm \
  -v /tmp/test-mount:/data \
  alpine sh -c "echo 'written by container' > /data/from-container.txt"

cat /tmp/test-mount/from-container.txt
# written by container  ← ไฟล์อยู่บน host จริง ๆ

rm -rf /tmp/test-mount
```

ถ้า container รันเป็น root และ mount home directory — container เขียนทับไฟล์ของคุณได้

> **Best practice:** mount เฉพาะ directory ที่ต้องการ ใช้ `:ro` เมื่อ container ไม่ต้องเขียน และอย่า mount path สำคัญเช่น `/`, `/etc`, `$HOME` โดยไม่จำเป็น

---

## Cleanup

```bash
docker rm -f dev-server 2>/dev/null
docker rmi vol-dev:1.0
rm -f /tmp/config.json
```
