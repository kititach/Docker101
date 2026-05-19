# Module 09 — Logging & Monitoring

ตั้งแต่ logs ที่ Docker เก็บอยู่แล้ว ไปจนถึง full observability stack ด้วย Prometheus + Grafana

## Labs ในโมดูลนี้

| Lab | หัวข้อ | สิ่งที่จะได้เรียน |
|-----|--------|-----------------|
| [01-logging-drivers](./01-logging-drivers/) | Log Drivers | json-file rotation, journald, syslog, fluentd |
| [02-log-aggregation](./02-log-aggregation/) | Log Aggregation | Loki + Grafana stack, query logs จากหลาย containers |
| [03-resource-limits](./03-resource-limits/) | Resource Limits | CPU/Memory/PIDs limits, docker stats, OOM behavior |
| [04-monitoring-stack](./04-monitoring-stack/) | Metrics Stack | cAdvisor + Prometheus + Grafana, dashboard จริง |

## Observability 3 Pillars

```
Logs        — "อะไรเกิดขึ้น"        → Loki / ELK / CloudWatch Logs
Metrics     — "ตัวเลขอะไร, แค่ไหน"  → Prometheus / VictoriaMetrics / Datadog
Traces      — "เกิดที่ไหนใน flow"   → Jaeger / Tempo / OpenTelemetry
```

Module นี้ครอบคลุม logs + metrics (traces ไม่อยู่ใน scope)
