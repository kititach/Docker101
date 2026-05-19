# Lab 03 — TLS / HTTPS

> ⚠️ **ไฟล์ `certs/registry.key` และ `registry.crt` ไม่ได้อยู่ใน repo** (อยู่ใน `.gitignore` — private key ห้าม commit) — รัน **Step 1** เพื่อ generate ก่อนเริ่ม lab

## Objective

เข้ารหัสการสื่อสารระหว่าง Docker client กับ registry — credentials และ image data ไม่รั่วบน network

---

## Files

```
03-tls/
├── compose.yaml
├── certs/
│   ├── registry.crt    — self-signed cert
│   └── registry.key
└── README.md
```

---

## Step 1 — Generate Self-Signed Certificate

```bash
mkdir -p certs
docker run --rm -v $(pwd)/certs:/certs alpine/openssl \
  req -x509 -newkey rsa:4096 -days 365 -nodes \
  -keyout /certs/registry.key -out /certs/registry.crt \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
```

ตรวจสอบ:
```bash
echo | openssl s_client -connect localhost:5443 -servername localhost 2>/dev/null | \
  openssl x509 -noout -subject -dates -ext subjectAltName
# subject=CN = localhost
# notBefore=...
# notAfter=...
# X509v3 Subject Alternative Name: DNS:localhost, IP Address:127.0.0.1
```

> **SAN สำคัญมาก:** modern Docker/Go client ไม่ accept cert ที่ไม่มี SAN  
> เพิ่ม `subjectAltName` เสมอเมื่อสร้าง cert

---

## Step 2 — Deploy Registry พร้อม TLS

```yaml
# compose.yaml
services:
  registry:
    image: registry:2
    ports: ["5443:443"]
    volumes:
      - registry-data:/var/lib/registry
      - ./certs:/certs:ro
    environment:
      REGISTRY_HTTP_ADDR: "0.0.0.0:443"
      REGISTRY_HTTP_TLS_CERTIFICATE: "/certs/registry.crt"
      REGISTRY_HTTP_TLS_KEY: "/certs/registry.key"
```

```bash
docker compose up -d
```

ทดสอบด้วย curl:
```bash
# -k = skip cert verify (เพราะ self-signed)
curl -ksI https://localhost:5443/v2/ | head -3
# HTTP/2 200
# content-type: application/json; charset=utf-8
# docker-distribution-api-version: registry/2.0
```

---

## Step 3 — ⚠️ Docker Daemon และ localhost

```bash
docker info | grep -A2 "Insecure Reg"
# Insecure Registries:
#   ::1/128
#   127.0.0.0/8
```

**Docker daemon มี `127.0.0.0/8` ใน insecure-registries default** — ทำให้ pull/push ไป localhost **ข้าม TLS verification** อัตโนมัติ

→ Lab นี้ทดสอบ TLS validation จริง ๆ ไม่ได้ตรง ๆ ผ่าน localhost  
→ ต้องใช้ hostname อื่น เช่น `registry.local` mapped ไป 127.0.0.1 ใน `/etc/hosts`

```bash
# ต้องใช้ sudo
echo "127.0.0.1 registry.local" | sudo tee -a /etc/hosts
```

หลังจากนั้น push:
```bash
docker tag alpine:3.20 registry.local:5443/test:1.0
docker push registry.local:5443/test:1.0
# x509: certificate signed by unknown authority   ← TLS check active!
```

---

## Step 4 — สอง Path ที่จะให้ Docker Trust Cert

### Path A: Trusted CA Cert (production-correct)

```bash
sudo mkdir -p /etc/docker/certs.d/registry.local:5443
sudo cp certs/registry.crt /etc/docker/certs.d/registry.local:5443/ca.crt

# ไม่ต้อง restart docker — daemon อ่านเองตอน connect
docker push registry.local:5443/test:1.0
# จะผ่าน
```

### Path B: insecure-registries (dev only)

```bash
# /etc/docker/daemon.json
{
  "insecure-registries": ["registry.local:5443"]
}

# restart daemon
sudo systemctl restart docker
```

| | Path A (cert.d) | Path B (insecure) |
|-|----------------|-------------------|
| Encrypt in transit | ✅ | ✅ (เพราะ registry ใช้ TLS) |
| Verify cert identity | ✅ | ❌ ข้ามไป |
| MITM attack | ป้องกัน | เสี่ยง |
| Production | ✅ ใช้ได้ | ❌ ห้าม |

---

## Step 5 — ใช้ Real Cert จาก Let's Encrypt (Production)

สำหรับ production registry ที่มี public DNS:

```bash
# ใช้ certbot สร้าง cert จาก Let's Encrypt
sudo certbot certonly --standalone -d registry.example.com

# mount cert เข้า registry
# REGISTRY_HTTP_TLS_CERTIFICATE: /etc/letsencrypt/live/registry.example.com/fullchain.pem
# REGISTRY_HTTP_TLS_KEY:         /etc/letsencrypt/live/registry.example.com/privkey.pem
```

หรือใช้ reverse proxy (Traefik, Caddy, nginx) จัดการ TLS แทน:
```yaml
services:
  proxy:
    image: caddy:2-alpine
    # Caddy auto-provision Let's Encrypt cert
  registry:
    image: registry:2
    expose: ["5000"]   # ไม่ expose ออก host
```

---

## Cleanup

```bash
docker compose down -v
sudo rm -rf /etc/docker/certs.d/registry.local:5443 2>/dev/null
sudo sed -i '/registry.local/d' /etc/hosts 2>/dev/null
```

---

## TLS Checklist

```
□ Cert มี subjectAltName (SAN) — modern client ไม่ accept ถ้าไม่มี
□ Production ใช้ cert จาก trusted CA (Let's Encrypt, organization CA)
□ Self-signed → ต้อง distribute CA cert ไปทุก client
□ ตั้ง /etc/docker/certs.d/<host>:<port>/ca.crt บนทุก node
□ rotate cert ก่อน expire (Let's Encrypt 90 วัน → automation จำเป็น)
□ ปิด HTTP fallback — registry ฟัง 443 อย่างเดียว
```
