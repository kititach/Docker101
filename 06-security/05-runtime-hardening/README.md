# Lab 05 — Runtime Hardening

## Objective

รวมทุก security technique จาก Lab 01-04 เข้าใน compose.yaml เดียว — production-grade hardening

---

## Files

```
05-runtime-hardening/
├── app.py            — Flask app เรียบง่ายเพื่อทดสอบ
├── Dockerfile        — non-root, numeric UID, HEALTHCHECK
├── compose.yaml      — รวมทุก security flag
└── README.md
```

---

## ผลวัดจริงหลัง Apply Hardening

```
Container inspect:
  User                  10001:10001
  Capabilities (effective) 0000000000000000  ← ไม่มี cap เลย
  ReadonlyRootfs        true
  SecurityOpt           ["no-new-privileges:true"]
  PidsLimit             100

Behavior:
  ✓ HTTP request → OK
  ✗ Write /etc/passwd → Permission denied
  ✓ Write /tmp → OK (tmpfs)
```

---

## Step 1 — ดู compose.yaml — Layered Defense

```yaml
services:
  web:
    build: .
    user: "10001:10001"            # 1. non-root (Lab 01)
    cap_drop: [ALL]                # 2. ไม่มี capability (Lab 02)
    read_only: true                # 3. read-only rootfs (Lab 03)
    tmpfs:
      - /tmp:size=10m              #    writable เฉพาะ tmpfs
      - /run:size=1m
    security_opt:
      - no-new-privileges:true     # 4. block setuid escalation
    pids_limit: 100                # 5. ป้องกัน fork bomb
    mem_limit: 256m                #    DoS protection
    cpus: 0.5
    ulimits:
      nofile: { soft: 1024, hard: 2048 }
      nproc: 100
    logging:
      driver: json-file            # 6. log rotation
      options:
        max-size: "10m"
        max-file: "3"
```

---

## Step 2 — Build และรัน

```bash
docker compose up -d --build

# ทดสอบ
curl http://localhost:9095/
# {"host":"...","service":"hardened-app","uid":10001}
```

---

## Step 3 — Verify Hardening

```bash
# 1. UID
docker compose exec web id
# uid=10001(app) gid=10001 groups=10001

# 2. Capabilities = 0
docker compose exec web cat /proc/1/status | grep ^Cap
# CapInh: 0000000000000000
# CapPrm: 0000000000000000
# CapEff: 0000000000000000   ← ไม่มี capability เลย!
# CapBnd: 0000000000000000
# CapAmb: 0000000000000000

# 3. Read-only rootfs
docker compose exec web sh -c 'echo x >> /etc/passwd' 2>&1
# Permission denied

# 4. tmpfs paths writable
docker compose exec web sh -c 'echo ok > /tmp/test && cat /tmp/test'
# ok

# 5. ดู host config
docker inspect 05-runtime-hardening-web-1 \
  --format 'User={{.Config.User}}, RO={{.HostConfig.ReadonlyRootfs}}, Caps={{.HostConfig.CapDrop}}, SecOpt={{.HostConfig.SecurityOpt}}, Pids={{.HostConfig.PidsLimit}}'
# User=10001:10001, RO=true, Caps=[ALL], SecOpt=[no-new-privileges:true], Pids=100
```

---

## Step 4 — แต่ละ Flag แก้ปัญหาอะไร

| Flag | ป้องกันอะไร |
|------|-----------|
| `user: 10001:10001` | container escape ได้แค่ user สิทธิ์ต่ำ ไม่ใช่ root |
| `cap_drop: [ALL]` | block sensitive syscalls (CHOWN, NET_RAW, etc.) |
| `read_only: true` | malware เขียนไฟล์ลง image ไม่ได้ → ไม่ persist |
| `tmpfs` | ให้ที่เขียนเฉพาะที่จำเป็น (in-memory, หายเมื่อ restart) |
| `no-new-privileges` | ป้องกัน setuid binary ใช้ escalate privilege |
| `pids_limit` | ป้องกัน fork bomb (`:(){:|:&};:`) |
| `mem_limit` | OOM killer ฆ่า process แทน crash ทั้ง host |
| `ulimits` | จำกัด file descriptors, processes ที่ user เปิดได้ |
| `logging max-size` | ป้องกัน log ใหญ่จน disk เต็ม |

---

## Step 5 — Seccomp Profile (Advanced)

Docker default seccomp profile block ~44 syscalls อันตรายอยู่แล้ว ดู:
```bash
docker run --rm alpine:3.20 sh -c 'cat /proc/self/status | grep Seccomp'
# Seccomp: 2  (filter mode)
```

Custom seccomp profile (เข้มกว่า default):
```bash
# download default profile แล้วแก้
curl -O https://raw.githubusercontent.com/moby/moby/master/profiles/seccomp/default.json
# แก้ syscalls ที่อนุญาต → save เป็น custom.json

docker run --security-opt seccomp=custom.json myapp
```

ใน compose:
```yaml
security_opt:
  - seccomp:./custom-seccomp.json
```

---

## Step 6 — เปรียบเทียบกับ Container แบบไม่ Hardened

```bash
# default container — root + ทุก capability + writable
docker run --rm alpine:3.20 sh -c '
  echo "uid=$(id -u)"
  cat /proc/1/status | grep CapEff
  echo "write /etc/passwd:"
  echo x >> /etc/passwd 2>&1 || echo "denied"
'
# uid=0
# CapEff: 00000000a80425fb   ← มี capabilities เพียบ
# write /etc/passwd:  → succeeds
```

---

## Cleanup

```bash
docker compose down
docker rmi hardened-app:1.0
```

---

## Production Security Checklist (ครบทั้ง Module)

```
Image build:
  □ multi-stage build
  □ non-root USER (numeric UID > 10000)
  □ base image รุ่นใหม่ + alpine/slim
  □ ไม่มี secrets ใน ENV/ARG
  □ HEALTHCHECK
  □ CVE scan ผ่าน

Container runtime:
  □ user: NNNN:NNNN
  □ cap_drop: [ALL] + cap_add เฉพาะที่ต้องการ
  □ read_only: true + tmpfs
  □ security_opt: [no-new-privileges:true]
  □ pids_limit, mem_limit, cpus
  □ ulimits
  □ logging max-size/max-file
  □ restart: unless-stopped (ไม่ใช่ always — ระวัง crash loop)

Network:
  □ network segmentation (Module 02)
  □ ไม่ expose port ที่ไม่จำเป็น
  □ ใช้ secrets (Module 04 Lab 04)

Operations:
  □ regular base image rebuild
  □ regular CVE scan
  □ audit logs
  □ pin image digests ใน production
```
