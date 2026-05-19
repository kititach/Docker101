# Lab 03 — Resource Limits

## Objective

จำกัด CPU, memory, processes ที่ container ใช้ — ป้องกันให้ container ตัวเดียวฉุดทั้ง host

---

## ทำไมต้องจำกัด?

```
default container ไม่มี limit — รันไปจน OOM-kill host

✗ memory leak ใน container A → ใช้ RAM หมด → kernel kill process random
✗ fork bomb ใน container B → process table เต็ม → host hang
✗ CPU spike ใน container C → container อื่นไม่ได้ CPU
```

---

## ผลวัดจริง

| Test | ผล |
|------|----|
| `--memory 50m`, allocate 100MB | exit 137, OOMKilled=true |
| `--memory 50m`, allocate 30MB | OK |
| CPU loop, `--cpus 0.5` | 52s |
| CPU loop, no limit | 23s (2.3x เร็วกว่า) |
| `--pids-limit 50`, fork 200 procs | "can't fork: Resource temporarily unavailable" |

---

## Step 1 — Memory Limit + OOM

```bash
# limit 50MB, app พยายาม allocate 100MB
docker run --memory 50m --memory-swap 50m --name oom python:3.12-alpine \
  python3 -c "a = bytearray(100*1024*1024); print('OK')"

echo "exit code: $?"
# exit code: 137   ← SIGKILL จาก OOM killer

docker inspect oom --format '{{.State.OOMKilled}}'
# true

docker rm oom
```

> `137` = `128 + 9` (SIGKILL) — convention ของ shell exit code  
> `--memory-swap` = `--memory` → ปิด swap (ไม่งั้นจะ swap ก่อน OOM)

ทำไมต้องตั้งทั้งสอง:
- `--memory` = RAM limit
- `--memory-swap` = RAM + swap limit
- ถ้าไม่ตั้ง memory-swap → default = 2x memory → container ใช้ swap ได้ → ช้าแต่ไม่ OOM

---

## Step 2 — Memory ที่ใช้ได้ภายใน Limit

```bash
docker run --rm --memory 50m --memory-swap 50m python:3.12-alpine \
  python3 -c "a = bytearray(30*1024*1024); print('allocated 30MB OK')"
# allocated 30MB OK
```

---

## Step 3 — CPU Limit

```bash
# ไม่มี limit
time docker run --rm alpine:3.20 \
  sh -c "for i in \$(seq 1 50000000); do :; done"
# real    0m23s   ← ใช้ CPU เต็ม core

# limit 0.5 CPU (= 50% ของ 1 core)
time docker run --rm --cpus 0.5 alpine:3.20 \
  sh -c "for i in \$(seq 1 50000000); do :; done"
# real    0m52s   ← ใช้เวลา 2.3x
```

`--cpus 1.5` = ใช้ได้สูงสุด 1.5 cores (150%)  
`--cpus 0.25` = ใช้ได้สูงสุด 25% ของ 1 core

ทางเลือกอื่น:
```bash
# CPU pinning
docker run --cpuset-cpus="0,1" myapp   # ใช้ได้แค่ core 0, 1

# Relative weight (เมื่อแย่ง CPU)
docker run --cpu-shares=512 myapp      # default 1024 → 512 = ครึ่งหนึ่งของ default
```

---

## Step 4 — PIDs Limit (กัน Fork Bomb)

Fork bomb: process spawn เร็วเรื่อย ๆ → process table เต็ม

```bash
# limit 50 processes, fork 200 → จะ fail ตอน process ที่ 51
docker run --rm --pids-limit 50 alpine:3.20 \
  sh -c "for i in \$(seq 1 200); do sh -c 'sleep 30' & done; wait"
# sh: can't fork: Resource temporarily unavailable
```

> **ทุก container ที่รัน Node.js, JVM, Python multiprocessing — ต้องมี pids-limit**

---

## Step 5 — ulimits

จำกัด resource ที่ละเอียดกว่า limits ปกติ:

```bash
docker run --rm \
  --ulimit nofile=1024:2048 \      # max open files
  --ulimit nproc=100 \             # max processes ของ user
  --ulimit core=0 \                # ไม่ให้ dump core file
  alpine:3.20 \
  sh -c "ulimit -n; ulimit -u"
# 1024
# 100
```

---

## Step 6 — docker stats

ดู usage real-time:

```bash
docker run -d --name app --memory 100m --cpus 0.5 \
  python:3.12-alpine python3 -c "
import time
a = bytearray(40*1024*1024)
while True: time.sleep(1)
"

docker stats --no-stream app
# CONTAINER ID   NAME   CPU %     MEM USAGE / LIMIT     MEM %     PIDS
# abc123def      app    0.00%     40.5MiB / 100MiB      40.50%    1
```

Format ที่ใช้ใน script:
```bash
docker stats --no-stream --format \
  "{{.Name}}: CPU={{.CPUPerc}} MEM={{.MemUsage}}/{{.MemPerc}} PIDS={{.PIDs}}"
# app: CPU=0.00% MEM=40.5MiB / 100MiB/40.50% PIDS=1

docker rm -f app
```

---

## Step 7 — Limits ใน Compose

```yaml
services:
  app:
    image: myapp
    mem_limit: 256m              # short syntax
    mem_reservation: 128m        # soft limit
    cpus: 0.5
    pids_limit: 100
    ulimits:
      nofile: { soft: 1024, hard: 2048 }
      nproc: 100
    # หรือใน deploy block (Swarm)
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 256M
        reservations:
          cpus: "0.25"
          memory: 128M
```

ความต่าง:
- `mem_limit` (Compose v2) — single host
- `deploy.resources.limits` — Swarm-aware
- ใช้ทั้งคู่ได้ — Compose runtime อ่าน `mem_limit`, Swarm อ่าน `deploy.*`

---

## Step 8 — Reservation vs Limit

```yaml
deploy:
  resources:
    limits:        memory: 256M     # ห้ามใช้เกิน
    reservations:  memory: 128M     # guarantee อย่างน้อย 128M
```

- **limit** = hard ceiling (OOM ถ้าเกิน)
- **reservation** = soft floor (scheduler ทึกทักให้ container ก่อน)

---

## Step 9 — Real-World Sizing Guide

```
แอป         | memory   | cpus   | pids
------------|----------|--------|-------
nginx       | 64-128M  | 0.25   | 50
Flask/Django| 256M     | 0.5    | 100
Node.js     | 512M     | 0.5    | 100
JVM service | 1G+      | 1.0+   | 200
Postgres    | 512M-2G  | 1.0+   | 100
Redis       | 256M-1G  | 0.5    | 50
```

วัดด้วย `docker stats` หรือ Prometheus (Lab 04) ก่อน set production limit

---

## Resource Limits Checklist

```
□ ทุก container production ตั้ง --memory + --memory-swap
□ ทุก container production ตั้ง --cpus
□ ทุก container production ตั้ง --pids-limit
□ ตั้ง ulimits ถ้า workload เปิด file descriptors เยอะ (DB, proxy)
□ Monitor ด้วย docker stats / Prometheus เพื่อ tune limit
□ container ที่ถูก OOMKilled = limit ต่ำเกินไป — เพิ่ม
□ container ที่ throttle (CPU stuck < limit) = CPU limit ต่ำเกินไป
```
