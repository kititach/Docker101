# Lab 02 — Stack Deploy

## Objective

Deploy compose.yaml ทั้ง file เป็น stack ใน Swarm — get multi-service orchestration ด้วย command เดียว

---

## Compose vs Stack

`docker compose` และ `docker stack deploy` อ่าน YAML format เดียวกัน แต่:

| | `docker compose up` | `docker stack deploy` |
|-|---------------------|----------------------|
| Target | single host | Swarm cluster |
| `build:` | ✅ build ก่อน run | ❌ ต้อง push image ก่อน |
| `deploy:` block | ❌ ignored | ✅ ใช้ replicas, placement, resources |
| `depends_on:` | ✅ startup order | ❌ ignored (services start แบบ independent) |
| Scaling | `--scale web=3` | ใน YAML: `deploy.replicas: 3` |

---

## Step 1 — เตรียม Swarm (ถ้ายังไม่ active)

```bash
docker info | grep "Swarm:"
# Swarm: active   ← OK

# ถ้าไม่ active
docker swarm init
```

---

## Step 2 — ดู compose.yaml

```yaml
services:
  web:
    image: nginxdemos/hello:plain-text
    ports: ["9082:80"]
    deploy:                        # ← Swarm-specific block
      replicas: 3
      update_config:
        parallelism: 1
        delay: 5s
      resources:
        limits: { cpus: "0.5", memory: 64M }
    networks: [frontend]

  cache:
    image: redis:7-alpine
    deploy:
      placement:
        constraints: [node.role == manager]   # บังคับให้รันบน manager
    networks: [backend]
```

---

## Step 3 — Deploy Stack

```bash
docker stack deploy -c compose.yaml myapp
```

ผล:
```
Creating network myapp_frontend
Creating network myapp_backend
Creating service myapp_web
Creating service myapp_cache
```

> Stack name = prefix ของทุก resource (network, service, volume) → ป้องกันชนกัน

---

## Step 4 — ดู Stack Resources

```bash
docker stack ls
# NAME    SERVICES
# myapp   2

docker stack services myapp
# ID       NAME           MODE         REPLICAS   IMAGE
# abc...   myapp_web      replicated   3/3        nginxdemos/hello
# def...   myapp_cache    replicated   1/1        redis:7-alpine

docker stack ps myapp
# ID    NAME            IMAGE              NODE       DESIRED STATE   CURRENT STATE
# ...   myapp_web.1     nginxdemos/hello   server1    Running         Running 1 min
# ...   myapp_web.2     nginxdemos/hello   server1    Running         Running 1 min
# ...   myapp_web.3     nginxdemos/hello   server1    Running         Running 1 min
# ...   myapp_cache.1   redis:7-alpine     server1    Running         Running 1 min
```

---

## Step 5 — ทดสอบ Service Discovery (DNS)

Service ใน stack เดียวกัน DNS resolve ด้วยชื่อ service:

```bash
# เข้า web container แล้ว ping cache
TASK_ID=$(docker ps -q -f "label=com.docker.swarm.service.name=myapp_web" | head -1)
docker exec $TASK_ID nslookup myapp_cache
# Name:   myapp_cache
# Address: 10.0.x.x   ← VIP ของ cache service
```

หรือใช้ short name (เฉพาะใน stack เดียวกัน):
```bash
docker exec $TASK_ID nslookup cache
```

---

## Step 6 — ดู Overlay Networks

```bash
docker network ls --filter scope=swarm
# myapp_frontend   overlay   swarm
# myapp_backend    overlay   swarm
# ingress          overlay   swarm

# inspect
docker network inspect myapp_backend --format \
  '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{"\n"}}{{end}}'
# myapp_cache.1.xxx: 10.0.x.x/24
```

**Network segmentation** — web อยู่ frontend, cache อยู่ backend → ตัด traffic ที่ไม่จำเป็น

---

## Step 7 — Update Stack

แก้ compose.yaml (เช่น เปลี่ยน replicas) แล้ว deploy ซ้ำ:

```bash
# เปลี่ยน web replicas เป็น 5
sed -i 's/replicas: 3/replicas: 5/' compose.yaml

docker stack deploy -c compose.yaml myapp
# Updating service myapp_web (id: ...)

docker stack services myapp
# myapp_web   replicated   5/5
```

Swarm cluster diff config เก่ากับใหม่ → update เฉพาะส่วนที่เปลี่ยน

---

## Step 8 — Stack Config Output

```bash
# ดู merged + validated config ที่ Swarm จะใช้
docker stack config -c compose.yaml
```

ใช้ debug compose.yaml ก่อน deploy

---

## Step 9 — Remove Stack

```bash
docker stack rm myapp
# Removing service myapp_cache
# Removing service myapp_web
# Removing network myapp_frontend
# Removing network myapp_backend
```

> volumes ที่ stack สร้างจะ **ไม่ถูกลบ** อัตโนมัติ — ต้อง `docker volume rm` เอง

---

## Stack vs `docker compose` Migration

| compose.yaml directive | Stack equivalent |
|------------------------|------------------|
| `build:` | ต้อง push image แล้วใช้ `image:` |
| `depends_on:` | ไม่ทำงาน — design ให้ service handle เอง |
| `restart: unless-stopped` | `deploy.restart_policy` |
| `--scale web=3` | `deploy.replicas: 3` |
| `mem_limit: 256m` | `deploy.resources.limits.memory: 256M` |

---

## Cleanup

```bash
docker stack rm myapp
```
