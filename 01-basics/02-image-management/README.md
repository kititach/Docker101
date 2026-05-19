# Lab 02 — Image Management

## Objective

เข้าใจ image lifecycle ทั้งหมด: pull, build, tag, inspect, save/load และ cleanup

---

## ทำไมต้องเรียน Image Management?

Container ทุกตัวเกิดจาก image ถ้าจัดการ image ไม่เป็นจะเจอปัญหาเหล่านี้:
- disk เต็มจาก dangling images ที่สะสมระหว่าง build
- ไม่รู้ว่า image มาจากไหน ใช้ layer อะไรบ้าง
- deploy ผิด version เพราะ tag ไม่ชัดเจน
- ย้าย image ระหว่าง environment ไม่ได้เมื่อไม่มี internet

---

## Files

```
02-image-management/
├── app/
│   ├── Dockerfile     — สร้าง image สำหรับ lab นี้
│   └── server.py      — HTTP server แสดง version + hostname
└── README.md
```

---

## Step 1 — Pull images และทำความเข้าใจ Tags

Pull image มาหลาย version เพื่อดูว่า tag ทำงานอย่างไร

```bash
docker pull alpine:3.20
docker pull alpine:3.19
docker pull python:3.12-alpine
```

ดู image ทั้งหมดที่มีอยู่:

```bash
docker images
```

สังเกต:
- แต่ละ tag คือ pointer ไปหา image ID
- `alpine:3.20` และ `alpine:3.19` มี Image ID ต่างกัน
- `CREATED` คือเวลาที่ image ถูกสร้าง ไม่ใช่เวลาที่ pull

ดูเฉพาะ alpine images:

```bash
docker images alpine
```

ตรวจสอบ digest (unique identifier ที่ไม่เปลี่ยนแม้ tag จะเปลี่ยน):

```bash
docker images --digests alpine
```

---

## Step 2 — Build Image จาก Dockerfile

Build version 1.0:

```bash
cd app
docker build -t myapp:1.0 .
```

Build version 2.0 (ใช้ build argument เปลี่ยน version):

```bash
docker build -t myapp:2.0 --build-arg APP_VERSION=2.0 .
```

ดู images ที่ build มา:

```bash
docker images myapp
```

> **สังเกต:** Build ครั้งที่สองเร็วกว่าเพราะ layers ที่ไม่เปลี่ยนถูก cache ไว้ (จะเรียนละเอียดใน Lab 04)

---

## Step 3 — Tag Image

Tag คือ alias ที่ชี้ไปหา image ID เดียวกัน การ tag ไม่ copy image

เพิ่ม tag `latest` ให้ version ล่าสุด:

```bash
docker tag myapp:2.0 myapp:latest
```

ตอนนี้ `myapp:2.0` และ `myapp:latest` มี Image ID เดียวกัน:

```bash
docker images myapp
```

สร้าง tag แบบ "เหมือนส่งไป private registry":

```bash
docker tag myapp:1.0 localhost:5000/myapp:1.0
docker tag myapp:2.0 localhost:5000/myapp:2.0
```

ดูผล:

```bash
docker images | grep myapp
```

> **ข้อสังเกต:** image ID เดียวกัน แต่มีหลาย tag — Docker ไม่เปลืองพื้นที่ซ้ำ

---

## Step 4 — Inspect Image Layers ด้วย history

ดูว่า image สร้างจาก layer อะไรบ้าง:

```bash
docker history myapp:1.0
```

ดูแบบไม่ตัดข้อความ (เห็น command เต็ม):

```bash
docker history --no-trunc myapp:1.0
```

เปรียบเทียบ python:3.12-alpine กับ myapp:1.0:

```bash
docker history python:3.12-alpine
docker history myapp:1.0
```

> **สังเกต:** layers ของ `python:3.12-alpine` ปรากฏอยู่ใน `myapp:1.0` ด้วย เพราะ `myapp:1.0` ต่อยอดมาจาก base image นั้น

---

## Step 5 — Inspect Image Metadata

ดู metadata ทั้งหมดของ image (JSON format):

```bash
docker image inspect myapp:1.0
```

ดึงข้อมูลเฉพาะที่สนใจด้วย format template:

```bash
# ดู architecture
docker image inspect myapp:1.0 --format '{{.Architecture}}'

# ดู OS
docker image inspect myapp:1.0 --format '{{.Os}}'

# ดู environment variables
docker image inspect myapp:1.0 --format '{{range .Config.Env}}{{println .}}{{end}}'

# ดู exposed ports
docker image inspect myapp:1.0 --format '{{json .Config.ExposedPorts}}'

# ดู total size (bytes)
docker image inspect myapp:1.0 --format '{{.Size}}'
```

เปรียบเทียบ size ระหว่าง version:

```bash
docker image inspect myapp:1.0 myapp:2.0 --format '{{.RepoTags}} → {{.Size}} bytes'
```

---

## Step 6 — Dangling Images

"Dangling image" คือ image ที่ไม่มี tag ชี้อยู่ — เกิดเมื่อ build image ใหม่ด้วย tag เดิม

สร้าง dangling image โดย build ซ้ำ:

