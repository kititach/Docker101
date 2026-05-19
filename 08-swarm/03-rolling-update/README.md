# Lab 03 — Rolling Updates + Rollback

## Objective

Update service โดยไม่มี downtime — ค่อย ๆ เปลี่ยน tasks ทีละ batch + auto rollback ถ้า fail

---

## ผลวัดจริง

| Operation | เวลา | ผล |
|-----------|------|----|
| Update image (4 replicas, parallelism=2) | ~25s | 2 batches × (5s delay + 10s monitor) |
| Rollback | ~17s | กลับ image เก่า ครบทุก task |

---

## Step 1 — Deploy Service ที่มี Update Config

```yaml
# compose.yaml
services:
  web:
    image: nginxdemos/hello:plain-text
    ports: ["9083:80"]
    deploy:
      replicas: 4
      update_config:
        parallelism: 2          # update 2 tasks พร้อมกัน (จาก 4)
        delay: 5s               # รอ 5s ระหว่าง batch
        order: start-first      # start ตัวใหม่ → kill ตัวเก่า (zero-downtime)
        failure_action: rollback
        monitor: 10s            # ดู task ใหม่ 10s ก่อนถือว่า healthy
        max_failure_ratio: 0.3  # ถ้า >30% fail → rollback
      rollback_config:
        parallelism: 2
        delay: 5s
        order: start-first
```

```bash
docker stack deploy -c compose.yaml upd
```

---

## Step 2 — Update Image (Rolling)

```bash
time docker service update --image nginx:1.27-alpine upd_web
```

ระหว่างที่ update:
- **t=0:** start task 1+2 (image ใหม่) → wait running → monitor 10s
- **t=15:** kill task 1+2 (image เก่า)
- **t=20:** delay 5s
- **t=20:** start task 3+4 (image ใหม่) → monitor 10s
- **t=35:** kill task 3+4 (image เก่า)
- **t=35:** converged ✅

ดู history ของแต่ละ task:
```bash
docker service ps upd_web --format "{{.Name}}\t{{.Image}}\t{{.CurrentState}}"
# upd_web.1   nginx:1.27-alpine               Running 20 seconds ago
# upd_web.1   nginxdemos/hello:plain-text     Shutdown 17 seconds ago
# upd_web.2   nginx:1.27-alpine               Running 20 seconds ago
# upd_web.2   nginxdemos/hello:plain-text     Shutdown 17 seconds ago
# upd_web.3   nginx:1.27-alpine               Running 10 seconds ago
# upd_web.3   nginxdemos/hello:plain-text     Shutdown 6 seconds ago
# upd_web.4   nginx:1.27-alpine               Running 10 seconds ago
# upd_web.4   nginxdemos/hello:plain-text     Shutdown 6 seconds ago
```

แต่ละ task มี 2 records — Running ตัวใหม่ + Shutdown ตัวเก่า

---

## Step 3 — Zero-Downtime ระหว่าง Update

```bash
# รัน curl loop ใน background ตอน update
while true; do
  echo "$(date +%T) → $(curl -s --max-time 1 -o /dev/null -w '%{http_code}' http://127.0.0.1:9083/)"
  sleep 0.5
done &
LOOP_PID=$!

docker service update --image nginx:1.27 upd_web
# ผล: HTTP 200 ทุก request — ไม่มี downtime

kill $LOOP_PID
```

`order: start-first` คือกุญแจ — ทำให้ task ใหม่ healthy ก่อนค่อย stop ตัวเก่า

---

## Step 4 — Update Configuration อื่น ๆ

```bash
# scale ผ่าน service update
docker service update --replicas 6 upd_web

# เปลี่ยน resource limits
docker service update --limit-memory 128M --limit-cpu 0.25 upd_web

# เปลี่ยน env var
docker service update --env-add LOG_LEVEL=debug upd_web

# เพิ่ม mount
docker service update --mount-add type=volume,source=mydata,target=/data upd_web
```

ทุก command trigger rolling update ตาม update_config ที่ตั้งไว้

---

## Step 5 — Rollback

```bash
time docker service rollback upd_web
# verify: Service upd_web converged
# real    0m16.853s
```

ดู task history:
```bash
docker service ps upd_web --format "{{.Name}}\t{{.Image}}\t{{.CurrentState}}"
# upd_web.1   nginxdemos/hello:plain-text  Running 12 seconds ago   ← rolled back
# upd_web.1   nginx:1.27-alpine            Shutdown 8 seconds ago
# upd_web.1   nginxdemos/hello:plain-text  Shutdown 46 seconds ago   ← original
```

Swarm เก็บ **previous spec** เป็น `rollback_spec` — rollback กลับได้ 1 step  
(rollback อีกรอบ = rollback ของ rollback = กลับมา image ใหม่)

---

## Step 6 — Auto Rollback ถ้า Update Fail

```bash
# update ไป image ที่ไม่มีจริง
docker service update --image nginx:nonexistent-tag upd_web

# Swarm พยายาม pull → fail → trigger failure_action: rollback
# → service กลับมา image เดิม
```

ตรวจสอบ:
```bash
docker service inspect upd_web --format '{{.UpdateStatus.State}} {{.UpdateStatus.Message}}'
# rollback_completed  rollback completed
```

---

## Step 7 — Update Strategies

| `order` | พฤติกรรม | ใช้กับ |
|---------|---------|--------|
| `stop-first` (default) | kill ตัวเก่า → start ตัวใหม่ | stateful service (DB) ที่ต้องการ singleton |
| `start-first` | start ตัวใหม่ → kill ตัวเก่า | stateless web app (zero-downtime) |

| `failure_action` | พฤติกรรม |
|------------------|---------|
| `pause` (default) | หยุด update รอ manual intervention |
| `continue` | continue update แม้ task fail |
| `rollback` | revert spec |

---

## Cleanup

```bash
docker stack rm upd
```

---

## Rolling Update Checklist

```
□ order: start-first สำหรับ stateless service
□ monitor period พอที่จะ detect crash (10-30s)
□ failure_action: rollback (อย่าใช้ pause ใน prod)
□ healthcheck ใน Dockerfile / compose — Swarm รอ healthy ก่อนนับว่า running
□ parallelism เล็ก ๆ ก่อน (1-2) ดู behavior ก่อนเพิ่ม
□ ทดสอบ rollback ใน staging ก่อน
□ image ใช้ digest (sha256) ดีกว่า tag — guarantee version
```
