# Docker Learning Lab — คู่มือฉบับสมบูรณ์

โปรเจกต์นี้คือพื้นที่เรียนรู้ Docker อย่างลึกซึ้งทุกซอกทุกมุม ตั้งแต่พื้นฐานจนถึงระดับ Production

---

## โครงสร้างโปรเจกต์

```
docker/
├── 01-basics/              # พื้นฐาน: image, container, Dockerfile
├── 02-networking/          # Docker network ทุกรูปแบบ
├── 03-volumes/             # การจัดการ data และ volume
├── 04-compose/             # Docker Compose
├── 05-multi-stage/         # Multi-stage builds
├── 06-security/            # Container security
├── 07-registry/            # Private registry และ image management
├── 08-swarm/               # Docker Swarm clustering
├── 09-monitoring/          # Logging และ monitoring
├── 10-ci-cd/               # Integration กับ CI/CD pipeline
└── labs/                   # Hands-on labs และ exercises
```

---

## หลักการทำงานใน Lab นี้

- **ทุก concept ต้องมี lab จริง** — ไม่ใช่แค่อ่าน ต้องรัน container จริง
- **อธิบาย "ทำไม" ก่อน "อย่างไร"** — เข้าใจ motivation ก่อน syntax
- **ใช้ Alpine/slim image เสมอ** ในตัวอย่าง เพื่อลด image size
- **ทุก Dockerfile ต้อง build ได้จริง** — ทดสอบทุกครั้งก่อน commit
- **ไม่ใช้ `latest` tag** ในตัวอย่างที่ต้องการ reproducibility

---

## ความรู้ที่ต้องครอบคลุม

### 1. Core Concepts

#### Container vs VM
- Container ใช้ kernel เดียวกับ host (namespaces + cgroups)
- ไม่มี guest OS — เบากว่า VM มาก
- Process isolation ผ่าน Linux namespaces: PID, NET, MNT, UTS, IPC, USER

#### Image Layers
- แต่ละ `RUN`/`COPY`/`ADD` สร้าง layer ใหม่
- Layer ถูก cache — เรียงคำสั่งจาก เปลี่ยนน้อย → เปลี่ยนบ่อย เสมอ
- Union filesystem (OverlayFS บน Linux ส่วนใหญ่)

#### Container Lifecycle
```
created → running → paused → running → stopped → removed
                                    ↘ restarting
```

---

### 2. Dockerfile Best Practices

```dockerfile
# ใช้ specific tag เสมอ
FROM python:3.12-slim

# รวม RUN commands เพื่อลด layers
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# COPY requirements ก่อน source code (cache optimization)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# ระบุ USER ที่ไม่ใช่ root
RUN useradd -m appuser
USER appuser

# ระบุ HEALTHCHECK
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:8080/health || exit 1

# ใช้ exec form ไม่ใช่ shell form
CMD ["python", "app.py"]
```

#### Instruction ที่ต้องรู้ทุกตัว
| Instruction | ใช้ทำอะไร | หมายเหตุ |
|-------------|-----------|----------|
| `FROM` | base image | ใช้ multi-stage ได้ |
| `RUN` | รัน command ตอน build | สร้าง layer |
| `CMD` | default command | override ได้ตอนรัน |
| `ENTRYPOINT` | fixed command | ใช้คู่กับ CMD |
| `COPY` | copy files | ใช้แทน ADD เสมอ ยกเว้น tar |
| `ADD` | copy + extract tar/URL | ระวัง unexpected behavior |
| `ENV` | environment variable | คงอยู่ใน container |
| `ARG` | build argument | ใช้ได้แค่ตอน build |
| `EXPOSE` | เอกสาร port | ไม่ได้ publish จริง |
| `VOLUME` | mount point | สร้าง anonymous volume |
| `WORKDIR` | working directory | สร้างให้อัตโนมัติถ้าไม่มี |
| `USER` | run as user | security สำคัญมาก |
| `HEALTHCHECK` | health check | ใช้ใน production เสมอ |
| `LABEL` | metadata | ใช้สำหรับ org/versioning |
| `ONBUILD` | trigger สำหรับ child image | ใช้ใน base images |
| `STOPSIGNAL` | signal ที่ส่งตอน stop | default SIGTERM |
| `SHELL` | เปลี่ยน shell สำหรับ RUN | default /bin/sh -c |

---

### 3. Networking

#### Network Drivers
```
bridge    — default, container-to-container บน host เดียว
host      — ใช้ network stack ของ host โดยตรง (Linux only)
none      — ไม่มี network (fully isolated)
overlay   — cross-host, ใช้กับ Swarm/Kubernetes
macvlan   — container มี MAC address จริง
ipvlan    — L2/L3 routing, ไม่ต้องการ promiscuous mode
```

#### DNS ใน Docker
- Containers ใน custom network คุยกันด้วยชื่อได้ทันที
- Built-in DNS server: `127.0.0.11`
- `--link` เป็น legacy — ใช้ custom network แทน

