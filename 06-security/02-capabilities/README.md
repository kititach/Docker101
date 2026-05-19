# Lab 02 — Linux Capabilities

## Objective

ลด attack surface ด้วยการ drop capabilities ทั้งหมดที่ application ไม่ต้องใช้

---

## Capabilities คืออะไร

Linux แบ่งสิทธิ์ของ root ออกเป็น ~40 capabilities — แต่ละ capability ให้สิทธิ์เฉพาะอย่าง

```
CAP_CHOWN          → chown ไฟล์ของคนอื่นได้
CAP_NET_RAW        → สร้าง raw socket (ping ดิบ, tcpdump)
CAP_NET_BIND_SERVICE → bind port < 1024
CAP_SYS_ADMIN      → ทำได้แทบทุกอย่าง (อย่าให้!)
CAP_SYS_PTRACE     → debug process อื่น
CAP_SYS_TIME       → ปรับเวลาระบบ
CAP_KILL           → ส่ง signal ให้ process ของคนอื่น
```

---

## Step 1 — ดู Default Capabilities ของ Container

Docker ให้ capabilities ชุดมาตรฐาน ~14 ตัวกับทุก container:

```bash
docker run --rm alpine:3.20 sh -c '
apk add -q libcap-utils 2>/dev/null
capsh --print | grep "Current:"
'
# Current: cap_chown,cap_dac_override,cap_fowner,cap_fsetid,
#          cap_kill,cap_setgid,cap_setuid,cap_setpcap,
#          cap_net_bind_service,cap_net_raw,cap_sys_chroot,
#          cap_mknod,cap_audit_write,cap_setfcap=ep
```

> Container ได้แค่ subset ของ root จริง — แต่ก็ยังเยอะกว่าที่ app ปกติต้องการ

---

## Step 2 — Drop CHOWN: chown หยุดทำงาน

```bash
# default — chown ทำงานได้
docker run --rm alpine:3.20 sh -c 'touch /tmp/f && chown 999 /tmp/f && echo OK'
# OK

# drop CHOWN — chown fail
docker run --rm --cap-drop CHOWN alpine:3.20 sh -c 'touch /tmp/f && chown 999 /tmp/f'
# chown: /tmp/f: Operation not permitted
```

---

## Step 3 — Drop NET_RAW: raw socket หยุดทำงาน

`tcpdump`, `nmap -sS` (SYN scan), packet crafting ต้องใช้ raw socket

```bash
# default — raw socket OK
docker run --rm python:3.12-alpine python3 -c '
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_RAW, 1)
print("raw socket created")
'
# raw socket created

# drop NET_RAW — fail
docker run --rm --cap-drop NET_RAW python:3.12-alpine python3 -c '
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_RAW, 1)
' 2>&1 | tail -1
# PermissionError: [Errno 1] Operation not permitted
```

**Web app ไม่ต้องการ NET_RAW** — drop ทันที

---

## Step 4 — Best Practice: --cap-drop ALL แล้วเพิ่มเฉพาะที่ต้องการ

```bash
# drop ทุก capability — ใช้ได้กับ web app ที่ไม่ต้องการสิทธิ์พิเศษ
docker run --rm --cap-drop ALL alpine:3.20 sh -c '
apk add -q libcap-utils 2>/dev/null
capsh --print | grep "Current:"
'
# Current: =
# ← ไม่มี capability เลย!

# ถ้า app ต้องการ chown (เช่น init script) — เพิ่มกลับมาเฉพาะตัวเดียว
docker run --rm --cap-drop ALL --cap-add CHOWN alpine:3.20 sh -c '
capsh --print | grep Current
'
# Current: cap_chown=ep
```

---

## Step 5 — Capabilities สำหรับ Use Case ทั่วไป

| Application | Capabilities ที่ต้องการ |
|------------|------------------------|
| Web app (Flask, Express, etc.) | ไม่ต้องการเลย — `--cap-drop ALL` |
| Web server bind port 80/443 | บน Linux ปกติต้อง NET_BIND_SERVICE |
| Database (postgres, mysql) | CHOWN, SETGID, SETUID (สำหรับ init), FOWNER |
| Network tool (tcpdump, ping) | NET_RAW |
| System monitoring | SYS_PTRACE, NET_ADMIN |
| Privileged daemon | คิดให้ดีก่อน — มักไม่ควรรันใน container |

---

## Step 6 — NET_BIND_SERVICE และ Docker

> **หมายเหตุสำคัญ:** Docker ตั้ง `net.ipv4.ip_unprivileged_port_start=0` ใน container โดย default → process ใด ๆ bind port ใดก็ได้ ไม่ต้องการ NET_BIND_SERVICE

ตรวจสอบ:
```bash
docker run --rm python:3.12-alpine sysctl net.ipv4.ip_unprivileged_port_start
# net.ipv4.ip_unprivileged_port_start = 0   ← Docker default
```

ถ้าต้องการ behavior แบบ Linux ปกติ (port < 1024 ต้อง privileged):
```bash
docker run --sysctl net.ipv4.ip_unprivileged_port_start=1024 ...
```

---

## Step 7 — Inspect Capabilities ของ Container ที่รันอยู่

```bash
docker run -d --name capdemo --cap-drop ALL --cap-add NET_BIND_SERVICE alpine:3.20 sleep 60
docker inspect capdemo --format '{{json .HostConfig.CapDrop}} / {{json .HostConfig.CapAdd}}'
# ["ALL"] / ["NET_BIND_SERVICE"]

# ดู effective capabilities ของ process ใน container
docker exec capdemo cat /proc/1/status | grep -i cap
docker rm -f capdemo
```

---

## Step 8 — Compose Syntax

```yaml
services:
  web:
    image: myapp:1.0
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE   # ถ้าต้องการ
    security_opt:
      - no-new-privileges  # ป้องกัน setuid escalation (Lab 05)
```

---

## Cleanup

```bash
# ไม่มี container ค้างไว้
```

---

## Capability Checklist

```
□ ใช้ --cap-drop ALL เสมอเป็น default
□ เพิ่มเฉพาะ capability ที่ใช้จริง
□ Web app ส่วนใหญ่ไม่ต้องการ capability ใด ๆ
□ ถ้าไม่แน่ใจ → audit ดูว่า app เคย fail ด้วย "Operation not permitted" หรือไม่
□ ห้ามใช้ CAP_SYS_ADMIN (เกือบเทียบเท่า root)
□ ห้ามใช้ --privileged (เปิด capabilities ทั้งหมด + อื่น ๆ)
```
