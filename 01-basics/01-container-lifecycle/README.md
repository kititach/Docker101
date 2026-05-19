# Lab 01 — Container Lifecycle

## Objective

เข้าใจทุก state ของ container และคำสั่งที่ใช้จัดการ lifecycle ตั้งแต่เกิดจนตาย

## สิ่งที่จะได้เรียน

- State diagram ของ container
- `docker run` flags ที่สำคัญ
- ดู logs, inspect, stats, top, diff
- exec เข้าไปใน running container
- หยุด/ลบ container อย่างถูกต้อง

---

## Background: Container State Diagram

```
          docker run
              │
              ▼
          [created]
              │  docker start
              ▼
          [running] ◄──────────── docker restart
           │     │
docker     │     │ docker pause
stop/kill  │     ▼
           │  [paused]
           │     │ docker unpause
           │     ▼
           │  [running]
           ▼
         [exited] ──── docker start ──► [running]
              │
              │ docker rm
              ▼
           (gone)
```

---

## Step 1 — Build ตัวอย่าง App

```bash
cd app/
docker build -t hello-docker:1.0 .
```

ตรวจสอบว่า build สำเร็จ:
```bash
docker images hello-docker
```

คาดหวัง: เห็น image ขนาดประมาณ 60-70 MB

---

## Step 2 — Run Modes

### 2a. Foreground (ค้างหน้าจอ)
```bash
docker run --name demo-fg hello-docker:1.0
```
กด `Ctrl+C` เพื่อหยุด — สังเกตว่า container หยุดด้วย

### 2b. Detached (background)
```bash
docker run -d --name demo -p 8080:8080 hello-docker:1.0
```

ทดสอบ:
```bash
curl http://localhost:8080
# hello-docker | uptime: 3s | pid: 1
```

### 2c. ลบ container อัตโนมัติเมื่อหยุด
```bash
docker run --rm -d --name demo-temp -p 8081:8080 hello-docker:1.0
docker stop demo-temp
docker ps -a | grep demo-temp    # ไม่เจอ — ลบอัตโนมัติแล้ว
```

---

## Step 3 — ดูสถานะ

```bash
# ดู running containers
docker ps

# ดูทั้งหมด รวม stopped
docker ps -a

# ดูแบบกำหนด format เอง
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

---

## Step 4 — Logs

```bash
# ดู logs ทั้งหมด
docker logs demo

# follow แบบ real-time
docker logs -f demo

# ดู 10 บรรทัดล่าสุด
docker logs --tail 10 demo

# กรองด้วยเวลา
docker logs --since 1m demo

# เพิ่ม timestamp
docker logs -t demo
```

ลองสร้าง log ใหม่:
```bash
curl http://localhost:8080
curl http://localhost:8080
docker logs --tail 5 demo
```

---

## Step 5 — Inspect

```bash
# ดูข้อมูลทั้งหมด (JSON)
docker inspect demo

# ดูแค่ IP address
docker inspect -f '{{.NetworkSettings.IPAddress}}' demo

# ดูแค่ environment variables
docker inspect -f '{{range .Config.Env}}{{.}}{{"\n"}}{{end}}' demo

# ดูแค่ mount points
docker inspect -f '{{range .Mounts}}{{.Source}} → {{.Destination}}{{"\n"}}{{end}}' demo

# ดู exit code ของ stopped container
docker inspect -f '{{.State.ExitCode}}' demo
```

---

## Step 6 — Stats & Top

```bash
# resource usage แบบ real-time
docker stats demo

# snapshot ครั้งเดียว
docker stats --no-stream demo

# ดู process ใน container (เหมือน ps aux)
docker top demo
```

---

## Step 7 — Exec

```bash
# เปิด interactive shell
docker exec -it demo sh

# รันคำสั่งเดียวโดยไม่เข้า shell
docker exec demo cat /etc/os-release

# ดู environment variables ใน container
docker exec demo env

# ดู process tree
docker exec demo ps aux
```

ใน shell ลอง:
```bash
# อยู่ที่ไหน?
pwd         # /app

# ไฟล์อะไรอยู่บ้าง?
ls -la

# ออก
exit
```

---

## Step 8 — Pause / Unpause

```bash
# หยุดชั่วคราว (process ถูก freeze — ไม่ใช่ killed)
docker pause demo

# ทดสอบ: container ไม่ตอบ
curl --max-time 2 http://localhost:8080    # timeout

# ดูสถานะ
docker ps    # STATUS: Up X minutes (Paused)

# คืนสภาพ
docker unpause demo
curl http://localhost:8080    # ตอบกลับปกติ
```

> **ทำไม pause ถึงมีประโยชน์?** — ใช้ snapshot database หรือ freeze state ชั่วคราวโดยไม่ต้อง stop

---

## Step 9 — Stop vs Kill

```bash
# stop — ส่ง SIGTERM ก่อน รอ 10s แล้วค่อยส่ง SIGKILL
docker stop demo

# stop พร้อมกำหนด timeout (วินาที)
docker stop --time 3 demo

# kill — ส่ง SIGKILL ทันที (บังคับหยุด)
docker kill demo

# ส่ง signal เฉพาะ
docker kill --signal SIGUSR1 demo
```

สังเกต log ของ app เมื่อ `docker stop`:
```
SIGTERM received — shutting down gracefully
```

เปรียบเทียบกับ `docker kill` — ไม่มีบรรทัดนั้น เพราะ process ถูกฆ่าทันที

---

## Step 10 — Diff

```bash
# start container ใหม่
docker start demo

# สร้างไฟล์ใน container
docker exec demo sh -c "echo test > /tmp/myfile"

# ดูว่า filesystem เปลี่ยนอะไรบ้าง
docker diff demo
# A /tmp/myfile    (A = Added)
# C /tmp           (C = Changed)
```

สัญลักษณ์:
- `A` — Added (ไฟล์ใหม่)
- `C` — Changed (แก้ไข)
- `D` — Deleted (ลบ)

---

## Step 11 — Cleanup

```bash
# หยุด container
docker stop demo

# ลบ container
docker rm demo

# หรือทำพร้อมกัน
docker rm -f demo    # force remove แม้ container ยังรัน

# ลบ stopped containers ทั้งหมด
docker container prune

# ลบทุกอย่างที่ไม่ใช้ (ระวัง!)
# docker system prune
```

---

## Cheat Sheet

```
docker run -d --name <n> -p <host>:<ctr> <image>   รัน background + map port
docker ps / ps -a                                   ดู running / ทั้งหมด
docker logs -f <name>                               ดู log แบบ follow
docker inspect <name>                               ข้อมูลละเอียด (JSON)
docker stats --no-stream <name>                     resource snapshot
docker top <name>                                   process list
docker exec -it <name> sh                           เข้า shell
docker pause / unpause <name>                       freeze / unfreeze
docker stop <name>                                  SIGTERM → SIGKILL
docker kill <name>                                  SIGKILL ทันที
docker rm -f <name>                                 ลบทันที
docker container prune                              ลบ stopped containers
```

---

## Cleanup ทั้งหมด

```bash
docker rm -f demo demo-fg demo-temp 2>/dev/null || true
docker rmi hello-docker:1.0
```
