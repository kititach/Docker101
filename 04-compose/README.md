# Module 04 — Docker Compose

จัดการ multi-container application ด้วย YAML เดียว — ตั้งแต่ basics จนถึง production pattern

## Labs ในโมดูลนี้

| Lab | หัวข้อ | สิ่งที่จะได้เรียน |
|-----|--------|-----------------|
| [01-basics](./01-basics/) | Compose Basics | services, ports, env, volumes, networks, restart |
| [02-depends-healthcheck](./02-depends-healthcheck/) | Startup Order | depends_on, healthcheck conditions, race condition |
| [03-profiles](./03-profiles/) | Profiles | dev vs debug services, selective startup |
| [04-secrets](./04-secrets/) | Secrets | file-based secrets, ไม่ใส่ password ใน env |
| [05-override](./05-override/) | Override Files | base + dev override + prod config |

## Compose File Format

ใช้ `compose.yaml` (ไม่ใช่ `docker-compose.yml` แบบเก่า) และ Compose V2 (`docker compose` ไม่ใช่ `docker-compose`)

```bash
docker compose version   # ต้องเป็น v2.x
```
