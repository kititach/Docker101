# Lab 02: Secret Mounts

เป้าหมาย: เข้าใจว่าทำไม `ARG` และ `COPY` ไม่เหมาะกับการส่ง secret เข้า build, แล้ว `--mount=type=secret` แก้ปัญหานี้อย่างไร

---

## ปัญหา: secret ตอน build (ไม่ใช่ตอน run)

บ่อยครั้งเราต้องใช้ secret **ตอน build image** เช่น:
- npm token / pip extra-index-url สำหรับ private package
- SSH key clone private repo
- API token ดาวน์โหลด artifact

3 วิธีที่ developer มักทำ มี 2 วิธีพังเงียบๆ:

| วิธี | Token หลุดที่ไหน? |
|------|-------------------|
| ❌ `ARG TOKEN` + `--build-arg` | โผล่ใน `docker history --no-trunc` |
| ❌ `COPY token.txt` แล้ว `rm` | ติดอยู่ใน layer COPY ถาวร |
| ✅ `--mount=type=secret` | ไม่หลุดที่ไหนเลย |

---

## โครงสร้าง Lab

```
02-secret-mounts/
├── app/
│   ├── Dockerfile.bad-arg     # ❌ ใช้ ARG GITHUB_TOKEN
│   ├── Dockerfile.bad-copy    # ❌ COPY token.txt → rm
│   ├── Dockerfile.good        # ✅ --mount=type=secret
│   └── token.txt              # fake token สำหรับทดสอบ
├── inspect-leaks.sh           # build ทั้ง 3 + ตรวจ leak
└── README.md
```

---

## Setup (ครั้งแรกเท่านั้น)

ไฟล์ `app/token.txt` **ไม่ได้อยู่ใน repo** (อยู่ใน `.gitignore`) — copy จาก `.example`:

```bash
cp app/token.txt.example app/token.txt
```

> `token.txt.example` เป็น fake token (`ghp_FAKE_TOKEN_FOR_LAB_ONLY_*`) — lab นี้ไม่ใช้คุยกับ GitHub จริง

---

## ทดลอง

```bash
bash inspect-leaks.sh
```

Script จะ:
1. Build ทั้ง 3 Dockerfile
2. ตรวจ `docker history --no-trunc` — หา token ใน command/buildarg
3. **Extract image จริง** (`docker save` → แกะ layer tar.gz) แล้ว grep หา token ในไฟล์ทุก layer

### ผลที่คาดหวัง

```
[bad-arg]
❌ LEAK: เจอ token ใน history
✅ ไม่เจอใน layers

[bad-copy]
✅ ไม่เจอใน history
❌ LEAK: เจอ token ในไฟล์ tmp/token.txt ของ layer COPY

[good]
✅ ไม่เจอใน history
✅ ไม่เจอใน layers
```

---

## ทำไม `rm /tmp/token.txt` ไม่ช่วย?

```dockerfile
COPY token.txt /tmp/token.txt        ← layer 1: มีไฟล์ token.txt
RUN curl ... && rm /tmp/token.txt    ← layer 2: เพิ่ม whiteout marker (.wh.token.txt)
```

**Overlay filesystem** ของ Docker ใช้วิธี "ซ้อนทับ" — layer 2 ไม่ได้ลบไฟล์ใน layer 1 จริง แต่เพิ่ม **whiteout marker** บอกว่า "ตำแหน่งนี้ถูกลบ" เมื่อ container ทำงาน user เห็นว่าไม่มีไฟล์ แต่ถ้าเอา image ไป `docker save` แล้วแกะ tar — **layer 1 ยังอยู่ครบ พร้อม token**

หลักฐานที่ script เจอ:
```
LEAK: เจอ token ใน layer 8b5e628d...
  ไฟล์ที่มี token: tmp/token.txt
```

---

## วิธีใช้ secret mount

### 1. ใน Dockerfile
```dockerfile
# syntax=docker/dockerfile:1.7
RUN --mount=type=secret,id=github_token \
    TOKEN=$(cat /run/secrets/github_token) && \
    curl -H "Authorization: token $TOKEN" https://api.github.com/zen
```

- `id=github_token` — ชื่อ secret (ใช้ตอน build เลือก)
- ไฟล์ mount อยู่ที่ `/run/secrets/<id>` (default — เปลี่ยนได้ด้วย `target=`)
- Mount เป็น **tmpfs** เฉพาะตอน RUN นี้ทำงาน หลังจากนั้นหายไป
- **ไม่ติด layer ใดๆ**

### 2. ตอน build
```bash
docker build --secret id=github_token,src=$HOME/.github_token .
```

หรือส่งจาก env:
```bash
GITHUB_TOKEN=xxx docker build --secret id=github_token,env=GITHUB_TOKEN .
```

### 3. ใน CI/CD
GitHub Actions:
```yaml
- uses: docker/build-push-action@v6
  with:
    secrets: |
      "github_token=${{ secrets.PRIVATE_PACKAGE_TOKEN }}"
```

---

## ⚠️ ข้อระวัง

- Secret mount **ป้องกัน leak จาก image** เท่านั้น ไม่ป้องกัน build process เขียน token ลงไฟล์ใน layer เอง (อย่าทำ `cat $TOKEN > /etc/some-file`)
- ระวัง output ของคำสั่งที่ใช้ token (เช่น `npm install --verbose`) อาจ print token ลง log → CI log หลุด
- BuildKit สามารถ `--mount=type=ssh` สำหรับ SSH agent forwarding ได้ด้วย (สำหรับ `git clone private-repo`)

---

## 🧹 Cleanup
```bash
docker rmi lab-secret-bad-arg:test lab-secret-bad-copy:test lab-secret-good:test
```