```bash
docker build -t myapp:1.0 .   # สร้าง layer ใหม่ที่ไม่มี tag
docker build -t myapp:1.0 .   # อีกครั้ง
```

> ถ้า `server.py` ไม่เปลี่ยน BuildKit จะใช้ cache จึงไม่เกิด dangling  
> แก้ไขไฟล์เล็กน้อยก่อน build เพื่อบังคับให้เกิด dangling:

```bash
echo "# rebuild" >> app/server.py
docker build -t myapp:1.0 app/
echo "# rebuild2" >> app/server.py
docker build -t myapp:1.0 app/
```

ดู dangling images:

```bash
docker images -f dangling=true
```

ลบ dangling images ทั้งหมด:

```bash
docker image prune
```

ดูว่าหายไปแล้ว:

```bash
docker images -f dangling=true
```

---

## Step 7 — Save และ Load (ย้าย image โดยไม่ผ่าน registry)

ใช้เมื่อ: air-gapped environment, ส่ง image ให้คนอื่นโดยไม่มี registry, backup

Export image เป็นไฟล์ tar:

```bash
docker save myapp:1.0 -o myapp-1.0.tar
ls -lh myapp-1.0.tar
```

Export หลาย image พร้อมกัน:

```bash
docker save myapp:1.0 myapp:2.0 -o myapp-all.tar
```

ลบ image ออกจาก local แล้ว load กลับมา:

```bash
docker rmi myapp:1.0
docker images myapp

docker load -i myapp-1.0.tar
docker images myapp
```

> **save vs export:**  
> `docker save` — บันทึก image (พร้อม layers และ history) → ใช้ `docker load`  
> `docker export` — บันทึก container filesystem (ไม่มี history) → ใช้ `docker import`  
> ใช้ `save/load` สำหรับแชร์ image เสมอ

---

## Step 8 — Remove Images

ลบ image ด้วย tag:

```bash
docker rmi myapp:latest
```

ลบ image ด้วย Image ID (ลบทุก tag ที่ชี้มา):

```bash
# ดู ID ก่อน
docker images myapp
# จากนั้น rmi ด้วย ID (แค่ 3-4 ตัวแรกก็พอ)
docker rmi <image-id>
```

ลบ image ที่ค้างจากการ pull:

```bash
docker rmi alpine:3.19 localhost:5000/myapp:1.0 localhost:5000/myapp:2.0
```

ลบ image ที่ไม่ได้ใช้งานทั้งหมด (ไม่มี container ใดใช้อยู่):

```bash
docker image prune -a
```

> **ระวัง:** `-a` จะลบทุก image ที่ไม่มี container รัน/หยุดอยู่

---

## Step 9 — Cleanup สมบูรณ์

```bash
# ลบไฟล์ tar ที่สร้างไว้
rm -f myapp-1.0.tar myapp-all.tar

# ลบ test lines ที่เพิ่มใน server.py
# (แก้กลับเอง หรือ git checkout app/server.py)

# ดู disk usage ก่อน/หลัง
docker system df

# ลบ images ที่ไม่ใช้ทั้งหมด
docker image prune -a

docker system df
```

---

## สรุป Commands

| Command | ใช้ทำอะไร |
|---------|-----------|
| `docker pull image:tag` | ดึง image จาก registry |
| `docker images` / `docker image ls` | แสดง images ทั้งหมด |
| `docker images -f dangling=true` | แสดงเฉพาะ dangling images |
| `docker images --digests` | แสดง content digest |
| `docker build -t name:tag .` | build image จาก Dockerfile |
| `docker build --build-arg K=V .` | build พร้อมส่ง ARG |
| `docker tag src:tag dst:tag` | สร้าง tag ใหม่ (ไม่ copy) |
| `docker history image:tag` | ดู layers และ commands |
| `docker image inspect image:tag` | ดู metadata ทั้งหมด |
| `docker image inspect --format` | ดึงข้อมูลเฉพาะส่วน |
| `docker save image -o file.tar` | export image เป็น tar |
| `docker load -i file.tar` | import image จาก tar |
| `docker rmi image:tag` | ลบ image |
| `docker image prune` | ลบ dangling images |
| `docker image prune -a` | ลบ images ที่ไม่มี container ใช้ |
| `docker system df` | ดู disk usage |

---

## Key Concepts

**Image ID vs Tag**
- Image ID คือ hash ของ content — ไม่เปลี่ยน
- Tag คือ pointer (mutable) — เปลี่ยนได้ ชี้ไปหา ID ต่าง ๆ ได้
- `latest` ไม่ได้หมายความว่าใหม่สุดเสมอ — เป็นแค่ tag ธรรมดาที่ชื่อ "latest"

**Dangling Image**
- Image ที่ไม่มี tag ชี้อยู่ (เกิดจาก rebuild tag เดิม)
- สะสมทีละนิด กินพื้นที่ disk — ควร `prune` เป็นประจำ

**Digest**
- `sha256:abc123...` คือ cryptographic hash ของ image content
- ใช้ pin version อย่างแน่นอน: `FROM python:3.12-alpine@sha256:...`
- Tag เปลี่ยนได้ แต่ digest ไม่เปลี่ยน