#### Port Mapping
```bash
# host_port:container_port
docker run -p 8080:80 nginx

# bind เฉพาะ interface
docker run -p 127.0.0.1:8080:80 nginx

# random host port
docker run -p 80 nginx
```

---

### 4. Volumes และ Data Management

#### ประเภท Mount
```
volumes     — managed by Docker (/var/lib/docker/volumes/)
bind mounts — path จริงบน host
tmpfs       — เก็บใน memory เท่านั้น
```

```bash
# Named volume
docker run -v mydata:/app/data nginx

# Bind mount
docker run -v /host/path:/container/path nginx

# tmpfs
docker run --tmpfs /tmp nginx

# Read-only
docker run -v mydata:/app/data:ro nginx
```

#### Volume ที่ควรรู้
- `docker volume inspect` — ดู metadata รวมถึง Mountpoint จริงบน host
- `docker volume prune` — ลบ unused volumes (ระวัง: ลบข้อมูลด้วย)
- Backup: `docker run --rm -v mydata:/data -v $(pwd):/backup alpine tar czf /backup/backup.tar.gz /data`

---

### 5. Docker Compose

#### compose.yaml (v2 format — ใช้แทน docker-compose.yml)
```yaml
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        VERSION: "1.0"
    image: myapp:1.0
    ports:
      - "8080:80"
    environment:
      - DATABASE_URL=postgres://db/myapp
    env_file:
      - .env
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - ./src:/app/src
    networks:
      - frontend
      - backend
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

  db:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - backend

volumes:
  pgdata:

networks:
  frontend:
  backend:
    internal: true  # ไม่มี internet access

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

#### Compose Commands ที่ใช้บ่อย
```bash
docker compose up -d                    # start ใน background
docker compose down -v                  # stop + ลบ volumes
docker compose logs -f web              # ดู logs แบบ follow
docker compose exec web sh              # exec เข้า container
docker compose ps                       # ดูสถานะ
docker compose build --no-cache         # rebuild ทั้งหมด
docker compose scale web=3              # scale service
docker compose config                   # validate และ print merged config
docker compose --profile debug up       # ใช้ profile
```

---

### 6. Multi-Stage Builds

```dockerfile
# Stage 1: Builder
FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /app .

# Stage 2: Runner (final image)
FROM scratch
COPY --from=builder /app /app
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
ENTRYPOINT ["/app"]
```

ประโยชน์:
- Final image ไม่มี build tools → เล็กกว่ามาก
- Build secrets ไม่รั่วไหลมาใน final image
- ใช้ `FROM scratch` สำหรับ statically compiled binaries

---

### 7. Security

#### หลักการ Principle of Least Privilege
```dockerfile
# สร้าง user ที่ไม่มี shell และ home directory ไม่จำเป็น
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
```

#### สิ่งที่ต้องทำเสมอ
- ไม่รัน container เป็น root
- ใช้ `--read-only` filesystem เมื่อทำได้
- Drop capabilities ที่ไม่จำเป็น: `--cap-drop=ALL --cap-add=NET_BIND_SERVICE`
- Scan image: `docker scout cves myimage` หรือ `trivy image myimage`
- ไม่ใส่ secrets ใน ENV หรือ ARG — ใช้ Docker Secrets หรือ external vault
- ใช้ `--security-opt=no-new-privileges`
- Set `ulimits` เพื่อป้องกัน resource exhaustion

#### Secret Management
```bash
# Docker Secrets (ใช้ได้กับ Swarm และ Compose)
echo "mysecret" | docker secret create db_password -

# Build secret (ไม่เก็บใน layer)
docker build --secret id=npmrc,src=$HOME/.npmrc .
```

ใน Dockerfile:
```dockerfile
RUN --mount=type=secret,id=npmrc cat /run/secrets/npmrc
```

---

### 8. Resource Management

```bash
# จำกัด CPU และ Memory
docker run \
  --cpus="1.5" \
  --memory="512m" \
  --memory-swap="512m" \  # ปิด swap
  --pids-limit=100 \
  myapp

# ดู resource usage
docker stats
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

---

### 9. Logging

#### Log Drivers
```
json-file   — default, เก็บใน host filesystem
journald    — ส่งไป systemd journal
syslog      — ส่งไป syslog
fluentd     — ส่งไป Fluentd
gelf        — Graylog Extended Log Format
awslogs     — AWS CloudWatch
splunk      — Splunk
```

```bash
# ตั้ง log rotation (ควรทำเสมอ)
docker run \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  myapp

# ดู logs
docker logs -f --since 1h --until 30m myapp
docker logs --tail 100 myapp
```

---

### 10. Docker Swarm

```bash
# Init swarm
docker swarm init --advertise-addr <MANAGER_IP>

# Join worker
docker swarm join --token <TOKEN> <MANAGER_IP>:2377

# Deploy stack
docker stack deploy -c compose.yaml mystack

# Scale service
docker service scale mystack_web=5

# Rolling update
docker service update \
  --image myapp:2.0 \
  --update-parallelism 2 \
  --update-delay 10s \
  mystack_web

# Rollback
docker service rollback mystack_web
```

