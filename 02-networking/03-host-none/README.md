# Lab 03 — Host & None Networks

## Objective

เข้าใจ `host` และ `none` network driver — สองขั้วสุดของ networking: ไม่มี isolation เลย vs isolated สมบูรณ์

---

## Host Network

### ทำงานอย่างไร

`--network host` ทำให้ container **ใช้ network stack ของ host โดยตรง** — ไม่มี virtual interface, ไม่มี NAT, ไม่ต้อง port mapping

```
ปกติ (bridge):
  Host:8080 → iptables NAT → Container:8080

Host network:
  Container ฟัง port 8080 = Host ฟัง port 8080 โดยตรง
```

> **Linux only** — ไม่ทำงานบน Docker Desktop (macOS/Windows) เพราะ Docker Desktop รัน Linux VM คั้นอยู่

### Step 1 — เปรียบเทียบ Bridge vs Host

รัน nginx แบบ bridge (ต้อง -p):
```bash
docker run -d --name nginx-bridge -p 8080:80 nginx:1.27-alpine
curl http://localhost:8080   # ได้ผ่าน port mapping
```

รัน nginx แบบ host (ไม่ต้อง -p):
```bash
docker run -d --name nginx-host --network host nginx:1.27-alpine
curl http://localhost:80     # ได้เลย — nginx ฟัง port 80 บน host โดยตรง
```

ดู port ที่ container ใช้:
```bash
docker port nginx-bridge     # แสดง mapping
docker port nginx-host       # ไม่แสดงอะไร — ไม่มี port mapping

# ดู process ที่ฟัง port บน host
ss -tlnp | grep :80
```

### Step 2 — ดู network interface ใน container

```bash
# bridge container — เห็นแค่ eth0 (virtual interface ของตัวเอง)
docker exec nginx-bridge ip addr

# host container — เห็น interface เดียวกับ host ทั้งหมด
docker exec nginx-host ip addr
# lo, eth0, docker0 ... เหมือนกับบน host เลย
```

### Step 3 — Use Cases จริง

```bash
# ดู hostname ของ host container (เห็น hostname ของ host จริง)
docker exec nginx-host hostname
hostname  # เทียบกับ host
```

**เมื่อไหรควรใช้ host network:**
- Performance-critical workload ที่ต้องการ raw network throughput (ลด overhead ของ NAT)
- เครื่องมือ network monitoring ที่ต้องเห็น traffic จริงบน host
- ทดสอบ network behavior บน host โดยตรง

**ข้อเสีย:**
- ไม่มี network isolation — container เห็น network ทั้งหมดของ host
- port collision — ถ้า port ซ้ำกับ service บน host จะ error
- ใช้ได้แค่ Linux

### Cleanup
```bash
docker rm -f nginx-bridge nginx-host
```

---

## None Network

### ทำงานอย่างไร

`--network none` ทำให้ container **ไม่มี network interface เลย** ยกเว้น loopback (`lo`)  
ไม่สามารถออก internet, ไม่สามารถรับ connection จากภายนอก, คุยกับ container อื่นไม่ได้

### Step 4 — รัน Container แบบ None

```bash
docker run -it --network none alpine:3.20 sh
```

ใน container:
```sh
# ดู interfaces
ip addr
# lo: 127.0.0.1  ← มีแค่ loopback

# ลองออก internet
ping -c 2 8.8.8.8
# Network unreachable

# ลอง ping localhost (ทำได้)
ping -c 2 127.0.0.1
# PING 127.0.0.1: 64 bytes from 127.0.0.1 ← ได้

exit
```

### Step 5 — Use Cases จริง

```bash
# รัน batch job ที่ไม่ต้องการ network เลย
docker run --rm --network none \
  -v $(pwd):/data \
  python:3.12-alpine \
  python -c "
import json, os
data = {'processed': True, 'files': os.listdir('/data')}
print(json.dumps(data, indent=2))
"
```

**เมื่อไหรควรใช้ none network:**
- Batch processing / data transformation ที่ไม่ต้องการ network
- Security-sensitive workload ที่ต้องการ air-gap สมบูรณ์
- Unit test ที่ต้องการ isolate network dependency

---

## สรุปเปรียบเทียบ Network Drivers

| Driver | Isolation | DNS | Internet | Port Mapping | Use Case |
|--------|-----------|-----|----------|--------------|----------|
| `bridge` (default) | partial | ❌ | ✅ | ต้องระบุ -p | dev/test |
| custom bridge | ✅ | ✅ | ✅ | ต้องระบุ -p | production |
| `host` | ❌ | — | ✅ | ไม่ต้อง | high-perf networking |
| `none` | ✅ (สมบูรณ์) | ❌ | ❌ | ❌ | isolated batch job |
| `overlay` | ✅ | ✅ | ✅ | ต้องระบุ | Swarm / multi-host |
