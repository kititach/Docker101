# Lab 01: GitHub Actions for Docker

เป้าหมาย: สร้าง Automated Pipeline บน GitHub Actions เพื่อ Build, Scan, และ Push Docker Image ไปยัง Docker Hub ทุกครั้งที่มีการ Push Code

## 📁 โครงสร้างโฟลเดอร์ (mini-repo)

โฟลเดอร์นี้ถูกออกแบบให้เป็น **ตัวอย่าง repo เล็กๆ** ที่ copy ไปวางที่ root ของ GitHub repo จริงได้ทันที:

```
01-github-actions/
├── .github/workflows/docker-build.yml   # pipeline definition
├── app/
│   ├── Dockerfile                       # python:3.12-alpine + non-root + HEALTHCHECK
│   └── server.py                        # HTTP server มี /health endpoint
└── README.md
```

## สิ่งที่ Pipeline นี้ทำ (ตาม CLAUDE.md)

1. **Checkout code** — `actions/checkout@v4`
2. **Setup QEMU + Buildx** — เตรียม emulator สำหรับ multi-arch
3. **Login to Docker Hub** — skip บน PR (ไม่ leak creds)
4. **Extract metadata** — gen tag จาก git ref (`main`, `pr-123`, `sha-abc1234`, `v1.2.3`) — **ไม่ใช้ `latest`**
5. **Build single-arch + scan ด้วย Trivy** — ถ้าเจอ HIGH/CRITICAL ที่ fix ได้ pipeline fail
6. **Upload SARIF report** — ขึ้น GitHub Security tab
7. **Build multi-arch (`linux/amd64,linux/arm64`) + push** — skip push บน PR

## สิ่งที่ต้องเตรียม

1. บัญชี [Docker Hub](https://hub.docker.com/)
2. Repository บน GitHub

## ขั้นตอนการตั้งค่า

### 1. ตั้งค่า Secrets ใน GitHub
- ไปที่ repo บน GitHub → **Settings** → **Secrets and variables** → **Actions**
- เพิ่ม 2 secrets:
  - `DOCKERHUB_USERNAME` — ชื่อผู้ใช้ Docker Hub
  - `DOCKERHUB_TOKEN` — [Access Token](https://hub.docker.com/settings/security) (อย่าใช้ password ตรงๆ)

### 2. Copy ไฟล์ขึ้น repo
Copy ทั้งโฟลเดอร์นี้ (`.github/`, `app/`) ไปวางที่ root ของ repo แล้ว push

### 3. ดูผลลัพธ์
แท็บ **Actions** บน GitHub → ดู workflow run
- ถ้า Trivy เจอช่องโหว่ HIGH/CRITICAL → step "Scan image with Trivy" จะ fail
- ผลการ scan โผล่ที่แท็บ **Security** → **Code scanning**

## ทดสอบ Build ที่เครื่องตัวเองก่อน push

```bash
cd app
docker build -t my-app:test .
docker run --rm -d -p 8080:8080 --name my-app my-app:test
curl http://localhost:8080/
curl http://localhost:8080/health
docker rm -f my-app
```

## 🧹 Cleanup
```bash
docker rmi my-app:test
```
