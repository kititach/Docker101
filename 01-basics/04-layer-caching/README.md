# Lab 04 — Layer Caching

## Objective

เข้าใจว่า Docker layer cache ทำงานอย่างไร และเรียงคำสั่งใน Dockerfile อย่างไรให้ build เร็วที่สุด

---

## ทำไม Layer Caching สำคัญ?

ใน dev loop ทั่วไป: แก้โค้ด → build → รัน ถ้า build ทุกครั้งใช้เวลา 60 วินาที ต่อวันทำ 50 ครั้ง = 50 นาทีรอ build เปล่า ๆ

---

## ทฤษฎี: Docker Layer Cache ทำงานอย่างไร

Docker เปรียบ layer cache เหมือน hash table — แต่ละ layer มี cache key ที่คำนวณจาก:
1. **parent layer** — layer ก่อนหน้า
2. **instruction** — เนื้อหาคำสั่ง (เช่น `RUN pip install flask==3.0.3`)
3. **สำหรับ COPY/ADD** — checksum ของไฟล์ที่ copy

**กฎสำคัญ: Cache miss ที่ layer ใด → ทุก layer ถัดจากนั้นก็ miss ด้วย**

```
FROM python:3.12-alpine   ← cache key: image digest
WORKDIR /app              ← cache key: FROM layer + "WORKDIR /app"
COPY . .                  ← cache key: WORKDIR layer + checksum(app.py, requirements.txt, ...)
RUN pip install ...       ← cache key: COPY layer + "RUN pip install ..."
                            ↑ ถ้า app.py เปลี่ยน → COPY miss → RUN miss ด้วย!
```

---

## Files

```
04-layer-caching/
├── bad/
│   ├── Dockerfile              — COPY . . ก่อน pip install (ลำดับผิด)
│   ├── app.py
│   └── requirements.txt
├── good/
│   ├── Dockerfile              — COPY requirements.txt ก่อน (ลำดับถูก)
│   ├── Dockerfile.cachemount   — BuildKit cache mount (ขั้นสูง)
│   ├── app.py
│   └── requirements.txt
└── README.md
```

---

## Step 1 — Build ครั้งแรก (ไม่มี cache)

```bash
# ทั้งสอง Dockerfile ใช้เวลาใกล้เคียงกันในการ build ครั้งแรก
time docker build --no-cache -t lab04:bad bad/
time docker build --no-cache -t lab04:good good/

# ผลที่ได้ (ประมาณ):
# bad:  ~6.5s
# good: ~7.5s  (สร้าง layer เพิ่ม 1 layer จาก COPY requirements.txt แยก)
```

---

## Step 2 — ดูความต่าง: Bad vs Good หลังแก้โค้ด

**เปรียบเทียบ Dockerfile สองแบบ:**

```dockerfile
# BAD — bad/Dockerfile
COPY . .                              # ← layer 3: checksum ของ ทุกไฟล์
RUN pip install --no-cache-dir -r requirements.txt   # ← layer 4

# ถ้าแก้ app.py → layer 3 miss → layer 4 pip install รันใหม่ทุกครั้ง
```

```dockerfile
# GOOD — good/Dockerfile
COPY requirements.txt .               # ← layer 3: checksum ของ requirements.txt เท่านั้น
RUN pip install --no-cache-dir -r requirements.txt   # ← layer 4
COPY . .                              # ← layer 5: checksum ของทุกไฟล์

# ถ้าแก้ app.py → layer 3 CACHED → layer 4 CACHED → แค่ layer 5 miss
```

**ทดสอบ: จำลองการแก้โค้ด**

```bash
# แก้ source code
echo "# change" >> bad/app.py
echo "# change" >> good/app.py

# rebuild และวัดเวลา
time docker build -t lab04:bad bad/
time docker build -t lab04:good good/
```

ผลที่ได้:
| | rebuild หลังแก้ app.py |
|--|--|
| **bad** | ~6s (pip ติดตั้งใหม่ทุกครั้ง) |
| **good** | **~1s** (pip layer ถูก cache — แค่ COPY . . รันใหม่) |

ดูว่า layer ไหน CACHED ไหน miss:

```bash
docker build -t lab04:good good/ 2>&1 | grep -E "CACHED|\[.*\]"

# คาดว่าเห็น:
# [2/5] WORKDIR /app            → CACHED
# [3/5] COPY requirements.txt . → CACHED
# [4/5] RUN pip install ...     → CACHED
# [5/5] COPY . .                → (miss — ไฟล์เปลี่ยน)
```

---

## Step 3 — Cache Invalidation Chain (Effect ที่สำคัญมาก)

ทดสอบให้เห็นว่า miss หนึ่งครั้ง cascade ลงมาทั้งหมด

แก้ `requirements.txt` (เพิ่ม package):

```bash
echo "colorama==0.4.6" >> good/requirements.txt

time docker build -t lab04:good good/

# ผล:
# [3/5] COPY requirements.txt . → miss (ไฟล์เปลี่ยน)
# [4/5] RUN pip install ...     → miss (parent เปลี่ยน)
# [5/5] COPY . .                → miss (parent เปลี่ยน)
# → pip ติดตั้งใหม่ ~ 6-7s (ถูกต้อง เพราะ dependency จริง ๆ เปลี่ยน)
```

