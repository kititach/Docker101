# Lab 01 — Non-Root User

## Objective

ลด blast radius ของการถูก exploit — ทำให้ application ใน container ไม่มี root privilege

---

## Files

```
01-non-root/
├── app.sh             — script ทดสอบ permissions
├── bad.Dockerfile     — รันเป็น root (default)
├── good.Dockerfile    — สร้าง appuser และใช้ USER instruction
├── numeric.Dockerfile — ใช้ numeric UID (สำหรับ scratch/distroless)
└── README.md
```

---

## ทำไมไม่ควรรันเป็น Root

container "root" คือ root จริง ๆ บน Linux namespace ของ container แม้จะ isolate จาก host แต่ ถ้า:
- มี container escape vulnerability → ได้ root บน host
- มี privileged mount หรือ docker socket → ได้ root บน host ได้ง่าย ๆ
- ถ้า exploit เขียนถึง shared volume → กระทบ host ได้
- ถ้า container รัน setuid binary หรือ install package → persist หลัง restart

หลักการ **principle of least privilege**: app ที่ทำหน้าที่ serve HTTP ไม่จำเป็นต้องเป็น root

---

## Step 1 — Build ทั้งสาม Pattern

```bash
docker build -f bad.Dockerfile -t sec01:bad .
docker build -f good.Dockerfile -t sec01:good .
docker build -f numeric.Dockerfile -t sec01:numeric .
```

---

## Step 2 — รันเปรียบเทียบ

```bash
docker run --rm sec01:bad
docker run --rm sec01:good
docker run --rm sec01:numeric
```

ผลลัพธ์จริง:

**Bad (root):**
```
uid=0(root) gid=0(root) groups=0(root),...

Write to /etc/passwd:  YES (danger!)
Write to /etc/shadow:  YES (danger!)
apk add curl:          YES (root)
```

**Good (appuser):**
```
uid=100(appuser) gid=101(appgroup)

Write to /etc/passwd:  Permission denied  → no (safe)
Write to /etc/shadow:  Permission denied  → no (safe)
apk add curl:          no (unprivileged)
```

**Numeric (uid 10001):**
```
uid=10001 gid=10001 groups=10001    ← ไม่มีชื่อใน /etc/passwd
```

---

## Step 3 — Pattern เปรียบเทียบ

**Alpine** (busybox adduser):
```dockerfile
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
```
- `-S` = system user: no password, no shell login, ไม่กิน UID range ปกติ

**Debian/Ubuntu slim:**
```dockerfile
RUN groupadd -r app && useradd -r -g app app
USER app
```
- `-r` = system account: similar concept

**Scratch / Distroless** (ไม่มี /etc/passwd):
```dockerfile
USER 10001:10001
```
- ใช้ numeric UID เท่านั้น
- เลือก UID > 10000 เพื่อหลีกเลี่ยงการชนกับ system users

---

## Step 4 — COPY --chown

ไฟล์ที่ COPY จะเป็นของ root โดย default — ถ้า USER non-root จะอ่าน/เขียนไม่ได้

```dockerfile
# COPY แล้ว chown ทีหลัง → สร้าง 2 layers
COPY app.py /app/
RUN chown -R appuser:appgroup /app

# GOOD: รวมเป็น layer เดียวด้วย --chown
COPY --chown=appuser:appgroup app.py /app/
```

---

## Step 5 — Kubernetes runAsNonRoot

ใน Kubernetes/PodSecurity admission ตรวจ `runAsNonRoot: true` ด้วย UID ตัวเลข:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
```

ถ้า Dockerfile ใช้ `USER appuser` (ชื่อ) — K8s อ่าน /etc/passwd ตอน admission ไม่ได้ → ต้องใช้ `USER 10001:10001` (ตัวเลข) เสมอเพื่อ portability

---

## Step 6 — ตรวจสอบ Image อื่นว่ารันเป็น Root หรือไม่

```bash
docker inspect nginx:1.27-alpine --format '{{.Config.User}}'
# (ว่าง) ← รันเป็น root โดย default

docker inspect node:20-alpine --format '{{.Config.User}}'
# (ว่าง) ← รันเป็น root แต่มี user "node" (uid 1000) ใน image แล้ว

# ดูด้วย dive หรือ run ดู
docker run --rm node:20-alpine id node
# uid=1000(node) gid=1000(node)
```

ถ้า base image ไม่ตั้ง USER ให้ — ต้องตั้งเองเสมอใน Dockerfile

---

## Cleanup

```bash
docker rmi sec01:bad sec01:good sec01:numeric
```

---

## Checklist Non-Root User

```
□ Dockerfile มี USER instruction
□ USER ใช้ numeric UID/GID (ดีต่อ K8s portability)
□ UID > 10000 เพื่อหลีกเลี่ยง system users
□ ใช้ COPY --chown แทน COPY + RUN chown
□ ตรวจสอบ base image ว่ารัน root หรือไม่
□ Process หลักไม่ต้องการ root capability ใด ๆ (Lab 02)
```
