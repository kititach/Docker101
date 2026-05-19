# Lab 01 — Init Swarm + Services

## Objective

เริ่ม Swarm cluster, สร้าง service, scale, และเข้าใจ load balancing ผ่าน ingress mesh

---

## Step 1 — Init Swarm

```bash
docker swarm init
```

ผล:
```
Swarm initialized: current node (qieo04k501qn16sdvzb4psejj) is now a manager.

To add a worker to this swarm, run the following command:
    docker swarm join --token SWMTKN-1-... 10.85.3.102:2377
```

ดู nodes ใน cluster:
```bash
docker node ls
# ID                            HOSTNAME     STATUS    AVAILABILITY   MANAGER STATUS
# qieo04k501qn16sdvzb4psejj *   server1      Ready     Active         Leader
```

> Single-node Swarm: node เดียวเป็นทั้ง manager และ worker  
> Multi-node: ใช้ `docker swarm join-token worker` / `manager` เพื่อดู token

---

## Step 2 — Service vs Container

Swarm ไม่จัดการ container โดยตรง — มันจัดการ **service** ที่ schedule **tasks** (each task = 1 container)

```
Service "web" (replicas=3)
    │
    ├─ Task 1 → Container on node A
    ├─ Task 2 → Container on node B
    └─ Task 3 → Container on node A
```

---

## Step 3 — สร้าง Service

```bash
docker service create \
  --name web \
  --replicas 3 \
  --publish 9081:80 \
  nginxdemos/hello:plain-text
```

`nginxdemos/hello` แสดง hostname + IP ของ task → ดู load balancing ได้

ผล:
```
verify: Service web converged
```

---

## Step 4 — ดู Services และ Tasks

```bash
docker service ls
# ID         NAME   MODE         REPLICAS   IMAGE                          PORTS
# lc84aw...  web    replicated   3/3        nginxdemos/hello:plain-text    *:9081->80/tcp

docker service ps web
# ID         NAME    IMAGE   NODE       DESIRED STATE   CURRENT STATE
# spcw...    web.1   ...     server1    Running         Running 5 sec ago
# t1qq...    web.2   ...     server1    Running         Running 5 sec ago
# cf9n...    web.3   ...     server1    Running         Running 5 sec ago
```

`3/3` = 3 desired / 3 running — service converged

---

## Step 5 — Load Balancing ผ่าน Ingress Mesh

```bash
for i in $(seq 1 6); do
  curl -s http://127.0.0.1:9081/ | grep "Server address"
done
```

ผล (round-robin):
```
Server address: 10.0.0.9:80
Server address: 10.0.0.8:80
Server address: 10.0.0.7:80
Server address: 10.0.0.9:80   ← วน
Server address: 10.0.0.8:80
Server address: 10.0.0.7:80
```

> **⚠️ IPv6 quirk:** `curl http://localhost:9081/` อาจ hang ถ้า `localhost` resolve `::1` ก่อน  
> Swarm ingress รองรับเฉพาะ IPv4 — ใช้ `127.0.0.1` หรือ `curl -4` แทน

---

## Step 6 — Ingress Network และ Routing Mesh

```bash
docker network ls | grep -E "ingress|overlay"
# 39evbf01jlvq   ingress   overlay   swarm

docker network inspect ingress --format \
  '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{"\n"}}{{end}}'
# web.1.xxx: 10.0.0.4/24
# web.2.xxx: 10.0.0.5/24
# web.3.xxx: 10.0.0.6/24
# ingress-endpoint: 10.0.0.2/24
```

**Routing mesh:** ทุก node ใน swarm รับ traffic บน published port — daemon route ไปยัง task ใด ๆ ของ service (อาจอยู่ node อื่น) ผ่าน overlay network

```
Client → :9081 → ingress sboard → any swarm node → any web task
```

---

## Step 7 — Scale Service

```bash
docker service scale web=5
# web scaled to 5
# verify: Service web converged
```

ดูผล:
```bash
docker service ps web --format "{{.Name}}\t{{.CurrentState}}"
# web.1    Running 2 minutes ago
# web.2    Running 2 minutes ago
# web.3    Running 2 minutes ago
# web.4    Running 4 seconds ago   ← ใหม่
# web.5    Running 4 seconds ago   ← ใหม่
```

Scale down:
```bash
docker service scale web=2
docker service ps web   # เห็น "Shutdown" state
```

---

## Step 8 — Service Inspect

```bash
docker service inspect web --pretty
# ID:             ...
# Name:           web
# Service Mode:   Replicated
# Replicas:       2
# Placement:
# UpdateConfig:
#   Parallelism:  1
#   On failure:   pause
#   ...
```

ดูเฉพาะ image:
```bash
docker service inspect web --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'
```

---

## Step 9 — Service Logs

```bash
docker service logs -f web
# จะ stream logs จากทุก task รวมกัน — prefix ด้วย task ID
```

---

## Cleanup

```bash
docker service rm web

# leave swarm (optional — ถ้าทำ lab อื่นต่อ ให้ skip)
docker swarm leave --force
```

---

## Service vs Container Commands

| Container (single host) | Service (Swarm cluster) |
|------------------------|------------------------|
| `docker run` | `docker service create` |
| `docker ps` | `docker service ls` + `docker service ps <svc>` |
| `docker stop/rm` | `docker service rm` |
| `docker logs` | `docker service logs` |
| `docker exec` | `docker exec` (เข้า container ที่หา task แล้ว) |
| ทำ scaling เอง | `docker service scale svc=N` |
