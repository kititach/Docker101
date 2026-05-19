# Lab 01 — Go: FROM scratch

## ผลวัดจริง

| Stage | Image | ขนาด |
|-------|-------|------|
| Builder | `golang:1.22-alpine` + compiled binary | 443 MB |
| **Final** | `scratch` + binary เท่านั้น | **7 MB** |

ลด **98%** — เหลือแค่ binary ไม่มี OS เลย

---

## Files

```
01-go/
├── main.go     — HTTP server ใช้แค่ stdlib
├── go.mod
├── Dockerfile
└── README.md
```

---

## Step 1 — ดู Dockerfile

```dockerfile
# Stage 1: Build
FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY go.mod .
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app .

# Stage 2: Runtime
FROM scratch
COPY --from=builder /app /app
EXPOSE 8080
ENTRYPOINT ["/app"]
```

**Flags ที่สำคัญ:**
- `CGO_ENABLED=0` — static binary ไม่พึ่ง shared C library → รันบน `scratch` ได้
- `-ldflags="-s -w"` — ตัด debug symbols และ DWARF table → binary เล็กลง ~30%
- `FROM scratch` — empty image ไม่มี OS, shell, หรือ library ใด ๆ

---

## Step 2 — Build

```bash
# build final image
docker build -t ms-go:final .

# build stage builder เพื่อเปรียบเทียบขนาด
docker build --target builder -t ms-go:builder .

docker images | grep ms-go
# ms-go:builder   443MB  ← golang toolchain + source + binary
# ms-go:final     7MB    ← binary ล้วน ๆ
```

---

## Step 3 — ทดสอบ

```bash
docker run -d --name go-app -p 9091:8080 ms-go:final

curl http://localhost:9091/
# {"go":"go1.22.x","service":"go-app","time":"..."}

curl http://localhost:9091/health
# OK
```

---

## Step 4 — ดู Image Contents

```bash
# scratch มีแค่ /app ไม่มีอะไรอื่น
docker export $(docker create ms-go:final) | tar tv
# -rwxr-xr-x  /app   ← มีแค่ binary เดียว!
```

เปรียบเทียบกับ builder:
```bash
docker export $(docker create ms-go:builder) | tar tv | wc -l
# หลายพันไฟล์ — Go toolchain, libraries, OS files
```

---

## Step 5 — ข้อจำกัดของ scratch

scratch image ไม่มี shell → debug ยากกว่า:

```bash
docker exec go-app sh
# Error: No such file or directory  ← ไม่มี /bin/sh!

# ถ้าต้องการ debug ใช้ distroless หรือ alpine แทน
# FROM gcr.io/distroless/static-debian12
# FROM alpine:3.20
```

สำหรับ Go ที่ต้องการ TLS certificates (HTTPS outbound):
```dockerfile
FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /app /app
ENTRYPOINT ["/app"]
```

---

## Step 6 — ตรวจสอบ Layers

```bash
docker history ms-go:final
# IMAGE          CREATED BY                SIZE
# <layer>        ENTRYPOINT ["/app"]        0B
# <layer>        EXPOSE 8080                0B
# <layer>        COPY /app /app             7MB  ← layer เดียว!
```

---

## Cleanup

```bash
docker rm -f go-app
docker rmi ms-go:final ms-go:builder
```
