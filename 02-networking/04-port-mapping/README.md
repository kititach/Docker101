# Lab 04 — Port Mapping

## Objective

เข้าใจการ publish port ทุกรูปแบบ — `-p` flag, interface binding, random port และ EXPOSE

---

## พื้นฐาน: Port Mapping ทำงานอย่างไร

Docker ใช้ **iptables DNAT** เพื่อ redirect traffic จาก host port ไป container port

```
Client → Host:8080 → iptables DNAT → Container:80
```

---

## Step 1 — รูปแบบพื้นฐาน

```bash
# host_port:container_port
docker run -d --name web1 -p 8080:80 nginx:1.27-alpine

curl http://localhost:8080
docker port web1          # แสดง mapping ทั้งหมด
```

---

## Step 2 — รูปแบบต่าง ๆ ของ -p

```bash
# 1. ระบุทั้ง host port และ container port
docker run -d --name p1 -p 8081:80 nginx:1.27-alpine

# 2. Random host port (Docker เลือกให้)
docker run -d --name p2 -p 80 nginx:1.27-alpine
docker port p2            # ดูว่า Docker เลือก port อะไร
PORT=$(docker inspect p2 --format '{{(index .NetworkSettings.Ports "80/tcp" 0).HostPort}}')
curl http://localhost:$PORT

# 3. หลาย port พร้อมกัน
docker run -d --name p3 -p 8082:80 -p 8443:443 nginx:1.27-alpine

# 4. UDP port
docker run -d --name p4 -p 5353:53/udp alpine:3.20 sleep 300
docker port p4
```

---

## Step 3 — Bind เฉพาะ Network Interface

โดย default Docker bind กับ `0.0.0.0` — ทุก interface (ทุก IP บน host)  
ถ้าต้องการ restrict ให้ accessible เฉพาะบาง interface:

```bash
# bind เฉพาะ localhost — ไม่ expose ออก network ภายนอก
docker run -d --name local-only -p 127.0.0.1:8083:80 nginx:1.27-alpine

# ทดสอบ
curl http://127.0.0.1:8083   # ได้
curl http://0.0.0.0:8083     # ได้ (0.0.0.0 หมายถึง localhost ด้วย)

# เปรียบเทียบ: default bind (0.0.0.0) ต่างกันอย่างไร
docker inspect local-only --format '{{json .NetworkSettings.Ports}}'
# {"80/tcp":[{"HostIp":"127.0.0.1","HostPort":"8083"}]}  ← bind เฉพาะ 127.0.0.1
```

**เมื่อไหรควรใช้ 127.0.0.1:**
- database ที่ไม่ควรเข้าถึงจากภายนอก
- service ที่มี reverse proxy (nginx) อยู่หน้า

ตั้ง default bind address ใน daemon config:
```json
// /etc/docker/daemon.json
{
  "ip": "127.0.0.1"
}
```

---

## Step 4 — ดู Port Mapping ทั้งหมด

```bash
# ดู ports ของ container เดียว
docker port p1

# ดู ports ของทุก container
docker ps --format "table {{.Names}}\t{{.Ports}}"

# ดูด้วย inspect
docker inspect p1 --format '{{json .NetworkSettings.Ports}}' | python3 -m json.tool
```

---

## Step 5 — EXPOSE vs -p

ความเข้าใจผิดที่พบบ่อย:

```dockerfile
EXPOSE 8080   # ← เอกสารเท่านั้น ไม่ได้ publish จริง!
```

```bash
# build image ที่มี EXPOSE 8080
docker run -d --name exposed nginx:1.27-alpine  # ไม่มี -p

curl http://localhost:80  # ไม่ได้ — ไม่มี port mapping

# ต้องระบุ -p เสมอ
docker run -d --name published -p 8084:80 nginx:1.27-alpine
curl http://localhost:8084  # ได้
```

`EXPOSE` มีประโยชน์กับ:
- `docker run -P` (capital P) — publish ทุก EXPOSE port พร้อมกัน ด้วย random host port
- Docker Compose / Kubernetes อ่าน EXPOSE เพื่อรู้ว่า service ฟัง port อะไร

```bash
# -P (capital P): publish ทุก EXPOSE port อัตโนมัติ
docker run -d --name auto-published -P nginx:1.27-alpine
docker port auto-published
# 80/tcp → 0.0.0.0:32769  ← random port
# 443/tcp → 0.0.0.0:32768
```

---

## Step 6 — iptables Rules ที่ Docker สร้าง

```bash
# ดู DNAT rules
sudo iptables -t nat -L DOCKER -n --line-numbers

# ดู forward rules
sudo iptables -L DOCKER-USER -n
```

---

## Step 7 — Cleanup

```bash
docker rm -f web1 p1 p2 p3 p4 local-only exposed published auto-published
```

---

## สรุป -p Flag

| รูปแบบ | ความหมาย |
|--------|---------|
| `-p 8080:80` | host:8080 → container:80, bind 0.0.0.0 |
| `-p 80` | random host port → container:80 |
| `-p 127.0.0.1:8080:80` | host:8080 บน localhost เท่านั้น |
| `-p 8080:80/udp` | UDP port |
| `-P` | publish ทุก EXPOSE port ด้วย random host port |
| ไม่มี -p | ไม่ accessible จาก host |
