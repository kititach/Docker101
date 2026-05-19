# Lab 02 — Python: Build with gcc, Run on slim

## ผลวัดจริง

| Stage | Image | ขนาด |
|-------|-------|------|
| Builder | `python:3.12` + gcc + compiled packages | 1.64 GB |
| **Final** | `python:3.12-slim` + packages เท่านั้น | **203 MB** |

ลด **88%** — ไม่มี gcc, make, build-essential ใน final image

---

## ทำไมต้อง multi-stage สำหรับ Python?

Package อย่าง `cryptography` มี Rust extension ที่ต้องการ compiler:
- ถ้าใช้ alpine runtime — compile บน alpine ต้องการ `musl-dev`, `libffi-dev`
- ถ้าใช้ glibc builder — runtime ต้องเป็น glibc เช่นกัน (slim, ไม่ใช่ alpine)

> **Alpine + glibc binary ไม่ compatible** — Alpine ใช้ musl libc ส่วน `python:3.12` full/slim ใช้ glibc
> binary ที่ compile บน glibc จะ error `ImportError: libgcc_s.so.1: No such file or directory` บน Alpine

---

## Files

```
02-python/
├── app.py          — Flask + cryptography (encrypt/decrypt demo)
├── requirements.txt
├── Dockerfile
└── README.md
```

---

## Step 1 — ดู Dockerfile

```dockerfile
# Stage 1: Builder — python:3.12 full มี gcc สำหรับ compile Rust/C extensions
FROM python:3.12 AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/deps -r requirements.txt

# Stage 2: Runtime — slim ใช้ glibc เหมือน builder → binary compatible
FROM python:3.12-slim AS runtime
WORKDIR /app
COPY --from=builder /deps /usr/local
COPY app.py .
```

---

## Step 2 — Build และเปรียบเทียบ

```bash
docker build -t ms-python:final .
docker build --target builder -t ms-python:builder .

docker images | grep ms-python
# ms-python:builder   1.64GB
# ms-python:final      203MB
```

เปรียบเทียบ layers:
```bash
# builder: packages layer
docker history ms-python:builder --format "{{.Size}}\t{{.CreatedBy}}" | grep pip
# ~400MB  ← รวม pip cache, wheel cache, setuptools

# final: copy layer
docker history ms-python:final --format "{{.Size}}\t{{.CreatedBy}}" | grep COPY
# ~160MB  ← เฉพาะ installed packages ไม่มี pip infrastructure
```

---

## Step 3 — ทดสอบ

```bash
docker run -d --name py-app -p 9092:8080 ms-python:final

curl http://localhost:9092/
# {
#   "decrypted": "hello-world",
#   "encrypted": "gAAAAABqC-...",
#   "host": "...",
#   "service": "python-app"
# }
```

cryptography ทำงานได้แม้ไม่มี gcc ใน final image เพราะ compile ไปแล้วใน builder stage

---

## Step 4 — ยืนยันว่าไม่มี Build Tools ใน Final

```bash
# ตรวจสอบว่า gcc ไม่อยู่ใน final image
docker run --rm ms-python:final gcc --version
# OCI runtime exec failed: exec: "gcc": executable file not found
# ← ถูกต้อง gcc ถูกทิ้งไว้ใน builder stage

# แต่ package ใช้งานได้
docker run --rm ms-python:final python -c "from cryptography.fernet import Fernet; print('OK')"
# OK
```

---

## Cleanup

```bash
docker rm -f py-app
docker rmi ms-python:final ms-python:builder
```
