# Module 11: BuildKit & buildx

BuildKit เป็น engine build รุ่นใหม่ที่มาแทน legacy builder ตั้งแต่ Docker 23+ (default แล้ว) — เปิดฟีเจอร์ที่ทำ pipeline เร็วและปลอดภัยขึ้นเยอะ

Module นี้ครอบคลุม 3 ฟีเจอร์หลักของ BuildKit ที่ทุก project ที่ใช้ Docker ใน production ควรใช้

## Labs

| Lab | หัวข้อ | สิ่งที่ได้ |
|-----|--------|-----------|
| `01-cache-mounts/` | `--mount=type=cache` | cache ของ pip/apt/npm ข้าม build ทำให้ rebuild หลัง layer invalidate เร็วขึ้นมาก |
| `02-secret-mounts/` | `--mount=type=secret` | ส่ง secret เข้า build โดยไม่หลุดเข้า image layers — เทียบกับ ARG/COPY ที่หลุดทั้งคู่ |
| `03-multi-arch/` | `buildx --platform` | build image เดียวรันได้ทั้ง amd64 + arm64 ผ่าน manifest list + QEMU |

## ทำไม BuildKit?

| | Legacy builder | BuildKit |
|---|---|---|
| สั่ง build | `docker build` (default ใน Docker <23) | `docker build` (default ใน Docker 23+) หรือ `docker buildx build` |
| Parallel layers | sequential | ✅ parallel ทุก layer ที่ไม่ depends กัน |
| Cache mount | ❌ | ✅ `--mount=type=cache` |
| Secret mount | ❌ (ใช้ได้แค่ ARG/COPY ซึ่งหลุด) | ✅ `--mount=type=secret` |
| Multi-arch | ❌ | ✅ `--platform linux/amd64,linux/arm64` |
| Remote cache | ❌ | ✅ `--cache-to/from type=registry` |
| Frontend syntax | fixed | ✅ `# syntax=docker/dockerfile:1.7` |

## Enable BuildKit (ถ้ายังไม่ default)

```bash
# วิธี 1: env var
DOCKER_BUILDKIT=1 docker build .

# วิธี 2: ใช้ buildx (มาคู่กับ BuildKit เสมอ)
docker buildx build .

# วิธี 3: เซ็ตถาวรใน daemon
# แก้ /etc/docker/daemon.json → {"features": {"buildkit": true}}
```

ตรวจสอบ:
```bash
docker buildx version
docker buildx ls
```

## บรรทัด syntax สำคัญมาก

ทุก Dockerfile ที่ใช้ feature ใหม่ของ BuildKit ต้องใส่บรรทัดนี้เป็นบรรทัดแรก:

```dockerfile
# syntax=docker/dockerfile:1.7
```

ไม่ใช่ comment ธรรมดา — เป็น directive ที่บอก BuildKit ว่าใช้ Dockerfile frontend version ไหน (จาก Docker Hub) ถ้าไม่ใส่ คำสั่งใหม่ๆ เช่น `--mount=type=cache` จะไม่ทำงาน

---

## ลำดับแนะนำในการทำ

1. **`01-cache-mounts/`** — เข้าใจ feature พื้นฐานที่สุด ใช้บ่อยที่สุด
2. **`02-secret-mounts/`** — security-critical สำหรับ private registry / private packages
3. **`03-multi-arch/`** — advanced, ต้องการ buildx builder แยก
