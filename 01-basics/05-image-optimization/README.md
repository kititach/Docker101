# Lab 05 — Image Optimization

## Objective

ลดขนาด Docker image อย่างเป็นระบบ ตั้งแต่ 1.63 GB จนเหลือ 86 MB โดยใช้ 4 เทคนิคหลัก

---

## ทำไม Image Size สำคัญ?

- **Pull/push time** — image 1 GB ใช้เวลา ~1 นาทีบน 100 Mbps, image 100 MB ใช้ ~10 วินาที
- **Attack surface** — image ใหญ่มี packages และ binaries มากกว่า → โอกาสมี CVE สูงกว่า
- **Storage cost** — registry เก็บหลาย version หลาย environment
- **Cold start** — Kubernetes pulling image ใหม่บน node ต้องรอ pull ก่อน run

---

## Files

```
05-image-optimization/
├── app/
│   ├── app.py            — Flask app เดียวกันทุก version
│   └── requirements.txt  — flask + requests
├── Dockerfile.v1         — anti-pattern baseline
├── Dockerfile.v2         — slim base + cleanup
├── Dockerfile.v3         — alpine base + non-root
├── Dockerfile.v4         — multi-stage build
└── README.md
```

---

## ผลสรุป (วัดจริงบนเครื่องนี้)

| Version | ขนาด | ลดจาก v1 | เทคนิคหลัก |
|---------|------|----------|------------|
| v1 — full, no cleanup | **1.63 GB** | — | anti-pattern baseline |
| v2 — slim base | **202 MB** | -87.6% | เปลี่ยน base image |
| v3 — alpine base | **99.2 MB** | -93.9% | Alpine + --no-cache-dir |
| v4 — multi-stage | **86.1 MB** | -94.7% | แยก build/runtime layer |

> ขนาดที่แสดงคือ "Disk Usage" รวม shared layers — เมื่อ push/pull registry จะส่งเฉพาะ layers ที่ไม่มีอยู่แล้ว

---

## Step 1 — Build และวัดขนาดทั้งหมด

```bash
cd 05-image-optimization

docker build --no-cache -f Dockerfile.v1 -t lab05:v1 .
docker build --no-cache -f Dockerfile.v2 -t lab05:v2 .
docker build --no-cache -f Dockerfile.v3 -t lab05:v3 .
docker build --no-cache -f Dockerfile.v4 -t lab05:v4 .

docker images lab05
```

ดู disk usage รายละเอียด:
```bash
docker system df -v | grep lab05
```

ดู layers ของแต่ละ image:
```bash
docker history lab05:v1 --format "{{.Size}}\t{{.CreatedBy}}"
docker history lab05:v3 --format "{{.Size}}\t{{.CreatedBy}}"
docker history lab05:v4 --format "{{.Size}}\t{{.CreatedBy}}"
```

---

## Step 2 — เทคนิคที่ 1: เลือก Base Image ให้เหมาะสม

ความแตกต่างระหว่าง v1 (1.63 GB) กับ v2 (202 MB) เกือบทั้งหมดมาจากการเปลี่ยน base image เพียงบรรทัดเดียว:

```dockerfile
# v1: full Debian — มี gcc, make, perl, libssl-dev และอีกร้อยกว่า package
FROM python:3.12

# v2: slim — ตัด development tools ออก เหลือแค่ runtime
FROM python:3.12-slim
```

ตรวจสอบว่า v1 มี packages อะไรที่ v2 ไม่มี:
```bash
docker run --rm lab05:v1 dpkg --get-selections | wc -l
docker run --rm lab05:v2 dpkg --get-selections | wc -l
```

---

## Step 3 — เทคนิคที่ 2: --no-cache-dir และ pip cache

v1 ปล่อยให้ pip เก็บ wheel cache ไว้ใน `/root/.cache/pip`:

```bash
# v1: มี pip cache อยู่ใน image
docker run --rm lab05:v1 du -sh /root/.cache/pip
# 2.6M	/root/.cache/pip

# v3: ไม่มี pip cache (ใช้ --no-cache-dir)
docker run --rm lab05:v3 du -sh /root/.cache/pip 2>/dev/null || echo "no pip cache"
```

```dockerfile
# v1: pip เก็บ cache ไว้ใน image
RUN pip install -r requirements.txt

# v2/v3: pip ไม่เก็บ cache
RUN pip install --no-cache-dir -r requirements.txt
```

> 2.6 MB ดูเล็กน้อย แต่ถ้า requirements มี 50 packages อาจเป็น 50+ MB ที่ไม่จำเป็น

---

## Step 4 — เทคนิคที่ 3: Alpine Base Image

Alpine Linux ใช้ musl libc + BusyBox แทน Debian — เล็กกว่ามาก

```dockerfile
# v3: Alpine
FROM python:3.12-alpine
```

เปรียบเทียบ pip install layer ขนาด:
```bash
# v1 pip layer (with cache)
docker history lab05:v1 --format "{{.Size}}\t{{.CreatedBy}}" | grep pip
# 21.5MB

# v3 pip layer (--no-cache-dir)
docker history lab05:v3 --format "{{.Size}}\t{{.CreatedBy}}" | grep pip
# 18.8MB
```

