# Lab 02 — Basic Authentication (htpasswd)

> ⚠️ **ไฟล์ `auth/htpasswd` ไม่ได้อยู่ใน repo** (อยู่ใน `.gitignore`) — รัน **Step 1** เพื่อ generate ก่อนเริ่ม lab

## Objective

เพิ่ม username/password ให้ registry — ใครก็ pull/push ไม่ได้ถ้าไม่ login

---

## Files

```
02-auth/
├── compose.yaml
├── auth/
│   └── htpasswd     — bcrypt-hashed credentials
└── README.md
```

---

## Step 1 — สร้าง htpasswd

ใช้ `httpd:alpine` image (มี `htpasswd` tool):

```bash
mkdir -p auth
docker run --rm --entrypoint htpasswd httpd:2.4-alpine \
  -Bbn admin admin123 > auth/htpasswd

cat auth/htpasswd
# admin:$2y$05$... ← bcrypt hash
```

- `-B` = bcrypt (registry รองรับเฉพาะ bcrypt)
- `-b` = batch mode (อ่าน password จาก argv)
- `-n` = พิมพ์ออก stdout ไม่เขียนไฟล์

> **Production:** ใช้ password ยาว + random ไม่ใช่ `admin123`

---

## Step 2 — Deploy Registry พร้อม Auth

```yaml
# compose.yaml
services:
  registry:
    image: registry:2
    ports: ["5000:5000"]
    volumes:
      - registry-data:/var/lib/registry
      - ./auth:/auth:ro
    environment:
      REGISTRY_AUTH: "htpasswd"
      REGISTRY_AUTH_HTPASSWD_REALM: "Registry Realm"
      REGISTRY_AUTH_HTPASSWD_PATH: "/auth/htpasswd"
```

```bash
docker compose up -d
```

---

## Step 3 — Push โดยไม่ Login (ต้อง Fail)

```bash
docker tag alpine:3.20 localhost:5000/secured:1.0
docker push localhost:5000/secured:1.0
```

ผลที่ได้:
```
push access denied, repository does not exist or may require authorization:
authorization failed: no basic auth credentials
```

---

## Step 4 — docker login

```bash
echo "admin123" | docker login localhost:5000 -u admin --password-stdin
# Login Succeeded
```

credentials ถูกเก็บที่ `~/.docker/config.json`:
```bash
cat ~/.docker/config.json | python3 -m json.tool
# {
#   "auths": {
#     "localhost:5000": { "auth": "YWRtaW46YWRtaW4xMjM=" }   ← base64
#   }
# }
```

> **ระวัง:** `~/.docker/config.json` เก็บ credential แบบ plaintext base64  
> Production ให้ใช้ credential helper: `docker-credential-secretservice` (Linux), `osxkeychain` (Mac)

---

## Step 5 — Push หลัง Login (สำเร็จ)

```bash
docker push localhost:5000/secured:1.0
# จะผ่านแล้ว
```

---

## Step 6 — Registry API ด้วย Auth

```bash
# ไม่ใส่ credentials
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:5000/v2/_catalog
# HTTP 401

# ใส่ basic auth
curl -s -u admin:admin123 http://localhost:5000/v2/_catalog
# {"repositories":["secured"]}

# Bearer token (ไม่ใช้ในแบบ htpasswd — สำหรับ token server)
```

---

## Step 7 — Logout

```bash
docker logout localhost:5000
# Removing login credentials for localhost:5000

# push หลัง logout → fail อีกครั้ง
docker push localhost:5000/secured:1.0
# authorization failed
```

---

## Step 8 — Add Users เพิ่ม

```bash
# เพิ่ม user ใหม่ — ใช้ -bn (no header) แล้ว append
docker run --rm --entrypoint htpasswd httpd:2.4-alpine \
  -Bbn alice alicepass >> auth/htpasswd

cat auth/htpasswd
# admin:$2y$05$...
# alice:$2y$05$...

# restart registry เพื่อ reload (registry cache ไฟล์ตอน start)
docker compose restart
```

---

## Cleanup

```bash
docker compose down -v
docker logout localhost:5000 2>/dev/null
rm -f auth/htpasswd
docker rmi localhost:5000/secured:1.0 2>/dev/null
```

---

## ข้อจำกัดของ htpasswd

- ✓ ง่าย, ไม่ต้อง external service
- ✗ user management ผ่านไฟล์ — ไม่ scale
- ✗ ไม่มี granular permission (push/pull แยก, repo-level)
- ✗ ไม่ support SSO, MFA

**สำหรับ production:** ใช้ token-based auth server (Harbor, Quay) หรือ external auth (LDAP, OIDC)

---

## ขั้นถัดไป

Registry นี้ยังคุยผ่าน HTTP — password ส่งแบบ base64 clear-text ใน network  
→ Lab 03 เพิ่ม TLS
