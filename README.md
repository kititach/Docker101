# Docker Learning Lab

Hands-on labs สำหรับเรียน Docker อย่างลึกซึ้ง ตั้งแต่พื้นฐานจนถึง production patterns — **46 sub-labs ที่รันได้จริงทั้งหมด**

อธิบายเป็นภาษาไทย / technical terms เป็นภาษาอังกฤษ

---

## เหมาะกับใคร

- คนที่ใช้ `docker run nginx` ได้แต่ไม่เข้าใจว่ามันทำงานอย่างไรข้างใน
- Developer ที่อยากเลื่อนจาก "ใช้ Docker เป็น" → "เอา Docker ขึ้น production ได้ปลอดภัย"
- เตรียมตัวสอบ DCA / สัมภาษณ์ DevOps role

ไม่เหมาะกับ: ผู้ที่ยังไม่เคยรัน command line — ควรเริ่มจาก Linux basics ก่อน

---

## โครงสร้าง

```
docker/
├── CLAUDE.md         ← reference guide ครบทุก concept + best practices
├── STATUS.md         ← progress tracker (อ่านก่อนเริ่มทุก session)
├── cleanup.sh        ← เคลีย containers/networks/volumes ระหว่าง lab
│
├── 00-setup/         install Docker CE บน Ubuntu / Mint
├── 01-basics/        container lifecycle, image, Dockerfile, layer cache, optimization
├── 02-networking/    bridge, custom network + DNS, host, none, port mapping
├── 03-volumes/       named volume, bind mount, tmpfs, volume drivers, backup/restore
├── 04-compose/       compose basics, depends + healthcheck, profiles, secrets, override
├── 05-multi-stage/   Go / Python / Node.js multi-stage builds
├── 06-security/      non-root, capabilities, read-only fs, image scan, runtime hardening
├── 07-registry/      private registry, auth, TLS, maintenance
├── 08-swarm/         init + service, stacks, rolling update, secrets & configs
├── 09-monitoring/    log drivers, Loki + Promtail + Grafana, resource limits, Prom + cAdvisor
├── 10-ci-cd/         DinD vs DooD, GitHub Actions, GitLab CI (with Trivy + multi-arch)
└── 11-buildkit/      cache mounts, secret mounts, multi-arch build (manifest list)
```

แต่ละ sub-lab มี:
- `README.md` — อธิบาย concept + ขั้นตอน hands-on
- ไฟล์ runnable (Dockerfile, compose.yaml, scripts)
- Cleanup instructions

---

## เริ่มต้น

### Prerequisites

- Linux host (ทดสอบบน Ubuntu 24.04 / Mint 22.3) — Mac / WSL2 ใช้ได้แต่บางส่วน (host network, swarm) จะแตกต่าง
- Docker CE 24+ พร้อม Compose v2 และ Buildx

ถ้ายังไม่มี Docker:
```bash
bash 00-setup/install-docker.sh
```

ตรวจสอบ:
```bash
docker version
docker buildx version
docker compose version
```

### Lab แรก

```bash
cd 01-basics/01-container-lifecycle
cat README.md   # อ่าน 11 steps แล้วทำตามทีละขั้น
```

### Module ที่แนะนำให้เริ่ม

ทำตามลำดับเลขใน folder name — แต่ละ module อ้างอิงสิ่งที่เรียนจาก module ก่อนหน้า

---

## ⚠️ Setup ก่อนรัน lab ที่ใช้ secrets

ไฟล์ secret บางตัว **ไม่ได้อยู่ใน repo** (ถูก `.gitignore` กัน) — ต้อง setup ก่อนรัน lab ที่ใช้:

| Lab | ไฟล์ที่ต้อง setup | วิธี |
|-----|------------------|------|
| `04-compose/04-secrets/` | `secrets/db_password.txt` | `cp secrets/db_password.txt.example secrets/db_password.txt` |
| `03-volumes/05-backup-restore/` | `secrets/db_password.txt` | `cp secrets/db_password.txt.example secrets/db_password.txt` |
| `11-buildkit/02-secret-mounts/` | `app/token.txt` | `cp app/token.txt.example app/token.txt` |
| `07-registry/02-auth/` | `auth/htpasswd` | รัน Step 1 ใน README (gen ด้วย `htpasswd`) |
| `07-registry/03-tls/` | `certs/registry.{key,crt}` | รัน Step 1 ใน README (gen ด้วย openssl) |

---

## หลักการของ Lab นี้

- **ทุก concept ต้องมี lab จริง** — ไม่ใช่แค่อ่าน
- **อธิบาย "ทำไม" ก่อน "อย่างไร"**
- **Alpine/slim image เสมอ** เพื่อลด size
- **ไม่ใช้ `latest` tag** ในตัวอย่างที่ต้องการ reproducibility
- **ทุก Dockerfile ต้อง build ได้จริง** — ทดสอบก่อน commit
- **Anti-pattern → แก้เป็น correct pattern เสมอ** (เช่น lab `02-secret-mounts/` แสดง bad vs good 3 แบบ)

ดูรายละเอียดเต็มใน [`CLAUDE.md`](./CLAUDE.md)

---

## เคลียระบบระหว่างทำ lab

ถ้ามี container/network/volume ค้างจาก lab ก่อนหน้า:
```bash
bash cleanup.sh
```

⚠️ ลบ container, dangling networks, unused volumes ของระบบทั้งหมด — ถ้ามี container อื่นที่ไม่เกี่ยวข้องที่อยากเก็บ ให้ระวัง

---

## สถานะปัจจุบัน

11 modules + 00-setup, 46 sub-labs ✅ ครบหมด

ดู [`STATUS.md`](./STATUS.md) สำหรับรายละเอียดแต่ละ module ที่ทดสอบไปแล้ว