**Alpine caveats:**
- ใช้ `musl libc` แทน `glibc` — packages บางตัว (numpy, pandas) ไม่มี prebuilt wheel สำหรับ musl → ต้องคอมไพล์จาก source → build นานกว่า
- ถ้าต้องการ package ที่ต้องการ glibc ให้ใช้ `python:3.12-slim` แทน

ทดสอบว่า v3 รันได้จริง:
```bash
docker run --rm -p 8080:8080 -d --name test-v3 lab05:v3
curl http://localhost:8080/
docker rm -f test-v3
```

---

## Step 5 — เทคนิคที่ 4: Multi-Stage Build

Multi-stage แยก build environment ออกจาก runtime environment โดยสมบูรณ์

```dockerfile
# v4: Dockerfile.v4

# Stage 1: builder — ติดตั้ง dependencies
FROM python:3.12 AS builder
RUN pip install --no-cache-dir --prefix=/deps -r requirements.txt
#                               ↑ ติดตั้งใน /deps แทน /usr/local

# Stage 2: runtime — copy เฉพาะ installed packages
FROM python:3.12-alpine AS runtime
COPY --from=builder /deps /usr/local
#    ↑ ไม่มี pip, setuptools, หรือ build cache
```

เปรียบเทียบ packages layer:
```bash
docker history lab05:v3 --format "{{.Size}}\t{{.CreatedBy}}" | grep -E "pip|COPY"
# 18.8MB  RUN pip install ...

docker history lab05:v4 --format "{{.Size}}\t{{.CreatedBy}}" | grep -E "pip|COPY"
# 9.18MB  COPY /deps /usr/local   ← ครึ่งหนึ่งของ v3!
```

**ทำไม v4 เล็กกว่า v3 เกือบครึ่ง?**
- v3: pip ติดตั้งทุกอย่างใน `/usr/local` รวมถึง pip metadata, `__pycache__`, dist-info
- v4: `--prefix=/deps` + `COPY` คัดลอกเฉพาะ package files จริง ๆ
- ผลลัพธ์: packages layer ลดจาก **18.8 MB → 9.18 MB**

---

## Step 6 — เทคนิคเสริม: .dockerignore

ลด build context + ป้องกันไฟล์ลับเข้าไปใน image

```bash
cat > .dockerignore << 'EOF'
__pycache__
*.pyc
.venv
.env
*.log
.git
EOF
```

ทดสอบผล:
```bash
# สร้างไฟล์ที่ไม่ควรอยู่ใน image
echo "SECRET=abc123" > .env

# ถ้าไม่มี .dockerignore → .env เข้าไปด้วย!
docker build -f Dockerfile.v1 -t test-no-ignore . 2>/dev/null
docker run --rm test-no-ignore cat /app/.env

# เมื่อมี .dockerignore → .env ถูก ignore
docker build -f Dockerfile.v3 -t test-with-ignore . 2>/dev/null
docker run --rm test-with-ignore cat /app/.env 2>/dev/null || echo "file not in image"

# cleanup
rm -f .env && docker rmi test-no-ignore test-with-ignore 2>/dev/null || true
```

---

## Step 7 — Security: Scan หา CVE

image ใหญ่ = attack surface มากกว่า = CVE มากกว่า

```bash
# ต้องติดตั้ง trivy ก่อน (ถ้ายังไม่มี)
# curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# เปรียบเทียบจำนวน CVE
trivy image --severity HIGH,CRITICAL lab05:v1 2>/dev/null | tail -5
trivy image --severity HIGH,CRITICAL lab05:v3 2>/dev/null | tail -5
```

> Alpine มี CVE น้อยกว่า Debian อย่างมีนัยสำคัญ เพราะมี packages น้อยกว่า

---

## Step 8 — Cleanup

```bash
docker rmi lab05:v1 lab05:v2 lab05:v3 lab05:v4
rm -f .dockerignore
```

---

## สรุป: Optimization Checklist

```
□ เลือก base image ให้เล็กที่สุดที่ใช้งานได้
    alpine > slim > full
    scratch สำหรับ statically compiled binary (Go, Rust)

□ ใช้ --no-cache-dir กับ pip
    pip install --no-cache-dir -r requirements.txt

□ Layer ordering: เปลี่ยนน้อย → เปลี่ยนบ่อย
    COPY requirements.txt → RUN install → COPY source

□ รวม RUN + cleanup ใน layer เดียว
    RUN apt-get update && apt-get install -y curl \
        && rm -rf /var/lib/apt/lists/*

□ ใช้ .dockerignore
    __pycache__, .venv, .env, .git, *.log

□ Multi-stage เมื่อ build tools ไม่จำเป็นใน runtime
    builder stage → runtime stage

□ รันเป็น non-root user
□ เพิ่ม HEALTHCHECK
□ Scan CVE ก่อน push: trivy image myapp:1.0
```

| เทคนิค | ลดขนาดได้ | ความซับซ้อน |
|--------|----------|------------|
| เปลี่ยนจาก full → slim | -87% | ต่ำ |
| เปลี่ยนจาก slim → alpine | -51% | ต่ำ-กลาง |
| --no-cache-dir | -5-15% | ต่ำมาก |
| Multi-stage | -10-30% สำหรับ Python, -95% สำหรับ Go | กลาง |
| .dockerignore | แล้วแต่โปรเจกต์ | ต่ำมาก |
