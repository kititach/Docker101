# Lab 03: Multi-Arch Build

เป้าหมาย: Build image เดียวให้รันได้ทั้ง `linux/amd64` และ `linux/arm64` (Mac M-series, Raspberry Pi, AWS Graviton) แล้วยืนยันว่ามันใช้งานได้จริง

---

## ทำไมต้อง multi-arch?

- **Mac developer + Linux production** — dev เครื่อง M-series (arm64), prod รัน Intel server (amd64) → image ต้อง match arch ของ runtime
- **AWS Graviton** ราคาถูกกว่า x86 ~20% — แต่ต้องมี arm64 image
- **Raspberry Pi, IoT** — เกือบทั้งหมดเป็น arm/arm64

ทางเดิม: build แยก 2 ครั้ง 2 tag (`myapp:1.0-amd64`, `myapp:1.0-arm64`) → ผู้ใช้ต้องเลือกเอง
ทางใหม่: build **manifest list** ก้อนเดียว tag เดียว → Docker เลือก variant ตาม arch ของเครื่องที่ `pull` อัตโนมัติ

---

## โครงสร้าง Lab

```
03-multi-arch/
├── app/
│   ├── Dockerfile      # base python:3.12-alpine — Python ใช้ same image cross-arch ได้
│   └── server.py       # HTTP server แสดงค่า platform.machine()
├── run-multiarch.sh    # script เต็มลูป
└── README.md
```

---

## ทดลอง

```bash
bash run-multiarch.sh
```

Script จะทำ:
1. **เปิด local registry** ที่ `localhost:5000` (เพื่อไม่ต้องใช้ Docker Hub)
2. **ติดตั้ง QEMU binfmt emulators** — เพื่อ build + run arm64 binary บน amd64 host
3. **สร้าง buildx builder** ใช้ `docker-container` driver (default `docker` driver build multi-arch ไม่ได้)
4. **Build + push** ด้วย `--platform linux/amd64,linux/arm64`
5. **`docker buildx imagetools inspect`** ดู manifest list — เห็น 2 platforms
6. **Pull แบบ default** — daemon เลือก amd64 อัตโนมัติ
7. **Pull --platform linux/arm64** — รันบน amd64 host ผ่าน QEMU

### ผลที่คาดหวัง

```
[6] amd64 variant:
  architecture: x86_64   ← native

[7] arm64 variant (QEMU):
  architecture: aarch64  ← emulated
```

---

## Key Concepts

### 1. buildx drivers
| Driver | Multi-arch? | ใช้เมื่อ |
|--------|-------------|---------|
| `docker` (default) | ❌ | local build single-arch |
| `docker-container` | ✅ | spin up BuildKit container — multi-arch, advanced cache |
| `kubernetes` | ✅ | build บน k8s cluster |
| `remote` | ✅ | คุยกับ BuildKit instance ภายนอก |

```bash
docker buildx create --name multiarch --driver docker-container --use
docker buildx inspect --bootstrap
```

### 2. Manifest list (OCI image index)
ไม่ใช่ image เดียว แต่เป็น **list ของ image** แต่ละ arch:
```
multiarch-demo:v1
├── linux/amd64 → sha256:abc...
└── linux/arm64 → sha256:def...
```

`docker pull` จะดู arch ของ daemon → เลือก digest ที่ match อัตโนมัติ

ดู manifest:
```bash
docker buildx imagetools inspect localhost:5000/multiarch-demo:v1
# หรือ
docker manifest inspect localhost:5000/multiarch-demo:v1
```

### 3. Build args ที่ BuildKit inject ให้
- `TARGETPLATFORM` = `linux/amd64`, `linux/arm64`, ...
- `TARGETOS` = `linux`
- `TARGETARCH` = `amd64`, `arm64`
- `TARGETVARIANT` = `v7` (สำหรับ arm)
- `BUILDPLATFORM` = platform ของเครื่องที่ build (สำหรับ **cross-compile pattern**)

ตัวอย่างใน Go:
```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.22 AS builder
ARG TARGETOS TARGETARCH
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o /app .
# build บน native arch (เร็ว) แต่ produce binary ตาม TARGETARCH
```

### 4. QEMU emulation
BuildKit ใช้ QEMU + binfmt_misc เพื่อรัน binary ของ arch อื่นบน host ปัจจุบัน — ติดตั้งครั้งเดียวต่อ host:
```bash
docker run --privileged --rm tonistiigi/binfmt --install all
```

⚠️ Emulation **ช้ากว่า native หลายเท่า** — production CI ที่ build บ่อยควรใช้ native runner หลาย arch (เช่น GitHub Actions matrix แยก `runs-on: ubuntu-latest` + `runs-on: ubuntu-24.04-arm`)

---

## 🧹 Cleanup
```bash
docker rm -f lab-multiarch-registry
docker buildx rm lab-multiarch-builder
docker buildx use default
docker rmi localhost:5000/multiarch-demo:v1
```
