# Lab 04 — Volume Drivers

## Objective

เข้าใจ volume driver ecosystem — local driver options, และภาพรวมของ drivers สำหรับ production

---

## Volume Driver คืออะไร

Volume driver เป็น plugin ที่บอก Docker ว่าจะ store ข้อมูลที่ไหนและอย่างไร  
Default driver คือ `local` — เก็บบน host filesystem

```bash
docker volume create mydata
docker volume inspect mydata --format '{{.Driver}}'
# local
```

---

## Step 1 — Local Driver Options

`local` driver รองรับ options เพิ่มเติมผ่าน `--opt` — ให้ความยืดหยุ่นมากกว่า default

**จำกัดขนาด volume (ต้องใช้ xfs filesystem):**
```bash
# ทดสอบว่า root filesystem เป็น xfs หรือไม่
df -T / | awk 'NR==2{print $2}'
```

> บนระบบที่ใช้ ext4 การจำกัดขนาดด้วย local driver ทำได้จำกัด — ใช้ quota-based approach แทน

**Local driver แบบ tmpfs (volume ที่ใช้ RAM):**
```bash
docker volume create \
  --driver local \
  --opt type=tmpfs \
  --opt device=tmpfs \
  --opt o=size=50m,noexec \
  mem-volume

docker volume inspect mem-volume

# ใช้งาน
docker run --rm -v mem-volume:/data alpine sh -c "
  df -h /data
  echo 'in memory' > /data/test.txt
  cat /data/test.txt
"

docker volume rm mem-volume
```

**Local driver แบบ bind (named volume ที่ชี้ไป path เฉพาะ):**
```bash
mkdir -p /tmp/mydata

docker volume create \
  --driver local \
  --opt type=none \
  --opt device=/tmp/mydata \
  --opt o=bind \
  path-volume

# ใช้ชื่อ volume แทน path — portable กว่า hard-code path ใน -v
docker run --rm -v path-volume:/data alpine sh -c "echo 'hello' > /data/test.txt"
ls /tmp/mydata/
# test.txt

docker volume rm path-volume
rm -rf /tmp/mydata
```

---

## Step 2 — NFS Volume (overview)

NFS volume ให้ container mount network filesystem จาก server อื่น:

```bash
# (ต้องการ NFS server จริง — ตัวอย่างนี้ดู syntax เท่านั้น)
docker volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=192.168.1.10,rw \
  --opt device=:/exports/mydata \
  nfs-volume
```

ทางเลือกที่ง่ายกว่าใน Compose:
```yaml
volumes:
  nfs-data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=192.168.1.10,rw
      device: ":/exports/mydata"
```

---

## Step 3 — Third-Party Volume Drivers

ecosystem ของ volume drivers สำหรับ production:

| Driver | ใช้กับ | ใช้งาน |
|--------|--------|--------|
| `local` | host filesystem | default, dev/single-host |
| `nfs` | NFS server | shared storage บน premises |
| `rexray/ebs` | AWS EBS | EC2 instances |
| `rexray/s3fs` | AWS S3 | object storage |
| `azure-file` | Azure Files | Azure VMs |
| `vsphere` | VMware | vSphere environments |
| `portworx` | Portworx cluster | production Kubernetes |

ติดตั้ง plugin:
```bash
# ตัวอย่าง (ไม่รันใน lab นี้)
docker plugin install rexray/ebs
docker plugin ls
```

---

## Step 4 — Volume Labels และ Metadata

```bash
# สร้าง volume พร้อม labels
docker volume create \
  --label project=myapp \
  --label env=production \
  --label owner=team-backend \
  labeled-vol

# filter ด้วย label
docker volume ls --filter label=project=myapp
docker volume ls --filter label=env=production

# ดู labels
docker volume inspect labeled-vol --format '{{json .Labels}}'

docker volume rm labeled-vol
```

---

## Step 5 — Volume ใน Docker Compose

การกำหนด volume ใน Compose file:

```yaml
services:
  db:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data

  app:
    image: myapp:1.0
    volumes:
      - ./src:/app:ro          # bind mount (dev)
      - appdata:/app/data      # named volume
      - type: tmpfs            # tmpfs (verbose syntax)
        target: /app/cache
        tmpfs:
          size: 52428800  # 50MB

volumes:
  pgdata:        # managed by Docker (default local driver)
  appdata:
    driver: local
    driver_opts:
      type: tmpfs
      device: tmpfs
      o: size=100m
```

---

## Cleanup

```bash
# ลบ volumes ที่สร้างใน lab นี้
docker volume prune -f
```

---

## สรุป: เลือก Mount Type อย่างไร

```
ต้องการ persist ข้อมูลข้าม container restart?
├── ใช่ → ต้องการ control path เอง?
│         ├── ใช่ → Bind Mount หรือ local driver (type=none)
│         └── ไม่  → Named Volume (Docker manage)
└── ไม่  → ต้องการ I/O เร็ว / ไม่เขียน disk?
           ├── ใช่ → tmpfs
           └── ไม่  → Named Volume (แต่ระวัง disk I/O)

ข้อมูลอยู่บนเครื่องเดียว → local driver
ข้อมูลต้องแชร์ข้าม hosts  → NFS / cloud volume driver
```
