# Lab 01 — Log Drivers + Rotation

## Objective

เข้าใจ log drivers ทุกตัว + ตั้ง rotation ที่ถูกต้องเพื่อป้องกัน disk เต็มจาก container logs

---

## ผลวัดจริง: Rotation Working

ตั้ง `max-size=10k`, `max-file=3` แล้ว run log-spam container ~3 วินาที:

```
-rw-r----- root 7.0K  ...-json.log      ← active (กำลังเขียน)
-rw-r----- root 9.9K  ...-json.log.1    ← rotated (เต็มที่ 10k)
-rw-r----- root 9.9K  ...-json.log.2    ← rotated
```

รวมไม่เกิน ~30k — ไม่มี log file ที่ 4 แม้ container เขียน log ตลอด

---

## Log Drivers ทั้งหมด

```
json-file (default)    เก็บไฟล์บน host
journald               ส่งไป systemd journal
syslog                 ส่ง syslog (rfc5424/3164)
fluentd                ส่ง Fluentd / Fluent Bit
gelf                   Graylog Extended Log Format
awslogs                AWS CloudWatch Logs
splunk                 Splunk HEC
loki                   Grafana Loki (ต้องติดตั้ง plugin)
none                   ปิด logging
local                  binary format (เร็วกว่า json-file)
```

ดู default driver:
```bash
docker info | grep "Logging Driver"
# Logging Driver: json-file
```

---

## Step 1 — Default Driver (json-file)

```bash
docker run -d --name app1 alpine:3.20 \
  sh -c "while true; do echo 'hello $(date)'; sleep 1; done"

# log path บน host
docker inspect app1 --format '{{.LogPath}}'
# /var/lib/docker/containers/<id>/<id>-json.log

# ดู logs
docker logs app1 | head -3
docker logs --since 1m app1
docker logs --tail 5 -f app1
```

---

## Step 2 — ⚠️ ปัญหา: Default ไม่มี Rotation

```bash
# default json-file ไม่มี max-size + max-file → file โตได้ unlimited
docker info | grep -A3 "Log Options"
```

ถ้าไม่ตั้ง rotation:
- log file โตเรื่อย ๆ
- disk เต็มได้
- `docker logs` ค้างเพราะอ่านไฟล์ใหญ่

---

## Step 3 — Per-Container Rotation

```bash
docker run -d --name app2 \
  --log-driver json-file \
  --log-opt max-size=10k \
  --log-opt max-file=3 \
  alpine:3.20 sh -c "while true; do echo 'log line'; done"

# ดูไฟล์
CID=$(docker inspect app2 --format '{{.Id}}')
docker run --rm -v /var/lib/docker:/d:ro alpine:3.20 \
  ls -lh /d/containers/$CID/ | grep json
```

ผลที่ได้:
```
-rw-r----- root 7K   ...-json.log       ← active
-rw-r----- root 10K  ...-json.log.1     ← rotated
-rw-r----- root 10K  ...-json.log.2     ← rotated (oldest, ลบเป็นตัวต่อไป)
```

---

## Step 4 — Daemon-Wide Default Rotation

ตั้ง default ให้ทุก container — แก้ `/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

```bash
sudo systemctl restart docker
docker info | grep -A5 "Logging Driver\|Log Options"
```

หลังจากนี้ ทุก container ใหม่ใช้ rotation อัตโนมัติ

---

## Step 5 — journald Driver (Linux)

ส่ง log เข้า systemd journal:

```bash
docker run -d --name jrn \
  --log-driver journald \
  --log-opt tag="{{.Name}}/{{.ID}}" \
  alpine:3.20 sh -c "while true; do echo 'journal log'; sleep 2; done"

# ดู log
journalctl CONTAINER_NAME=jrn -n 5
# หรือ
journalctl -t "jrn/$(docker inspect jrn --format '{{.Id}}' | head -c 12)"

# docker logs ทำงานแค่ json-file/journald/local — ไม่ทำงานกับ syslog/fluentd
docker logs jrn  # ได้

docker rm -f jrn
```

**ประโยชน์ journald:**
- รวมเข้า system journal — ใช้ `journalctl` query แบบ structured ได้
- Rotation ตั้งใน journald (`/etc/systemd/journald.conf`)
- ไม่ต้องตั้ง per-container

---

## Step 6 — syslog Driver

ส่ง log ไป syslog server:

```bash
docker run -d --name syslog-app \
  --log-driver syslog \
  --log-opt syslog-address=udp://192.168.1.100:514 \
  --log-opt tag="myapp" \
  myapp

# docker logs ใช้ไม่ได้ — ต้องไปดูที่ syslog server
docker logs syslog-app  # Error
```

---

## Step 7 — fluentd Driver

```bash
docker run -d --name fluent-app \
  --log-driver fluentd \
  --log-opt fluentd-address=localhost:24224 \
  --log-opt tag=docker.{{.Name}} \
  myapp
```

ใช้กับ Fluentd / Fluent Bit ที่ aggregate logs จากหลาย sources

---

## Step 8 — none Driver (ปิด logging)

```bash
docker run -d --log-driver none myapp
docker logs <container>  # Error: configured logging driver does not support reading
```

ใช้กับ batch job ที่เขียน log ลง external system อยู่แล้ว — ประหยัด disk

---

## Step 9 — Structured Logging (Best Practice)

แทนที่จะ `echo "user X logged in"` ให้ใช้ JSON:

```python
import json
print(json.dumps({"event": "login", "user_id": 42, "ip": "1.2.3.4"}))
```

ผล:
```json
{"event": "login", "user_id": 42, "ip": "1.2.3.4"}
```

query ง่ายในเครื่องมือ aggregation:
```
{container="app"} |= "login" | json | user_id="42"
```

---

## Cleanup

```bash
docker rm -f $(docker ps -aq -f name=app)
```

---

## Logging Checklist

```
□ daemon.json มี max-size + max-file (default rotation)
□ structured logging (JSON) เสมอใน production
□ ส่ง log ไป stdout/stderr (ไม่เขียน file ใน container)
□ ไม่ log secret/PII
□ tag/label container ให้ filter ได้ใน aggregator
□ พิจารณา log driver:
   - dev / single host  → json-file + rotation
   - system integration → journald
   - aggregation        → fluentd / loki / gelf (Lab 02)
```
