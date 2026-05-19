# Lab 04 — Image CVE Scanning

## Objective

ตรวจสอบ vulnerabilities (CVE) ใน image ก่อน push ขึ้น production — หลีกเลี่ยง base image ที่ EOL หรือมีช่องโหว่ที่ถูก fix ไปแล้ว

---

## ผลวัดจริง

| Image | CVE Total | HIGH | CRITICAL |
|-------|-----------|------|----------|
| `node:14` (EOL since 2023) | **572** | 551 | 21 |
| `node:20-alpine` (current) | **11** | 11 | 0 |

แค่เปลี่ยน base image → ลดช่องโหว่ลง **>98%**

---

## Step 1 — Scan ด้วย Trivy (ผ่าน Container)

ไม่ต้อง install บน host — รัน trivy เป็น container:

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image alpine:3.20
```

หรือ filter เฉพาะ severity สูง:
```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --severity CRITICAL,HIGH alpine:3.20
```

---

## Step 2 — เปรียบเทียบ Old vs Current Image

```bash
# old image — node:14 (EOL)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --severity CRITICAL,HIGH node:14 | tail -5

# Output:
# Total: 572 (HIGH: 551, CRITICAL: 21)
```

```bash
# current image
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --severity CRITICAL,HIGH node:20-alpine | tail -5

# Output:
# Total: 11 (HIGH: 11, CRITICAL: 0)
```

---

## Step 3 — Scan Image ที่ Build เอง

```bash
# build image
cd ../../05-multi-stage/02-python
docker build -t ms-python:final .

# scan
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image ms-python:final
```

---

## Step 4 — Trivy Output Formats

```bash
# JSON สำหรับ CI/CD
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --format json alpine:3.20 > scan.json

# SARIF (ใช้กับ GitHub code scanning)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --format sarif --output report.sarif alpine:3.20

# fail build ถ้ามี CRITICAL CVE
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --severity CRITICAL --exit-code 1 alpine:3.20
echo "Exit code: $?"
# 0 = clean, 1 = found CVE → ใช้กับ CI pipeline
```

---

## Step 5 — Ignore Known/Unfixable CVE

ถ้ามี CVE ที่ยังไม่มี fix หรือไม่กระทบ app ของคุณ:

```bash
# สร้าง .trivyignore
cat > .trivyignore << 'EOF'
CVE-2023-XXXXX
CVE-2024-XXXXX
EOF

docker run --rm -v $(pwd):/workspace -w /workspace \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --ignorefile /workspace/.trivyignore alpine:3.20
```

---

## Step 6 — Scan Filesystem (Dockerfile/source)

trivy scan ได้มากกว่า image — รวมถึง source code dependencies:

```bash
# scan requirements.txt / package.json / go.mod
docker run --rm -v $(pwd):/src \
  aquasec/trivy:latest fs /src

# scan Dockerfile หา misconfiguration
docker run --rm -v $(pwd):/src \
  aquasec/trivy:latest config /src
```

---

## Step 7 — เครื่องมือทางเลือก

| Tool | จุดเด่น |
|------|---------|
| `trivy` (Aqua Security) | Open source, รวดเร็ว, scan ได้หลายอย่าง |
| `docker scout` | Built-in Docker (`docker scout cves myimage`) |
| `grype` (Anchore) | Open source, integrate กับ Syft (SBOM) |
| `snyk container test` | Commercial, deep dependency scan |
| `clair` (Red Hat) | Server-based, registry integration |

---

## Step 8 — Integrate กับ CI/CD

GitHub Actions:
```yaml
- name: Scan image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'myapp:${{ github.sha }}'
    severity: 'CRITICAL,HIGH'
    exit-code: '1'    # fail build on findings
```

GitLab CI:
```yaml
scan:
  image: aquasec/trivy:latest
  script:
    - trivy image --exit-code 1 --severity CRITICAL myapp:$CI_COMMIT_SHA
```

---

## CVE Scanning Checklist

```
□ scan ทุก image ก่อน push ขึ้น registry
□ ใช้ base image รุ่นล่าสุด — patch CVE ฟรี
□ ใช้ alpine/slim variant — packages น้อย → CVE น้อย
□ avoid EOL image (node:14, python:3.8, etc.)
□ rebuild image เป็นประจำเพื่อรับ base image update
□ block CI/CD ถ้ามี CRITICAL CVE
□ track ignored CVE — review เป็นระยะ
```
