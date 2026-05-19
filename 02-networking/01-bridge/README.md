# Lab 01 — Default Bridge Network

## Objective

เข้าใจว่า default bridge network ทำงานอย่างไร และทำไมถึงไม่แนะนำให้ใช้ใน production

---

## ทำไมต้องรู้ Bridge Network?

เมื่อรัน `docker run` โดยไม่ระบุ `--network` — container จะเข้า default bridge network อัตโนมัติ  
เข้าใจ default bridge ช่วยให้รู้ว่า custom network ช่วยแก้ปัญหาอะไร (Lab 02)

---

## Step 1 — ดู Default Bridge Network

```bash
# แสดง networks ทั้งหมด
docker network ls

# ดู detail ของ default bridge
docker network inspect bridge
```

สังเกต:
- `"Subnet": "172.17.0.0/16"` — IP range ที่ containers จะได้รับ
- `"Gateway": "172.17.0.1"` — gateway ออก internet คือ host
- `"com.docker.network.bridge.name": "docker0"` — network interface บน host

ดู interface บน host:
```bash
ip addr show docker0
# docker0: ... inet 172.17.0.1/16 ...
```

---

## Step 2 — รัน Containers บน Default Bridge

รัน container สองตัวโดยไม่ระบุ network (ไปอยู่ default bridge อัตโนมัติ):

```bash
docker run -d --name c1 alpine:3.20 sleep 600
docker run -d --name c2 alpine:3.20 sleep 600
```

ดู IP ของแต่ละ container:

```bash
docker inspect c1 --format '{{.NetworkSettings.IPAddress}}'
docker inspect c2 --format '{{.NetworkSettings.IPAddress}}'
# ได้ 172.17.0.2 และ 172.17.0.3 (หรือใกล้เคียง)
```

---

## Step 3 — คุยกันด้วย IP (ได้)

```bash
# เอา IP ของ c2 มาก่อน
C2_IP=$(docker inspect c2 --format '{{.NetworkSettings.IPAddress}}')
echo "c2 IP: $C2_IP"

# ping จาก c1 ไป c2 ด้วย IP
docker exec c1 ping -c 3 $C2_IP
```

การสื่อสารผ่าน IP **ทำได้** บน default bridge — containers อยู่ใน subnet เดียวกัน

---

## Step 4 — คุยกันด้วยชื่อ (ไม่ได้ บน default bridge)

```bash
# พยายาม ping ด้วยชื่อ container
docker exec c1 ping -c 2 c2
# ping: bad address 'c2'  ← DNS ไม่ทำงานบน default bridge!
```

**นี่คือข้อจำกัดสำคัญของ default bridge:**  
ไม่มี automatic DNS — ต้องรู้ IP ก่อน แต่ IP เปลี่ยนทุกครั้งที่ container restart

---

## Step 5 — Legacy --link (อย่าใช้)

`--link` คือ workaround เก่าที่เพิ่ม DNS บน default bridge:

```bash
docker rm -f c1 c2
docker run -d --name c2 alpine:3.20 sleep 600
docker run -d --name c1 --link c2:c2 alpine:3.20 sleep 600

docker exec c1 ping -c 2 c2   # ← ได้ด้วย --link
docker exec c1 cat /etc/hosts  # เห็น c2 ถูกเพิ่มแบบ hard-code
```

ปัญหาของ `--link`:
- เป็น **one-way** — c1 เห็น c2 แต่ c2 ไม่เห็น c1
- ไม่ support container restart (IP อาจเปลี่ยน แต่ /etc/hosts ไม่อัปเดต)
- deprecated — Docker อาจถอดออกในอนาคต

> **สรุป:** ใช้ custom network แทนเสมอ (Lab 02) — ได้ DNS ฟรีและทำงานสองทิศทาง

---

## Step 6 — ดู Network บน Host

```bash
# ดู bridge interfaces บน host
bridge link show

# ดู iptables rules ที่ Docker สร้าง
sudo iptables -t nat -L DOCKER --line-numbers
```

Docker ใช้ Linux bridge + iptables NAT เพื่อให้ container ออก internet ได้

---

## Step 7 — Cleanup

```bash
docker rm -f c1 c2
```

---

## สรุป

| Feature | Default Bridge | Custom Network (Lab 02) |
|---------|---------------|------------------------|
| DNS by container name | ❌ | ✅ |
| Network isolation | ❌ (ทุก container รวมกัน) | ✅ (แยกตาม network) |
| Automatic IP management | ✅ | ✅ |
| Recommended | ❌ dev/test only | ✅ production |
