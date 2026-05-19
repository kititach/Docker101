# STATUS — Docker Learning Lab
> **อ่านไฟล์นี้ก่อนทุกครั้งที่เข้ามาทำงาน**  
> อัปเดตท้ายไฟล์ทุกครั้งที่เรียน/ทำ lab เสร็จ — ไม่ว่าจะสำเร็จหรือพัง

---

## 🟢 สถานะล่าสุด — 2026-05-19 (audit ทั้ง repo + sync STATUS.md กับ filesystem จริง)

### ความคืบหน้าโดยรวม
```
01-basics         ✅ เสร็จแล้ว (5/5 labs)
02-networking     ✅ เสร็จแล้ว (5/5 labs)
03-volumes        ✅ เสร็จแล้ว (5/5 labs)
04-compose        ✅ เสร็จแล้ว (5/5 labs)
05-multi-stage    ✅ เสร็จแล้ว (3/3 labs)
06-security       ✅ เสร็จแล้ว (5/5 labs)
07-registry       ✅ เสร็จแล้ว (4/4 labs)
08-swarm          ✅ เสร็จแล้ว (4/4 labs)
09-monitoring     ✅ เสร็จแล้ว (4/4 labs)
10-ci-cd          ✅ เสร็จแล้ว (3/3 labs) — มี Dockerfile+app จริง, scan, multi-arch
11-buildkit       ✅ เสร็จแล้ว (3/3 labs) — cache mounts, secret mounts, multi-arch build
```

### Lab inventory ต่อ module (sync กับ filesystem จริง 2026-05-19)

| Module | Sub-labs | Highlight ที่ทดสอบแล้ว |
|--------|----------|-----------------------|
| 00-setup | `install-docker.sh` | Docker 29.5.0, Compose v5.1.3, Buildx v0.34.0 (Ubuntu 24.04 / Mint 22.3) |
| 01-basics | container-lifecycle, image-management, dockerfile, layer-caching, image-optimization | 1.63 GB → 86 MB optimization; layer-caching มี `Dockerfile.cachemount` เป็น teaser ของ module 11 |
| 02-networking | bridge, custom-network, host-none, port-mapping, multi-container | nginx → backend ผ่าน custom DNS, ทดสอบ host/none isolation |
| 03-volumes | named-volume, bind-mount, tmpfs, volume-drivers, backup-restore | pg_dump/restore atomic flow + Docker secret |
| 04-compose | basics, depends-healthcheck, profiles, secrets, override | `compose.broken.yaml` สาธิต race; `compose.override.yaml` + `compose.prod.yaml` |
| 05-multi-stage | go, python, nodejs | scratch base + statically-linked binary patterns |
| 06-security | non-root, capabilities, readonly-rootfs, image-scanning, runtime-hardening | seccomp + cap-drop ใน `05-runtime-hardening/compose.yaml` |
| 07-registry | basics, auth, tls, maintenance | htpasswd auth + TLS certs ใน `03-tls/certs/` |
| 08-swarm | init-service, stacks, rolling-update, secrets-configs | rolling-update parallelism + Swarm secrets |
| 09-monitoring | logging-drivers, log-aggregation, resource-limits, monitoring-stack | Loki + Promtail + Grafana; Prometheus + cAdvisor + Grafana |
| 10-ci-cd | dind-dood, github-actions, gitlab-ci | DooD: container เห็น host containers; CI: trivy scan + multi-arch |
| 11-buildkit | cache-mounts, secret-mounts, multi-arch | leak detection ทั้ง history + ทุก layer; amd64+arm64 manifest verified |

**รวม: 11 modules + 00-setup, 46 sub-labs ทุกตัวมี `README.md` + ไฟล์ตามขั้นตอน**

---

## 🗺️ แผนการเรียน

