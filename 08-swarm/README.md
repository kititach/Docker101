# Module 08 — Docker Swarm

Cluster orchestration ที่มาพร้อม Docker — turn multiple hosts into one logical engine

## Labs ในโมดูลนี้

| Lab | หัวข้อ | สิ่งที่จะได้เรียน |
|-----|--------|-----------------|
| [01-init-service](./01-init-service/) | Swarm Basics | init, services, replicas, scale, load balancing |
| [02-stacks](./02-stacks/) | Stack Deploy | deploy compose.yaml ทั้ง file เป็น stack, overlay network |
| [03-rolling-update](./03-rolling-update/) | Rolling Updates | update strategy, parallelism, rollback |
| [04-secrets-configs](./04-secrets-configs/) | Secrets & Configs | Swarm secrets (encrypted) vs Compose file secrets |

## Swarm vs Kubernetes vs Compose

| | Compose | Swarm | Kubernetes |
|-|---------|-------|------------|
| Hosts | 1 | หลาย hosts | หลาย hosts |
| Orchestration | ❌ | ✅ | ✅ |
| HA | ❌ | ✅ (Raft consensus) | ✅ |
| Setup complexity | minimal | minimal | สูง |
| Production scale | ❌ | small-medium | large |
| Ecosystem | small | small | huge |

**Swarm เหมาะกับ:** team เล็ก, environment ไม่ซับซ้อน, ใช้ docker compose อยู่แล้ว, ต้องการ HA แต่ไม่ต้องการ K8s overhead

## Architecture (Single-Node Mode สำหรับ Lab)

```
┌──────────────────────────────────────────────────┐
│ Manager Node (this machine)                      │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │ Raft consensus (state, secrets, configs)   │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  Services:                                       │
│    web (replicas=3) → task1, task2, task3       │
│                                                  │
│  Networks: ingress (overlay, routing mesh)       │
└──────────────────────────────────────────────────┘
```

ในระบบจริง: 3-5 manager nodes (Raft quorum) + N worker nodes
