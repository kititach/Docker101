# Module 07 — Private Registry

Deploy private Docker registry แบบ self-hosted ตั้งแต่เริ่มจนถึง production-ready (auth + TLS + maintenance)

## Labs ในโมดูลนี้

| Lab | หัวข้อ | สิ่งที่จะได้เรียน |
|-----|--------|-----------------|
| [01-basics](./01-basics/) | Deploy & API | push, pull, registry HTTP API, storage layout |
| [02-auth](./02-auth/) | Basic Auth | htpasswd, docker login, API auth |
| [03-tls](./03-tls/) | TLS/HTTPS | self-signed cert, daemon trust, insecure-registries |
| [04-maintenance](./04-maintenance/) | Delete & GC | API delete, garbage-collect, reclaim disk |

## ทำไมต้อง Private Registry?

```
Public registry (Docker Hub, GHCR)            Private registry
─────────────────────────────────────         ──────────────────────────
✗ proprietary code อยู่ผิดที่                  ✓ ข้อมูลอยู่ใน infrastructure ตัวเอง
✗ ขึ้นกับ availability ของ provider            ✓ pull จาก LAN เร็วกว่า internet
✗ มี rate limit                               ✓ ไม่มี rate limit
✗ private repo ต้องจ่ายเงิน                    ✓ ฟรี (รัน registry:2)
✗ ลบ image ที่รั่วยาก                         ✓ control ทุก image ทุก tag
```

## Registry Image ที่ใช้

`registry:2` — official Docker registry, open source (CNCF Distribution project)

> มี options อื่นเช่น Harbor (multi-tenant + scan + sign), Nexus, JFrog Artifactory  
> ใน module นี้เน้น `registry:2` เพราะเป็น reference implementation
