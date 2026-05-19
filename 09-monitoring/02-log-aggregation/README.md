# Lab 02 — Log Aggregation: Loki + Promtail + Grafana

## Objective

Aggregate logs จากทุก containers เข้า central store + query ผ่าน Grafana — production-ready stack ที่ใช้ disk น้อย

---

## ทำไม Loki?

| | ELK (Elasticsearch + Kibana) | Loki + Grafana |
|-|-----------------------------|----------------|
| Storage | full-text index (กิน disk เยอะ) | index แค่ labels (เบามาก) |
| Query | Lucene query | LogQL (เหมือน PromQL) |
| Resource | JVM-heavy | Go binary, lightweight |
| Setup | ซับซ้อน | minimal |
| Cost-effective | low | high |
| Production scale | excellent | excellent (cloud native) |

---

## Architecture

```
┌──────────────┐  scrapes  ┌──────────────────────────┐
│  Containers  │ ────────▶ │ Promtail                 │
│  (any logs)  │           │ (Docker discovery + tail)│
└──────────────┘           └────────────┬─────────────┘
                                        │ push
                                        ▼
                           ┌──────────────────────────┐
                           │         Loki             │
                           │  (label-indexed store)   │
                           └────────────┬─────────────┘
                                        │ query
                                        ▼
                           ┌──────────────────────────┐
                           │       Grafana            │
                           │   (UI + dashboards)      │
                           └──────────────────────────┘
```

---

## Files

```
02-log-aggregation/
├── compose.yaml             — Loki + Promtail + Grafana + noisy-app
├── promtail-config.yaml     — Docker service discovery + relabel
├── grafana-datasource.yaml  — auto-provision Loki datasource
└── README.md
```

---

## Step 1 — Deploy Stack

```bash
docker compose up -d

# รอ ~15 วินาที ให้ Loki พร้อม
sleep 15

# ตรวจสอบ
curl http://localhost:3100/ready
# Ingester not ready: waiting for 15s after being ready
# (รอสักครู่แล้วเช็คใหม่ — จะตอบ "ready" หลัง 30-60s)
```

---

## Step 2 — เปิด Grafana

```
http://localhost:3000
```

- **Anonymous access เปิด + admin role** — ไม่ต้อง login
- Loki datasource ถูก provision ให้แล้ว
- ไปที่ `Explore` (icon เข็มทิศ) เลือก data source `Loki`

---

## Step 3 — Query Logs ผ่าน API

```bash
curl -sG "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={container="lab09-noisy"}' \
  --data-urlencode "start=$(date -d '5 minutes ago' +%s)000000000" \
  --data-urlencode "end=$(date +%s)000000000" \
  --data-urlencode 'limit=5' | python3 -m json.tool
```

ผล:
```json
{
  "status": "success",
  "data": {
    "result": [{
      "stream": {
        "container": "lab09-noisy",
        "service_name": "lab09-noisy",
        "stream": "stdout"
      },
      "values": [
        ["1779170287339482887", "Tue May 19 ... level=info user_id=81 event=request status=200"],
        ["1779170286338681233", "Tue May 19 ... level=info user_id=78 event=request status=200"]
      ]
    }]
  }
}
```

---

## Step 4 — LogQL Queries ใน Grafana Explore

```
# logs ของ container เดียว
{container="lab09-noisy"}

# logs ที่มี "user_id=42"
{container="lab09-noisy"} |= "user_id=42"

# regex match
{container="lab09-noisy"} |~ "user_id=(4[0-9]|5[0-5])"

# nested label extraction (LogQL)
{container="lab09-noisy"} | logfmt | user_id="42"

# rate ของ log ต่อวินาที (สร้าง metric จาก log)
rate({container="lab09-noisy"}[1m])

# count log line ใน 5 นาที
sum by (container) (count_over_time({container=~".+"}[5m]))
```

---

## Step 5 — Promtail Config Walkthrough

```yaml
clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker
    docker_sd_configs:                      # auto-discover containers
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:                        # ดึง labels จาก Docker
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: container             # → label `container`
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: stream                # → stdout/stderr
```

Promtail mount `/var/lib/docker/containers/:ro` + Docker socket → discover container ใหม่อัตโนมัติ ไม่ต้อง config ทีละตัว

---

## Step 6 — Add Container ใหม่ — Auto Discovered

```bash
docker run -d --name another-app alpine:3.20 \
  sh -c "while true; do echo 'another app log'; sleep 2; done"

# ใน Grafana Explore:
# {container="another-app"}
# ← เห็น logs ทันที โดยไม่แก้ promtail config
```

---

## Step 7 — Production Considerations

```
□ Loki ตั้ง retention (default 7 วัน) ใน config
□ Promtail rate limit เพื่อไม่ overload Loki
□ ใช้ external storage backend (S3, GCS) สำหรับ scale
□ Grafana ตั้ง alerting rule (เช่น error rate > X)
□ structured logging ทุก service (JSON / logfmt)
□ ไม่ใส่ secret/PII ใน log lines
```

---

## Cleanup

```bash
docker compose down -v
```

---

## เปรียบเทียบ Approach สำหรับ Aggregation

| Approach | Setup | Disk | Recommended |
|----------|-------|------|-------------|
| docker logging driver → fluentd | ต้อง config ทุก container | ขึ้นกับ backend | enterprise + fluentd ecosystem |
| Promtail tail + Loki | scrape อัตโนมัติ | น้อย (label index) | ✅ default ใหม่ |
| Filebeat + ELK | medium | สูง | ทีมที่ใช้ ELK อยู่แล้ว |
| Vector / OpenTelemetry | high | medium | unified logs + metrics + traces |
