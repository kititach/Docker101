# Lab 05 — Multi-Container Networking

## Objective

นำทุก concept มารวม: สร้าง stack สามชั้น nginx → backend → redis โดยใช้ network segmentation แบบ production

---

## Architecture

```
Internet
    │
    ▼ port 8080
┌─────────────────────────────────────────────────────┐
│ frontend-net                                        │
│   ┌──────────┐        ┌──────────────────────────┐  │
│   │  nginx   │──────▶ │        backend           │  │
│   └──────────┘        └──────────────────────────┘  │
└─────────────────────────────────────────────────────┘
                                    │
                        ┌───────────▼──────────────────┐
                        │ backend-net                  │
                        │   ┌───────┐                  │
                        │   │ redis │                  │
                        │   └───────┘                  │
                        └──────────────────────────────┘
```

**nginx** — รู้จัก backend (frontend-net) แต่ไม่รู้จัก redis  
**backend** — อยู่สอง network (frontend-net + backend-net) เป็น bridge ระหว่างสองชั้น  
**redis** — รู้จักแค่ backend ไม่ exposed ออก internet เลย

---

## Files

```
05-multi-container/
├── backend/
│   ├── app.py           — Flask: นับ hits ด้วย Redis
│   ├── requirements.txt
│   └── Dockerfile
├── nginx/
│   ├── nginx.conf       — proxy ทุก request ไป backend:8080
│   └── Dockerfile
└── README.md
```

---

## Step 1 — Build Images

```bash
cd 05-multi-container

docker build -t net-backend:1.0 backend/
docker build -t net-nginx:1.0   nginx/
```

---

## Step 2 — สร้าง Networks

```bash
docker network create frontend-net
docker network create backend-net

docker network ls | grep -E "frontend|backend"
```

---

## Step 3 — รัน Services

**Redis** — บน backend-net เท่านั้น (ไม่ expose port ออก host):
```bash
docker run -d \
  --name redis \
  --network backend-net \
  redis:7-alpine
```

**Backend** — เชื่อมสอง network:
```bash
docker run -d \
  --name backend \
  --network backend-net \
  -e REDIS_HOST=redis \
  net-backend:1.0

# เชื่อม backend เข้า frontend-net ด้วย
docker network connect frontend-net backend
```

**Nginx** — บน frontend-net, expose port ออก host:
```bash
docker run -d \
  --name nginx \
  --network frontend-net \
  -p 8080:80 \
  net-nginx:1.0
```

---

## Step 4 — ทดสอบ Stack

```bash
# ทดสอบ full path: client → nginx → backend → redis
curl http://localhost:8080/
# {"hits":1,"hostname":"...","service":"backend"}

curl http://localhost:8080/
# {"hits":2,...}

curl http://localhost:8080/
# {"hits":3,...}
```

hits เพิ่มทุก request — backend อ่านค่าจาก Redis ได้

---

## Step 5 — ยืนยัน Network Isolation

```bash
# nginx เห็น backend ได้ (frontend-net เดียวกัน)
docker exec nginx wget -qO- http://backend:8080/ 2>/dev/null
# ได้ผล

# nginx ไม่เห็น redis (คนละ network)
docker exec nginx wget -qO- http://redis:6379 --timeout=2 2>&1
# wget: bad address 'redis'  ← isolated!

# backend เห็น redis ได้ (backend-net เดียวกัน)
docker exec backend wget -qO- http://localhost:8080/health
# OK

# redis ไม่มี port expose ออก host
curl http://localhost:6379 2>&1
# Connection refused  ← ไม่ accessible จากภายนอก
```

---

## Step 6 — ดู Network Membership

```bash
# ดู networks ที่ backend อยู่ (ควรเห็น 2 networks)
docker inspect backend \
  --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}'
# backend-net
# frontend-net

# ดู containers ทั้งหมดบน frontend-net
docker network inspect frontend-net \
  --format '{{range .Containers}}{{.Name}}{{"\n"}}{{end}}'
# nginx
# backend

# ดู containers ทั้งหมดบน backend-net
docker network inspect backend-net \
  --format '{{range .Containers}}{{.Name}}{{"\n"}}{{end}}'
# redis
# backend
```

---

## Step 7 — ดู Logs ของแต่ละ Service

```bash
docker logs nginx    # access logs จาก nginx
docker logs backend  # application logs จาก Flask
docker logs redis    # redis server logs
```

ติดตาม logs แบบ real-time ขณะส่ง request:
```bash
docker logs -f backend &
curl http://localhost:8080/
curl http://localhost:8080/
```

---

## Step 8 — Cleanup

```bash
docker rm -f nginx backend redis
docker network rm frontend-net backend-net
docker rmi net-backend:1.0 net-nginx:1.0
```

---

## สรุป Pattern นี้

```
pattern: network segmentation
─────────────────────────────
frontend-net:  nginx ←→ backend       (user-facing)
backend-net:   backend ←→ redis/db    (data layer)

ผลลัพธ์:
- nginx เข้าถึง redis ไม่ได้โดยตรง
- redis ไม่มี port expose ออก internet
- backend เป็น bridge เดียวระหว่างสองชั้น
- ถ้า nginx ถูก compromise → attacker เข้าถึงแค่ backend
```

นี่คือ **defense in depth** ระดับ network ในแบบ Docker บน single host
