# Lab 03 — Dockerfile Fundamentals

## Objective

เข้าใจ Dockerfile instruction ทุกตัวที่ใช้บ่อย — ทำไม, อย่างไร, และ trade-off

---

## Files

```
03-dockerfile/
├── app/
│   ├── app.py                  — CLI tool: hello / env / whoami
│   ├── Dockerfile.cmd          — สาธิต CMD override
│   ├── Dockerfile.entrypoint   — สาธิต ENTRYPOINT + CMD
│   └── Dockerfile              — full best-practices example
└── README.md
```

---

## Step 1 — FROM: เลือก base image

`FROM` คือ instruction แรกเสมอ — กำหนด base ที่ทุก layer จะต่อยอดขึ้นมา

```bash
# ดูขนาดก่อนเลือก base
docker pull python:3.12          # full Debian — ใหญ่
docker pull python:3.12-slim     # Debian ตัดเครื่องมือ dev ออก
docker pull python:3.12-alpine   # Alpine Linux — เล็กที่สุด

docker images python
```

เปรียบเทียบขนาด (ประมาณ):
| Base | ขนาด | เหมาะกับ |
|------|------|---------|
| `python:3.12` | ~1 GB | dev environment ที่ต้องการ tooling ครบ |
| `python:3.12-slim` | ~130 MB | production ทั่วไป |
| `python:3.12-alpine` | ~55 MB | production ที่ต้องการ size เล็ก |

> **Alpine caveat:** ใช้ `musl libc` แทน `glibc` — บาง Python package (numpy, pandas) อาจ build นานกว่าหรือมีปัญหา เพราะไม่มี prebuilt wheel สำหรับ musl

กฎเลือก base image:
1. เริ่มจาก official image เสมอ
2. ใช้ specific tag (ไม่ใช่ `latest`) เพื่อ reproducibility
3. เลือก alpine/slim เมื่อไม่ต้องการ tooling พิเศษ

---

## Step 2 — RUN: Shell Form vs Exec Form

```bash
cd app
```

**Shell form** — Docker รัน command ผ่าน `/bin/sh -c`:
```dockerfile
RUN echo hello           # จริง ๆ คือ: /bin/sh -c "echo hello"
```

**Exec form** — Docker รัน binary โดยตรง ไม่ผ่าน shell:
```dockerfile
RUN ["echo", "hello"]
```

ปัญหาของ shell form:
- shell ต้องมีอยู่ใน image (`scratch` image ไม่มี `/bin/sh`)
- variable expansion อาจแตกต่างกันตาม shell
- process ที่รันจริงคือ `/bin/sh` ไม่ใช่ command โดยตรง

**การลด layers ด้วยการรวม RUN:**

```dockerfile
# BAD — 4 layers
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y git
RUN rm -rf /var/lib/apt/lists/*

# GOOD — 1 layer + cleanup อยู่ layer เดียวกัน
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*
```

> ถ้า `rm` อยู่ใน `RUN` แยก layer จะไม่ลด size — Docker เก็บ layer เก่าไว้เสมอ

---

## Step 3 — COPY vs ADD

**ใช้ COPY เสมอสำหรับ local files:**

```dockerfile
COPY app.py .              # copy ไฟล์เดี่ยว
COPY src/ /app/src/        # copy ทั้ง directory
COPY *.py /app/            # wildcard
```

**ใช้ ADD เฉพาะสองกรณีนี้:**

```dockerfile
# กรณี 1: extract tar อัตโนมัติ
ADD archive.tar.gz /app/

# กรณี 2: (หลีกเลี่ยงถ้าทำได้) copy จาก URL
ADD https://example.com/file.txt /app/
```

> `ADD` จาก URL ไม่ถูก cache อย่างถูกต้องและเป็น security risk — ใช้ `RUN curl` แทนและ verify checksum

---

## Step 4 — WORKDIR

`WORKDIR` กำหนด working directory สำหรับ instruction ที่ตามมา (`RUN`, `COPY`, `CMD`, `ENTRYPOINT`)

```dockerfile
# BAD
RUN mkdir -p /app
RUN cd /app   # ไม่มีผล — แต่ละ RUN เริ่ม shell ใหม่!
COPY . .      # copy ไปที่ / ไม่ใช่ /app

# GOOD
WORKDIR /app
COPY . .      # copy ไปที่ /app
```

`WORKDIR` สร้าง directory ให้อัตโนมัติถ้าไม่มี ไม่ต้องรัน `mkdir`

---

## Step 5 — ENV vs ARG

**ARG** — มีชีวิตแค่ตอน build

```bash
docker build --build-arg APP_VERSION=2.0 -t myapp .
```

```dockerfile
ARG APP_VERSION=1.0          # มี default ได้
RUN echo "Building v${APP_VERSION}"
# หลัง build เสร็จ ARG หายไป — ไม่มีใน container
```

**ENV** — คงอยู่ใน container ตลอดเวลา

```dockerfile
ENV APP_VERSION=1.0
# accessible ทั้งตอน build และ runtime
```