---

### 11. Registry

```bash
# Run private registry
docker run -d \
  -p 5000:5000 \
  --restart=always \
  -v registry-data:/var/lib/registry \
  --name registry \
  registry:2

# Tag และ push ไป private registry
docker tag myapp:1.0 localhost:5000/myapp:1.0
docker push localhost:5000/myapp:1.0

# Pull
docker pull localhost:5000/myapp:1.0

# List images ใน registry
curl http://localhost:5000/v2/_catalog
curl http://localhost:5000/v2/myapp/tags/list
```

---

### 12. Troubleshooting

```bash
# ดู process ใน container
docker top <container>

# ดู events แบบ real-time
docker events --filter type=container

# ดู filesystem changes
docker diff <container>

# Export/import container filesystem
docker export <container> | tar tv

# Inspect ทุกอย่าง
docker inspect <container/image/network/volume>

# ดู image history และ layers
docker history --no-trunc myimage

# Debug container ที่ crash ทันที (ใช้ entrypoint override)
docker run --entrypoint sh myimage

# Copy files ออกจาก container
docker cp <container>:/app/logs ./logs

# Attach โดยไม่ต้อง exec
docker attach <container>

# ดู stats ทุก container
docker stats $(docker ps -q)
```

---

### 13. BuildKit และ Advanced Build Features

```bash
# Enable BuildKit
DOCKER_BUILDKIT=1 docker build .

# หรือใช้ docker buildx (recommended)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag myapp:1.0 \
  --push \
  .

# Build cache จาก registry
docker buildx build \
  --cache-from type=registry,ref=myregistry/myapp:buildcache \
  --cache-to type=registry,ref=myregistry/myapp:buildcache,mode=max \
  .

# Bake — build หลาย target พร้อมกัน
docker buildx bake --file docker-bake.hcl
```

---

### 14. Useful Patterns

#### Wait for dependency
```bash
# ใช้ wait-for-it script หรือ dockerize
dockerize -wait tcp://db:5432 -timeout 60s ./myapp
```

#### Init process (ป้องกัน zombie processes)
```bash
docker run --init myapp
# หรือใน Dockerfile
ENTRYPOINT ["/sbin/tini", "--", "python", "app.py"]
```

#### จัดการ container ที่ตายแล้ว
```bash
# ลบ stopped containers ทั้งหมด
docker container prune

# ลบทุกอย่างที่ไม่ใช้
docker system prune -a --volumes
```

---

## คำสั่ง Docker ที่ต้องรู้ทั้งหมด

### Container Management
```bash
docker run / start / stop / restart / rm / pause / unpause
docker ps / ps -a
docker exec -it <container> sh
docker logs / stats / top / diff / inspect
docker cp / export / commit
docker rename / update
docker wait   # รอจนกว่า container จะ stop
docker kill   # ส่ง signal (default SIGKILL)
```

### Image Management
```bash
docker build / pull / push / tag / rmi
docker images / image ls
docker image prune
docker image inspect
docker save / load    # export/import image (tar)
docker history
docker manifest inspect   # ดู multi-arch manifest
```

### System
```bash
docker info           # ดูข้อมูล daemon
docker version        # version ของ client และ server
docker system df      # ดู disk usage
docker system prune   # cleanup
docker context        # จัดการหลาย Docker endpoints
docker trust          # image signing
```

---

## Environment Setup

```bash
# ตรวจสอบ installation
docker version
docker info
docker run hello-world

# ตรวจสอบ BuildKit
docker buildx version

# ตรวจสอบ Compose
docker compose version
```

---

## Lab Workflow

เมื่อสร้าง lab ใหม่ให้ทำตามขั้นตอนนี้เสมอ:

1. สร้างโฟลเดอร์ใต้ `labs/` หรือหมวดที่เกี่ยวข้อง
2. เขียน `README.md` อธิบาย concept และ objective
3. สร้างไฟล์ที่จำเป็น (Dockerfile, compose.yaml, scripts)
4. ทดสอบจนได้ผลจริงบนเครื่อง
5. เพิ่ม cleanup instructions ใน README

---

## หมายเหตุสำหรับ Claude

- เมื่อเขียน Dockerfile ให้ build และตรวจสอบว่า syntax ถูกต้องก่อนเสมอ
- อธิบาย trade-off ของแต่ละ approach (เช่น bind mount vs volume)
- เมื่อ user ถามเรื่อง security ให้ครอบคลุมทั้ง image scan, runtime security, และ network policy
- ชี้ให้เห็น anti-pattern เมื่อพบ เช่น การใช้ `ADD` แทน `COPY`, รัน root, ไม่มี HEALTHCHECK
- ใช้ภาษาไทยในการอธิบาย แต่ใช้ technical terms เป็นภาษาอังกฤษตามปกติ
