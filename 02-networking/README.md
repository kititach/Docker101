# Module 02 — Networking

Docker networking ทุกรูปแบบ — เข้าใจว่า container คุยกันอย่างไร และควบคุม traffic ได้อย่างไร

## Labs ในโมดูลนี้

| Lab | หัวข้อ | สิ่งที่จะได้เรียน |
|-----|--------|-----------------|
| [01-bridge](./01-bridge/) | Default Bridge Network | IP-based comms, ข้อจำกัดของ default bridge |
| [02-custom-network](./02-custom-network/) | Custom Network + DNS | DNS by name, network isolation |
| [03-host-none](./03-host-none/) | Host & None Networks | edge case networks, use cases จริง |
| [04-port-mapping](./04-port-mapping/) | Port Mapping | -p flag ทุกรูปแบบ, interface binding |
| [05-multi-container](./05-multi-container/) | Multi-Container Lab | nginx + backend + redis, network segmentation |

## ลำดับการเรียน

```
01 → 02 → 03 → 04 → 05
```

## Network Drivers สรุป

```
bridge    — default, container-to-container บน host เดียวกัน
host      — ใช้ network stack ของ host โดยตรง (Linux only)
none      — ไม่มี network (fully isolated)
overlay   — cross-host (Swarm / Kubernetes)
macvlan   — container มี MAC address จริง
```