### ✅ เสร็จแล้ว
| งาน | วันที่ |
|-----|--------|
| สร้าง CLAUDE.md + STATUS.md | 2026-05-17 |
| Lab 01-basics/01-container-lifecycle | 2026-05-17 |
| ติดตั้ง Docker CE 29.5.0 + เขียนคู่มือ 00-setup/ | 2026-05-18 |
| Lab 01-basics/02-image-management | 2026-05-19 |
| Lab 01-basics/03-dockerfile | 2026-05-19 |
| Lab 01-basics/04-layer-caching | 2026-05-19 |
| Lab 01-basics/05-image-optimization | 2026-05-19 |
| Module 02-networking (5 labs) | 2026-05-19 |
| Module 03-volumes (5 labs) | 2026-05-19 |
| Module 04-compose (5 labs) | 2026-05-19 |
| Module 05-multi-stage (3 labs) | 2026-05-19 |
| Module 06-security (5 labs) | 2026-05-19 |
| Module 07-registry (4 labs) | 2026-05-19 |
| Module 08-swarm (4 labs) | 2026-05-19 |
| Module 09-monitoring (4 labs) | 2026-05-19 |
| Lab 03-volumes/05-backup-restore (contribution คนอื่น) | 2026-05-19 |
| Module 10-ci-cd scaffold (contribution คนอื่น — 3 subfolders) | 2026-05-19 |
| ปรับ 03-volumes/05-backup-restore เข้าแนวทาง (5 จุด) + ทดสอบ end-to-end | 2026-05-19 |
| ปรับ 10-ci-cd ทั้ง 3 sub-labs เข้าแนวทาง (7 จุด) + เพิ่ม Dockerfile/app | 2026-05-19 |
| Module 11-buildkit (3 labs: cache-mounts, secret-mounts, multi-arch) | 2026-05-19 |
| Audit ทั้ง repo + sync STATUS.md กับ filesystem จริง | 2026-05-19 |
| Pre-commit security review + `.gitignore` + .example files | 2026-05-19 |

---

### 📋 Backlog — เรียงตามลำดับแนะนำ

#### Phase 1 — Basics
- [x] **Container lifecycle** — run, stop, rm, inspect, logs, exec
- [x] **Image management** — pull, build, tag, push, history, rmi
- [x] **Dockerfile fundamentals** — FROM, RUN, COPY, CMD, ENTRYPOINT, ENV
- [x] **Layer caching** — ทดสอบ cache hit/miss จากการเรียงคำสั่ง
- [x] **Image optimization** — เปรียบเทียบ size ก่อน/หลัง optimize

#### Phase 2 — Networking
- [x] **bridge network** — container-to-container communication
- [x] **custom network + DNS** — ชื่อแทน IP
- [x] **host network** — ทดสอบบน Linux
- [x] **none network** — isolated container
- [x] **port mapping** — publish, bind interface

#### Phase 3 — Volumes
- [x] **named volume** — create, inspect, backup, restore
- [x] **bind mount** — dev workflow, hot-reload
- [x] **tmpfs** — in-memory, sensitive data
- [x] **volume drivers** — NFS, local driver options
- [x] **backup & restore** — pg_dump with docker exec (Real-world use case)

#### Phase 4 — Compose
- [x] **compose basics** — services, ports, environment
- [x] **depends_on + healthcheck** — startup order
- [x] **profiles** — dev vs prod config
- [x] **secrets** — file-based secrets
- [x] **override files** — compose.override.yaml

#### Phase 5 — Advanced
- [x] **multi-stage builds** — Go / Python / Node.js examples
- [x] **BuildKit + buildx** — cache mounts, secret mounts, multi-arch (ดู `11-buildkit/`)
- [x] **security hardening** — non-root, capabilities, read-only fs, seccomp
- [x] **private registry** — deploy, push, pull, API
- [x] **Swarm basics** — init, stack deploy, scale, rolling update

#### Phase 6 — Operations
- [x] **resource limits** — CPU, memory, pids
- [x] **logging** — drivers, rotation, aggregation
- [x] **monitoring** — cAdvisor + Prometheus + Grafana stack
- [x] **Docker-in-Docker / DooD** — `/var/run/docker.sock`
- [x] **CI/CD integration** — GitHub Actions / GitLab CI pipeline

---

## ⚠️ Known Issues & Gotchas

- ✅ ไม่มีงานค้าง — backlog ทุก Phase ติ๊กครบ, ทุก contribution ปรับเข้าแนวทางแล้ว
- หากเปิด lab ที่ build ผ่าน BuildKit-only features (cache mount, secret mount) ต้องมีบรรทัด `# syntax=docker/dockerfile:1.7` ที่บรรทัดแรกของ Dockerfile — มิฉะนั้น `--mount=type=...` ไม่ทำงาน (ดู `11-buildkit/README.md`)
- Multi-arch build ต้อง create builder ด้วย `--driver docker-container` ก่อน (default `docker` driver build multi-arch ไม่ได้) + ติดตั้ง QEMU binfmt บน host หาก run image ของ arch ต่าง

