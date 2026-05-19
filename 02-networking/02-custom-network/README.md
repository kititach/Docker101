# Lab 02 — Custom Network + DNS

## Objective

สร้าง custom bridge network ที่มี built-in DNS — containers คุยกันด้วยชื่อได้ทันที และ isolate ได้ตามต้องการ

---

## Files

```
02-custom-network/
├── app/
│   ├── server.py    — HTTP server แสดง hostname/IP และ resolve target ได้
│   └── Dockerfile
└── README.md
```

---

## Step 1 — สร้าง Custom Network

```bash
docker network create mynet

# ดู detail
docker network inspect mynet
```

สังเกต:
- `"Driver": "bridge"` — custom network ก็เป็น bridge เช่นกัน แต่ได้ built-in DNS
- `"Subnet"` — Docker เลือก subnet ให้อัตโนมัติ (172.18.x.x หรือ 172.19.x.x)
- `"com.docker.network.bridge.enable_icc": "true"` — inter-container communication เปิด

---

## Step 2 — Build และรัน Containers บน Custom Network

```bash
cd app
docker build -t net-app:1.0 .
```

รัน 2 containers บน custom network เดียวกัน:

```bash
docker run -d --name svc-a --network mynet \
  -e SERVICE_NAME=svc-a net-app:1.0

docker run -d --name svc-b --network mynet \
  -e SERVICE_NAME=svc-b net-app:1.0
```

---

## Step 3 — DNS Resolution ด้วยชื่อ Container

```bash
# resolve ชื่อ svc-b จาก svc-a
docker exec svc-a nslookup svc-b
# Server: 127.0.0.11   ← Docker's built-in DNS
# Address: ...
# Name: svc-b
# Address: 172.18.0.x

# ping ด้วยชื่อ (ไม่ต้องรู้ IP)
docker exec svc-a ping -c 3 svc-b
```

`127.0.0.11` คือ DNS resolver ที่ Docker inject เข้าทุก container บน custom network

---

## Step 4 — HTTP Request ระหว่าง Containers

```bash
# svc-a fetch svc-b ด้วยชื่อ (พร้อม resolve IP ให้เห็น)
docker exec svc-a wget -qO- "http://svc-b:8080/?target=svc-a"
```

ดู response:
```json
{
  "service": "svc-b",
  "hostname": "...",
  "ip": "172.18.0.3",
  "target": "svc-a",
  "target_ip": "172.18.0.2",
  "target_response": { "service": "svc-a", ... }
}
```

ลองจาก browser หรือ curl บน host:
```bash
# expose port svc-a ก่อน (ต้อง recreate)
docker rm -f svc-a
docker run -d --name svc-a --network mynet \
  -e SERVICE_NAME=svc-a -p 8081:8080 net-app:1.0

curl "http://localhost:8081/?target=svc-b"
```

---

## Step 5 — Network Isolation

Container ต่าง network คุยกันไม่ได้ (ถ้าไม่ได้เชื่อมถึงกัน):

```bash
# สร้าง network อื่น
docker network create othernet

# รัน container บน othernet
docker run -d --name svc-c --network othernet \
  -e SERVICE_NAME=svc-c net-app:1.0

# svc-a พยายาม reach svc-c (ต่าง network)
docker exec svc-a ping -c 2 svc-c
# ping: bad address 'svc-c'  ← isolated!

docker exec svc-a wget -qO- http://svc-c:8080 --timeout=2 2>&1
# wget: bad address 'svc-c'  ← ไม่เห็นกัน
```

---

## Step 6 — เชื่อม Container เข้าหลาย Networks

Container หนึ่งตัวสามารถอยู่ได้หลาย network:

```bash
# เชื่อม svc-c เข้า mynet ด้วย
docker network connect mynet svc-c

# ตอนนี้ svc-a เห็น svc-c ได้
docker exec svc-a ping -c 2 svc-c
# PING svc-c: 64 bytes from ...

# ดู networks ที่ svc-c อยู่
docker inspect svc-c --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool
```

ถอดออกจาก network:
```bash
docker network disconnect mynet svc-c
```

---

## Step 7 — Network Scope และ DNS Alias

กำหนด DNS alias (ชื่อเพิ่มเติม) ให้ container:

```bash
docker run -d --name svc-d --network mynet \
  --network-alias api \
  --network-alias service-d \
  -e SERVICE_NAME=svc-d net-app:1.0

# เรียกได้ทั้งสามชื่อ
docker exec svc-a ping -c 1 svc-d
docker exec svc-a ping -c 1 api
docker exec svc-a ping -c 1 service-d
```

ประโยชน์: ใช้ alias ที่สื่อความหมายแทนชื่อ container

---

## Step 8 — Internal Network (ไม่มี internet access)

```bash
docker network create --internal private-net

docker run -d --name isolated --network private-net alpine:3.20 sleep 600

# ลองออก internet
docker exec isolated ping -c 2 8.8.8.8
# Network unreachable  ← ถูกตัด internet

# แต่คุยกับ container อื่นใน network เดียวกันได้
```

ใช้สำหรับ: database network ที่ไม่ควรมี internet access

---

## Step 9 — Cleanup

```bash
docker rm -f svc-a svc-b svc-c svc-d isolated
docker network rm mynet othernet private-net
```

---

## สรุป

| Feature | ทำอย่างไร |
|---------|----------|
| DNS by name | อัตโนมัติบน custom network |
| DNS server | `127.0.0.11` (inject ทุก container) |
| Network isolation | containers ต่าง network ไม่เห็นกัน |
| หลาย networks | `docker network connect` |
| DNS alias | `--network-alias` |
| ตัด internet | `--internal` flag |
| Legacy --link | อย่าใช้ — ใช้ custom network แทน |