**ใช้ ARG → ENV เพื่อรับค่าจากภายนอกแล้วเก็บไว้ runtime:**

```dockerfile
ARG APP_VERSION=1.0
ENV APP_VERSION=${APP_VERSION}
```

> **Security:** ทั้ง ARG และ ENV ปรากฏใน `docker history` และ `docker inspect`  
> ห้ามใส่ secrets (passwords, API keys) ใน ENV หรือ ARG เด็ดขาด — ใช้ Docker Secrets แทน

---

## Step 6 — CMD: Default Command ที่ override ได้ทั้งหมด

Build และทดสอบ:

```bash
docker build -f Dockerfile.cmd -t lab03:cmd .
```

รันปกติ (ใช้ CMD ที่กำหนดไว้):
```bash
docker run --rm lab03:cmd
# Hello, docker!  (app v1.0)
```

Override CMD ทั้งหมดด้วย arguments:
```bash
docker run --rm lab03:cmd python app.py hello claude
# Hello, claude!  (app v1.0)
```

```bash
docker run --rm lab03:cmd python app.py env
# แสดง environment variables
```

> เมื่อส่ง arguments ตอน `docker run` — **CMD ทั้งก้อนถูกแทนที่**

---

## Step 7 — ENTRYPOINT + CMD: กำหนด executable ที่แน่นอน

Build และทดสอบ:

```bash
docker build -f Dockerfile.entrypoint -t lab03:ep .
```

รันปกติ (ENTRYPOINT + CMD รวมกัน = `python app.py hello docker`):
```bash
docker run --rm lab03:ep
# Hello, docker!  (app v1.0)
```

Override เฉพาะ CMD arguments:
```bash
docker run --rm lab03:ep hello claude
# Hello, claude!  (app v1.0)

docker run --rm lab03:ep whoami
# uid=0 (root)  ← ยังเป็น root เพราะ Dockerfile.entrypoint ไม่มี USER

docker run --rm lab03:ep env
# แสดง environment variables
```

Override ENTRYPOINT (ต้องใช้ flag `--entrypoint`):
```bash
docker run --rm --entrypoint sh lab03:ep
# เข้า shell ได้ — เหมาะสำหรับ debug
```

**สรุปความต่าง:**

| Dockerfile | `docker run img` | `docker run img hello claude` |
|-----------|------------------|-------------------------------|
| `CMD ["python","app.py","hello","docker"]` | `python app.py hello docker` | `hello claude` (แทนทั้งหมด) |
| `ENTRYPOINT ["python","app.py"]` + `CMD ["hello","docker"]` | `python app.py hello docker` | `python app.py hello claude` (ต่อท้าย) |

> **Pattern ที่แนะนำ:** ใช้ ENTRYPOINT + CMD เสมอเมื่อ container มี purpose เดียว  
> ENTRYPOINT = executable ที่ไม่เปลี่ยน, CMD = default arguments ที่ user เปลี่ยนได้

---

## Step 8 — USER: รันเป็น non-root

Build full Dockerfile แล้วเปรียบเทียบ:

```bash
docker build -f Dockerfile -t lab03:full --build-arg BUILD_DATE=$(date -I) .
```

```bash
# lab03:ep ไม่มี USER → รันเป็น root
docker run --rm lab03:ep whoami
# uid=0 (root)

# lab03:full มี USER appuser → รันเป็น non-root
docker run --rm lab03:full whoami
# uid=100 (appuser)
```

ทำไมต้องรันเป็น non-root:
- ถ้า container ถูก exploit → attacker ได้แค่ appuser ไม่ใช่ root
- ป้องกัน privilege escalation บน host ในบาง configuration
- เป็น compliance requirement ในหลาย organization

Alpine ใช้ pattern นี้:
```dockerfile
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
```

> `-S` = system user (no password, no shell, no home directory ยกเว้นตั้งเอง)

---

## Step 9 — EXPOSE + HEALTHCHECK + LABEL

**EXPOSE** — เอกสารเท่านั้น ไม่ได้ publish port จริง:
```dockerfile
EXPOSE 8080
# ยังต้องใช้ -p 8080:8080 ตอน docker run
```

ประโยชน์: tooling เช่น Compose, Kubernetes อ่าน EXPOSE เพื่อรู้ว่า service ฟังที่ port ไหน

**HEALTHCHECK** — Docker daemon จะ poll สม่ำเสมอ:
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python app.py whoami || exit 1
```

ดูสถานะ health:
```bash
docker run -d --name test-health lab03:full
sleep 5
docker inspect test-health --format '{{.State.Health.Status}}'
docker rm -f test-health
```

**LABEL** — metadata ตาม OCI standard:
```dockerfile
LABEL org.opencontainers.image.title="myapp" \
      org.opencontainers.image.version="1.0" \
      org.opencontainers.image.authors="team@example.com"