### 🔒 Secret files (ต้อง setup ก่อนรัน lab — ไม่อยู่ใน repo)

`.gitignore` กัน secret files ออกจาก git แล้ว — ก่อนรัน lab ต่อไปนี้ต้อง setup secret ก่อน:

| Lab | ไฟล์ | วิธี setup |
|-----|------|----------|
| `04-compose/04-secrets/` | `secrets/db_password.txt` | `cp .example → ตัวจริง` (ดู Step 0 ใน README) |
| `03-volumes/05-backup-restore/` | `secrets/db_password.txt` | `cp .example → ตัวจริง` (ดู Step 0) |
| `11-buildkit/02-secret-mounts/` | `app/token.txt` | `cp .example → ตัวจริง` |
| `07-registry/02-auth/` | `auth/htpasswd` | รัน Step 1 ใน README (`docker run httpd ... htpasswd ...`) |
| `07-registry/03-tls/` | `certs/registry.{key,crt}` | รัน Step 1 ใน README (`docker run alpine/openssl req -x509 ...`) |

---

## 📋 Key File Locations

### Top-level
| ไฟล์ | หน้าที่ |
|------|--------|
| `CLAUDE.md` | reference ครบทุก concept + best practices (อ่านก่อนเริ่ม) |
| `STATUS.md` | ไฟล์นี้ — progress tracking |
| `cleanup.sh` | ลบ containers/networks/volumes/dangling images ก่อนเริ่ม lab ใหม่ |
| `00-setup/install-docker.sh` | install Docker CE บน Ubuntu 24.04 / Mint 22.3 |

### Highlight ที่อาจต้องอ้างอิงบ่อย
| Path | จุดสำคัญ |
|------|---------|
| `01-basics/04-layer-caching/good/Dockerfile.cachemount` | teaser ของ BuildKit cache mount — โยงไป `11-buildkit/01-cache-mounts/` |
| `03-volumes/05-backup-restore/` | pg_dump/restore lab (compose v2 + Docker secret + healthcheck + atomic restore ด้วย `ON_ERROR_STOP=1 --single-transaction`) |
| `04-compose/05-override/` | สาธิต `compose.override.yaml` + `compose.prod.yaml` วิธี merge |
| `06-security/05-runtime-hardening/compose.yaml` | seccomp + cap-drop + read-only fs ใช้พร้อมกันเป็น reference template |
| `10-ci-cd/00-dind-dood/` | DooD hands-on (`docker:27.3-cli` pinned) |
| `10-ci-cd/01-github-actions/` | mini-repo: `.github/workflows/docker-build.yml` + `app/Dockerfile` + Trivy + multi-arch + metadata-action |
| `10-ci-cd/02-gitlab-ci/` | mini-repo: `.gitlab-ci.yml` 3 stages (build→scan→push) + DinD-vs-DooD ตารางอธิบาย |
| `11-buildkit/01-cache-mounts/run-comparison.sh` | benchmark cold/warm สำหรับ cache mount |
| `11-buildkit/02-secret-mounts/inspect-leaks.sh` | ตรวจ secret leak ทั้ง `docker history` + แกะ tar ทุก layer |
| `11-buildkit/03-multi-arch/run-multiarch.sh` | end-to-end multi-arch (registry + binfmt + buildx + manifest inspect + run arm64) |

---

## 📜 ประวัติการแก้ไข

### 2026-05-17 — เริ่มต้นโปรเจกต์ + Lab 01
- สร้าง `CLAUDE.md` — reference guide ครบทุก Docker concept
- สร้าง `STATUS.md` — progress tracking
- สร้าง `01-basics/01-container-lifecycle/` — lab พร้อม app จริง (Python HTTP server)
  - `app/server.py` — HTTP server แสดง uptime, pid, SIGTERM handler
  - `app/Dockerfile` — python:3.12-alpine + HEALTHCHECK
  - `README.md` — 11 steps ครอบคลุม run, logs, inspect, stats, exec, pause, stop/kill, diff, cleanup
  - ทดสอบ build + run จริงแล้ว ✅
