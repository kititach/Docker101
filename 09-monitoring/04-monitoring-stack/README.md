# Lab 04 — Monitoring Stack: cAdvisor + Prometheus + Grafana

## Objective

ตั้ง production-grade observability stack สำหรับ metrics — เห็น container/host usage แบบ time-series + dashboard

---

## Architecture

```
                   scrape (every 10s)
┌──────────────┐  ─────────────────────▶ ┌─────────────┐
│  cAdvisor    │                          │             │
│  (container  │                          │  Prometheus │
│   metrics)   │                          │  (TSDB)     │
└──────────────┘                          │             │
                                          │             │
┌──────────────┐  ─────────────────────▶ │             │
│ node-exporter│                          │             │
│ (host metrics│                          └──────┬──────┘
│   - CPU/MEM/ │                                 │
│     DISK/NET)│                                 │ query
└──────────────┘                                 ▼
                                          ┌─────────────┐
                                          │   Grafana   │
                                          │ (dashboards)│
                                          └─────────────┘
```

---

## Files

```
04-monitoring-stack/
├── compose.yaml             — full stack
├── prometheus.yml           — scrape config
├── grafana-datasource.yaml  — auto-provision Prometheus datasource
└── README.md
```

---

## Step 1 — Deploy Stack

```bash
docker compose up -d

# รอ ~20 วินาที
sleep 20
```

ตรวจสอบ targets:
```bash
curl -s http://localhost:9090/api/v1/targets | python3 -c "
import json, sys
data = json.load(sys.stdin)
for t in data['data']['activeTargets']:
    print(f\"  {t['labels']['job']:12s} {t['health']}\")
"
# prometheus    up
# cadvisor      up
# node          up
```

---

## Step 2 — เปิด Grafana

```
http://localhost:3000
```

Anonymous admin access เปิดอยู่ — เข้าได้เลย ไม่ต้อง login  
Prometheus datasource ถูก provision ให้แล้ว

---

## Step 3 — Node Exporter Queries (Host Metrics)

✅ **node-exporter ทำงานสมบูรณ์บน Docker 29**

```bash
# CPU usage %
curl -sG "http://localhost:9090/api/v1/query" \
  --data-urlencode 'query=100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)'
# → CPU usage: 14.5%

# Memory usage %
curl -sG "http://localhost:9090/api/v1/query" \
  --data-urlencode 'query=100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)'
# → Memory usage: 20.1%

# Disk usage
curl -sG "http://localhost:9090/api/v1/query" \
  --data-urlencode 'query=100 * (1 - node_filesystem_avail_bytes{mountpoint="/rootfs"} / node_filesystem_size_bytes{mountpoint="/rootfs"})'

# Network throughput
curl -sG "http://localhost:9090/api/v1/query" \
  --data-urlencode 'query=rate(node_network_receive_bytes_total{device!="lo"}[1m])'
```

Import Grafana dashboard **Node Exporter Full** (ID: `1860`):  
Grafana → Dashboards → New → Import → 1860 → Load → Prometheus = Prometheus

---

## Step 4 — cAdvisor (Container Metrics)

> **⚠️ ข้อจำกัดที่เจอจริง:** Docker 29.x ใช้ storage driver ใหม่ชื่อ `overlayfs`  
> cAdvisor v0.49.1 รู้จักแค่ `overlay2` → enrich per-container metrics ไม่ได้  
> 
> Error ใน cAdvisor logs:
> ```
> Failed to identify the read-write layer ID for container ...
> open /rootfs/var/lib/docker/image/overlayfs/layerdb/mounts/...: no such file or directory
> ```
>
> **Workaround options:**
> 1. รอ cAdvisor support `overlayfs` storage driver (เปิด issue ใน GitHub)
> 2. เปลี่ยน Docker storage driver กลับเป็น `overlay2` ใน `/etc/docker/daemon.json`:
>    ```json
>    {"storage-driver": "overlay2"}
>    ```
> 3. ใช้ Docker daemon built-in metrics (เพิ่ม `"metrics-addr": "0.0.0.0:9323"` ใน daemon.json)
> 4. ใช้ exporter อื่น เช่น `docker_stats_exporter`

หลังจาก workaround → query metrics ตาม:

```promql
# top 5 containers by CPU
topk(5, rate(container_cpu_usage_seconds_total{name!=""}[1m]))

# top 5 containers by memory
topk(5, container_memory_usage_bytes{name!=""}) / 1024 / 1024

# container restart count
changes(container_start_time_seconds{name!=""}[1h])

# network: bytes received per container
rate(container_network_receive_bytes_total{name!=""}[1m])
```

Import Grafana dashboard **Docker Containers** (ID: `893` หรือ `19792`)

---

## Step 5 — Build Custom Query

Grafana → Explore → เลือก Prometheus

```promql
# rate of HTTP requests per second
rate(nginx_http_requests_total[1m])

# 95th percentile request latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# error rate %
100 * rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])
```

แอป production ควร export metrics ของตัวเอง (`/metrics` endpoint) ผ่าน:
- Python: `prometheus_client`
- Node.js: `prom-client`
- Go: `prometheus/client_golang`
- Java: `micrometer-registry-prometheus`

---

## Step 6 — Setup Alerting

```yaml
# alerts.yml
groups:
  - name: container_alerts
    rules:
      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes{name!=""} / container_spec_memory_limit_bytes > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} > 90% memory limit"

      - alert: ContainerRestart
        expr: changes(container_start_time_seconds[10m]) > 3
        labels:
          severity: critical
        annotations:
          summary: "Container {{ $labels.name }} restarted >3 times in 10min"
```

เพิ่มใน prometheus.yml:
```yaml
rule_files:
  - alerts.yml
```

แล้ว reload:
```bash
curl -X POST http://localhost:9090/-/reload
```

ดูใน Prometheus UI: `http://localhost:9090/alerts`

Production: ใช้ Alertmanager → Slack/PagerDuty/email

---

## Step 7 — Useful PromQL Cheatsheet

| Query | ใช้ทำอะไร |
|-------|----------|
| `rate(metric[1m])` | per-second rate ใน 1 นาที |
| `increase(metric[5m])` | เพิ่มขึ้นใน 5 นาที |
| `sum by (label) (metric)` | aggregate group ตาม label |
| `topk(5, metric)` | top 5 |
| `histogram_quantile(0.95, ...)` | percentile จาก histogram |
| `metric{label="value"}` | filter |
| `metric{label=~"v1\|v2"}` | regex |
| `predict_linear(metric[1h], 3600)` | ทำนาย 1h ข้างหน้า |
| `up{job="api"} == 0` | service down |

---

## Cleanup

```bash
docker compose down -v
```

---

## Production Stack Checklist

```
□ scrape_interval 10-30s (ไม่เร็วเกิน — กิน CPU+disk)
□ Prometheus retention (default 15d)
□ remote_write ไป cloud (Grafana Cloud, Mimir) สำหรับ long-term
□ Grafana ไม่ใช้ anonymous access ใน production
□ Alertmanager + Slack/PagerDuty integration
□ ทุก service มี /metrics endpoint
□ SLO/SLI dashboard (availability, latency, error rate)
□ Runbook link ใน alert annotation
```

---

## Resources

- Grafana dashboards: https://grafana.com/grafana/dashboards/
- PromQL docs: https://prometheus.io/docs/prometheus/latest/querying/basics/
- cAdvisor metrics: https://github.com/google/cadvisor/blob/master/docs/storage/prometheus.md
- Node Exporter metrics: https://github.com/prometheus/node_exporter