```

ดู labels:
```bash
docker image inspect lab03:full --format '{{json .Config.Labels}}'
```

---

## Step 10 — ENV + ARG ใน Full Dockerfile

ตรวจสอบว่า ARG ถูกส่งผ่าน ENV เข้ามาใน container:
```bash
docker run --rm lab03:full env
# APP_VERSION  = 1.0
# BUILD_DATE   = 2026-05-19
```

Build ด้วย version ต่างออกไป:
```bash
docker build -f Dockerfile -t lab03:v2 \
  --build-arg APP_VERSION=2.0 \
  --build-arg BUILD_DATE=$(date -I) .

docker run --rm lab03:v2 env
# APP_VERSION  = 2.0
```

ดูว่า ARG ปรากฏใน history (security concern):
```bash
docker history lab03:v2
# สังเกต layer ที่มี APP_VERSION=2.0
```

---

## Step 11 — Cleanup

```bash
docker rmi lab03:cmd lab03:ep lab03:full lab03:v2
```

---

## Image ที่ Build ไปอยู่ที่ไหน?

เมื่อรัน `docker build` — image ถูกเก็บใน **local image store** ของ Docker daemon บนเครื่องคุณ ไม่ได้ขึ้น internet อัตโนมัติ

```bash
# ดู path จริงบน Linux
docker info | grep "Docker Root Dir"
# Docker Root Dir: /var/lib/docker

# layers อยู่ที่
ls /var/lib/docker/overlay2/   # layer data (OverlayFS)
ls /var/lib/docker/image/      # image metadata
```

ดู images ทั้งหมดที่อยู่บนเครื่อง:
```bash
docker images
docker system df          # ดู disk ที่ Docker ใช้ทั้งหมด
```

images ยังอยู่หลัง reboot — Docker daemon จัดการเอง  
หายเมื่อ: `docker rmi`, `docker system prune`, หรือ uninstall Docker

---

### จะเอาขึ้น Internet ได้สองทาง

**1. Push ขึ้น Registry** (Docker Hub, GitHub GHCR, AWS ECR ฯลฯ)

```bash
# tag ให้ตรงกับ registry ก่อน
docker tag lab03:full yourusername/lab03:full

# login แล้ว push
docker login
docker push yourusername/lab03:full

# คนอื่น pull ได้จากทั่วโลก
docker pull yourusername/lab03:full
```

**2. Save เป็นไฟล์ tar** (ส่งให้คนอื่นโดยไม่ผ่าน registry)

```bash
docker save lab03:full -o lab03-full.tar     # export
docker load -i lab03-full.tar                # import บนเครื่องอื่น
```

---

### Flow สรุป

```
Dockerfile
    │
    ▼ docker build
Local image store (/var/lib/docker)
    │
    ├── docker push ──→ Registry (Docker Hub, GHCR, ECR, ...)
    │                       │
    │                       ▼ docker pull
    │                   เครื่องอื่น
    │
    └── docker save ──→ .tar file ──→ docker load ──→ เครื่องอื่น
```

> **Public vs Private registry:**  
> Docker Hub image ที่ไม่ได้ set เป็น private — ใครก็ pull ได้  
> ถ้ามี proprietary code ใน image ต้องใช้ private registry หรือ set visibility เป็น private เสมอ

---

## สรุป Instructions

| Instruction | ใช้ทำอะไร | หมายเหตุ |
|-------------|-----------|----------|
| `FROM` | base image | ใช้ specific tag + alpine/slim |
| `RUN` | รัน command ตอน build | รวมเป็น layer เดียว + cleanup |
| `COPY` | copy local files | ใช้แทน ADD เสมอ ยกเว้นต้องการ tar extract |
| `ADD` | copy + extract tar | ระวัง unexpected behavior กับ URL |
| `WORKDIR` | set working directory | สร้างให้อัตโนมัติ ไม่ต้อง mkdir |
| `ENV` | runtime environment variable | ห้ามใส่ secrets |
| `ARG` | build-time variable | ไม่ติดมาใน container (แต่ยังอยู่ใน history) |
| `CMD` | default command | override ได้ทั้งก้อนตอน docker run |
| `ENTRYPOINT` | executable ที่ไม่เปลี่ยน | ใช้คู่กับ CMD |
| `USER` | run as user | ใช้ non-root เสมอใน production |
| `EXPOSE` | document port | ไม่ publish จริง |
| `HEALTHCHECK` | health check command | ใช้ใน production เสมอ |
| `LABEL` | image metadata | ตาม OCI image spec |

## Key Rules

1. **Exec form สำหรับ CMD/ENTRYPOINT** — `["python", "app.py"]` ไม่ใช่ `python app.py`
2. **รวม RUN + cleanup ใน layer เดียวกัน** — ไม่เช่นนั้น cleanup ไม่ลด size
3. **COPY ก่อน ADD** — ADD มี side effects ที่ไม่คาดคิด
4. **USER ก่อน CMD** — อย่ารัน process หลักเป็น root
5. **ARG + ENV pattern** — รับค่าจากภายนอก build แล้วส่งไปใน runtime
