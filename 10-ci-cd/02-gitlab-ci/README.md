# Lab 02: GitLab CI/CD for Docker

เป้าหมาย: สร้าง Automated Pipeline บน GitLab เพื่อ Build, Scan, และ Push Docker Image ไปยัง GitLab Container Registry

GitLab มี Container Registry ฟรีในตัว ทำให้สะดวกกว่า GitHub Actions ที่ต้องพึ่งพา Docker Hub

## 📁 โครงสร้างโฟลเดอร์ (mini-repo)

```
02-gitlab-ci/
├── .gitlab-ci.yml      # pipeline definition (3 stages: build → scan → push)
├── app/
│   ├── Dockerfile      # python:3.12-alpine + non-root + HEALTHCHECK
│   └── server.py       # HTTP server มี /health endpoint
└── README.md
```

---

## 🤔 ทำไม GitLab ยังใช้ DinD แทน DooD?

ใน Lab `00-dind-dood/` เราสรุปไว้ว่า **DooD ปลอดภัยกว่า DinD** แต่ทำไม GitLab shared runners ถึงเลือกใช้ DinD?

**คำตอบ: เพราะ isolation**

- **Shared runner** ต้องรัน job ของลูกค้าคนละคนสลับกันบนเครื่องเดียวกัน
- ถ้าใช้ **DooD** (mount `/var/run/docker.sock` จาก host) — job หนึ่งจะมองเห็น/แก้ไข/ลบ container ของ job อื่นได้ทั้งหมด → security disaster
- **DinD** สร้าง Docker daemon ใหม่ทุก job ในรูป ephemeral service container → job แต่ละตัวมี daemon ของตัวเอง ไม่เห็นกัน

**สรุป trade-off:**
| | DinD | DooD |
|---|------|------|
| Isolation ระหว่าง job | ✅ ดี | ❌ แย่ (เห็นกันหมด) |
| Performance | ❌ ช้ากว่า | ✅ เร็ว |
| ต้อง `--privileged` | ✅ ใช่ | ❌ ไม่ |
| เหมาะกับ | **shared runner** (GitLab.com) | self-hosted runner ของทีมเดียว |

ในไฟล์ `.gitlab-ci.yml` คุณจะเห็น:
```yaml
services:
  - docker:27.3-dind   # ← นี่คือ DinD service container
```

---

## สิ่งที่ Pipeline นี้ทำ

| Stage | ทำอะไร |
|-------|--------|
| `build` | Build amd64 image แล้ว push ขึ้น registry (tag = short SHA) |
| `scan` | Trivy scan image — ถ้าเจอ HIGH/CRITICAL ที่ fix ได้ → pipeline fail |
| `push` | Build multi-arch (`linux/amd64,linux/arm64`) + tag ด้วย branch slug — ทำเฉพาะ default branch |

### Pre-defined variables ที่ใช้
- `$CI_REGISTRY` — URL ของ GitLab Registry
- `$CI_REGISTRY_USER` / `$CI_REGISTRY_PASSWORD` — token ชั่วคราว GitLab สร้างให้ ไม่ต้องเซ็ต secret เอง
- `$CI_REGISTRY_IMAGE` — `registry.gitlab.com/group/project`
- `$CI_COMMIT_SHORT_SHA` — short hash 8 ตัว → ใช้แทน `latest`
- `$CI_COMMIT_REF_SLUG` — branch name แบบ slug-friendly

---

## ขั้นตอน

### 1. Push โฟลเดอร์ขึ้น GitLab repo
Copy ทั้งโฟลเดอร์นี้ไปวางที่ root ของ repo บน GitLab แล้ว push

### 2. ดูผลลัพธ์
**Build > Pipelines** บน GitLab → ดู 3 stages ทำงานทีละขั้น

### 3. ดู image ใน Registry
**Deploy > Container Registry**

---

## ทดสอบ Build ที่เครื่องตัวเองก่อน push

```bash
cd app
docker build -t my-app:test .
docker run --rm -d -p 8080:8080 --name my-app my-app:test
curl http://localhost:8080/
docker rm -f my-app
```

## 🧹 Cleanup
```bash
docker rmi my-app:test
```