นี่คือพฤติกรรมที่ถูกต้อง — เมื่อ `requirements.txt` เปลี่ยน pip ควรรันใหม่

Revert กลับ:
```bash
# ลบบรรทัดสุดท้าย
head -n -1 good/requirements.txt > tmp && mv tmp good/requirements.txt
```

---

## Step 4 — --no-cache: บังคับ Build ใหม่ทั้งหมด

ใช้เมื่อ: security patch, base image update, ตรวจสอบว่า build reproducible

```bash
time docker build --no-cache -t lab04:good good/

# ทุก layer รันใหม่ ไม่ว่า checksum จะเปลี่ยนหรือไม่
# เหมาะกับ CI/CD pipeline ที่ต้องการ deterministic build
```

> **เมื่อไหรควรใช้ `--no-cache`:**
> - หลัง base image มี security update
> - สงสัยว่า cache มีปัญหา (stale dependency)
> - CI pipeline ที่ต้องการ reproducible build เสมอ

---

## Step 5 — BuildKit Cache Mount (ขั้นสูง)

Layer cache มีข้อจำกัด: ถ้าบังคับ `--no-cache` → pip ต้อง download ทุกอย่างใหม่จาก internet

**BuildKit cache mount** แก้ปัญหานี้โดยเก็บ pip cache ไว้ *นอก* image layers — เหมือนมี local package mirror

```dockerfile
# good/Dockerfile.cachemount
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

ทดสอบ:

```bash
# build ครั้งแรก — download packages และเก็บใน BuildKit cache (~7s)
time docker build --no-cache -f good/Dockerfile.cachemount -t lab04:cm good/

# build ครั้งสอง ด้วย --no-cache — pip อ่านจาก BuildKit cache, ไม่ download ใหม่ (~5-6s)
time docker build --no-cache -f good/Dockerfile.cachemount -t lab04:cm good/
```

> **ข้อสังเกต:** บนเครื่องนี้ packages ส่วนใหญ่เป็น prebuilt wheel ที่เบา ความต่างน้อย  
> ประโยชน์ชัดเจนขึ้นเมื่อ: packages ต้องคอมไพล์จาก source (numpy, psycopg2), package มีจำนวนมาก, หรือ connection ช้า

**ข้อดีของ cache mount:**
- pip cache ไม่ถูกเก็บใน image layer → image size ไม่เพิ่ม
- cache persist ข้ามการ build แม้ใช้ `--no-cache`
- ใช้ได้กับ package manager อื่นด้วย: npm, apt, go module

ตัวอย่างสำหรับ package manager อื่น:
```dockerfile
# npm
RUN --mount=type=cache,target=/root/.npm \
    npm ci

# apt
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && apt-get install -y curl

# go modules
RUN --mount=type=cache,target=/go/pkg/mod \
    go build ./...
```

---

## Step 6 — .dockerignore: อีกหนึ่งตัวที่กระทบ Cache

ถ้าไม่มี `.dockerignore` → `COPY . .` จะ copy ทุกอย่าง รวมถึง:
- `.git/` — repository history (อาจ > 100MB)
- `node_modules/`, `__pycache__/`, `.venv/` — build artifacts
- `.env` — secrets!

ไฟล์เหล่านี้ทำให้ checksum เปลี่ยนบ่อยขึ้น → cache miss บ่อยขึ้น

สร้าง `.dockerignore`:

```bash
cat > good/.dockerignore << 'EOF'
__pycache__
*.pyc
.venv
.env
.git
*.md
EOF
```

ตรวจสอบผลต่อ cache:
```bash
# แตะไฟล์ที่ ignore แล้ว rebuild — cache ควรยังอยู่
touch good/README.md
docker build -t lab04:good good/
# [5/5] COPY . . → CACHED (เพราะ README.md ถูก ignore)
```

---

## Step 7 — Cleanup

```bash
docker rmi lab04:bad lab04:good lab04:cm

# ลบไฟล์ที่สร้างระหว่าง lab
rm -f good/.dockerignore
# ถ้าแก้ app.py ไว้ ให้ revert กลับ
```

---

## สรุป: กฎการเรียงลำดับ Layers

```
เปลี่ยนน้อย (บน)   →   เปลี่ยนบ่อย (ล่าง)
────────────────────────────────────────────
FROM base-image
WORKDIR
COPY lock-files / requirements    ← เปลี่ยนเฉพาะตอนเพิ่ม dependency
RUN install dependencies          ← ขึ้นอยู่กับ lock-files
COPY source-code                  ← เปลี่ยนทุก commit
RUN build / compile               ← ขึ้นอยู่กับ source-code
CMD / ENTRYPOINT
```

| Technique | ช่วยอะไร | ข้อจำกัด |
|-----------|---------|---------|
| **Good layer order** | rebuild เร็วขึ้นมากเมื่อแก้ source | ต้องวางแผน Dockerfile ตั้งแต่ต้น |
| **`--no-cache`** | force rebuild ทั้งหมด | ช้าเท่ากับ build ครั้งแรก |
| **BuildKit cache mount** | pip/npm cache ข้ามการ build | ต้องใช้ BuildKit (default ใน Docker 23+) |
| **`.dockerignore`** | ลด context size + stabilize COPY checksum | ต้องดูแลให้ครบ |
