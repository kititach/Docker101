# Lab 01 — Named Volumes

## Objective

เข้าใจ named volume lifecycle ทั้งหมด — create, persist, share, backup, restore และ cleanup

---

## ทำไม Named Volume?

Container เป็น ephemeral — ถ้าลบ container ข้อมูลใน container filesystem หายหมด  
Named volume คือ storage ที่ Docker manage แยกจาก container lifecycle

```
Container A ──┐
               ├──▶ /var/lib/docker/volumes/mydata/_data  (named volume)
Container B ──┘

ลบ Container A → volume ยังอยู่
รัน Container C แล้ว mount volume เดิม → ข้อมูลยังครบ
```

---

## Step 1 — สร้างและ Inspect Volume

```bash
# สร้าง named volume
docker volume create mydata

# แสดง volumes ทั้งหมด
docker volume ls

# ดู metadata
docker volume inspect mydata
```

สังเกต `Mountpoint`:
```json
"Mountpoint": "/var/lib/docker/volumes/mydata/_data"
```

ดู path จริงบน host (ต้องใช้ sudo):
```bash
sudo ls /var/lib/docker/volumes/mydata/_data
# (ว่างอยู่)
```

---

## Step 2 — Data Persistence ข้าม Container

เขียนข้อมูลจาก container แรก:
```bash
docker run --rm \
  -v mydata:/data \
  alpine sh -c "echo 'hello from container 1' > /data/message.txt && date >> /data/message.txt"
```

ลบ container (--rm ลบให้อัตโนมัติ) แล้วอ่านจาก container ใหม่:
```bash
docker run --rm -v mydata:/data alpine cat /data/message.txt
# hello from container 1
# (วันที่)   ← ยังอยู่!
```

เพิ่มข้อมูลอีกครั้ง:
```bash
docker run --rm -v mydata:/data alpine \
  sh -c "echo 'hello from container 2' >> /data/message.txt"

docker run --rm -v mydata:/data alpine cat /data/message.txt
# ทั้งสองบรรทัด
```

---

## Step 3 — Volume กับ Database (Postgres)

pattern จริงสำหรับ database:

```bash
docker volume create pgdata

# รัน postgres พร้อม volume
docker run -d \
  --name pg1 \
  -v pgdata:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=testdb \
  postgres:16-alpine

sleep 5  # รอ postgres start

# สร้างตาราง + insert data
docker exec pg1 psql -U postgres -d testdb -c "
  CREATE TABLE users (id serial PRIMARY KEY, name text);
  INSERT INTO users (name) VALUES ('alice'), ('bob');
"

# ลบ container
docker rm -f pg1

# รัน postgres container ใหม่ด้วย volume เดิม
docker run -d \
  --name pg2 \
  -v pgdata:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=testdb \
  postgres:16-alpine

sleep 5

# ข้อมูลยังอยู่!
docker exec pg2 psql -U postgres -d testdb -c "SELECT * FROM users;"
#  id | name
# ----+-------
#   1 | alice
#   2 | bob

docker rm -f pg2
```

---

## Step 4 — Share Volume ระหว่าง Containers

หลาย containers mount volume เดียวกันได้พร้อมกัน:

```bash
# writer: เขียนข้อมูลทุก 2 วินาที
docker run -d --name writer \
  -v mydata:/data \
  alpine sh -c "while true; do date >> /data/log.txt; sleep 2; done"

# reader: อ่านข้อมูล
docker run --rm -v mydata:/data alpine tail -f /data/log.txt &
READER_PID=$!

sleep 6
kill $READER_PID 2>/dev/null
docker rm -f writer
```

> **ระวัง:** การเขียนพร้อมกันหลาย containers โดยไม่มี locking อาจทำให้ข้อมูล corrupt ใช้สำหรับ log aggregation หรือ config sharing เป็นหลัก

---

## Step 5 — Backup Volume

```bash
# backup: tar ข้อมูลใน volume ออกมาเป็น .tar.gz บน host
docker run --rm \
  -v mydata:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/mydata-backup.tar.gz -C /data .

ls -lh mydata-backup.tar.gz
```

---

## Step 6 — Restore Volume

```bash
# สร้าง volume ใหม่สำหรับ restore
docker volume create mydata-restored

# restore จาก backup
docker run --rm \
  -v mydata-restored:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/mydata-backup.tar.gz -C /data

# ตรวจสอบ
docker run --rm -v mydata-restored:/data alpine ls -la /data
```

---

## Step 7 — Anonymous Volume vs Named Volume

```dockerfile
# Dockerfile ที่มี VOLUME instruction
VOLUME /app/data
```

เมื่อรัน container จาก image นี้โดยไม่ระบุ -v → Docker สร้าง **anonymous volume** ให้อัตโนมัติ:

```bash
docker run -d --name anon-test postgres:16-alpine
docker inspect anon-test --format '{{json .Mounts}}' | python3 -m json.tool
# "Name": "a1b2c3d4..."  ← random hash — anonymous volume
```

anonymous volume ไม่มีชื่อ → หา + manage ยาก ควรระบุ `-v namedvolume:/path` เสมอ

---

## Step 8 — Cleanup

```bash
# ลบ volume ที่ไม่มี container ใช้อยู่
docker volume prune

# ลบ volume เฉพาะตัว
docker volume rm mydata mydata-restored pgdata

# ลบ backup file
rm -f mydata-backup.tar.gz
```

> **ระวัง:** `docker volume prune` ลบข้อมูลถาวร ตรวจสอบก่อนรันเสมอ

---

## สรุป Commands

| Command | ใช้ทำอะไร |
|---------|----------|
| `docker volume create name` | สร้าง named volume |
| `docker volume ls` | แสดงทุก volume |
| `docker volume inspect name` | ดู metadata + Mountpoint |
| `docker volume rm name` | ลบ volume |
| `docker volume prune` | ลบ volumes ที่ไม่มี container ใช้ |
| `-v name:/path` | mount named volume |
| `-v name:/path:ro` | mount read-only |
