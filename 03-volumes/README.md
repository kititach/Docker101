# Module 03 — Volumes

จัดการ data ใน Docker ทุกรูปแบบ — ทำความเข้าใจว่าข้อมูลไปอยู่ที่ไหน และเลือกใช้ mount type ไหนสำหรับงานแต่ละประเภท

## Labs ในโมดูลนี้

| Lab | หัวข้อ | สิ่งที่จะได้เรียน |
|-----|--------|-----------------|
| [01-named-volume](./01-named-volume/) | Named Volumes | create, inspect, persist, backup, restore, share |
| [02-bind-mount](./02-bind-mount/) | Bind Mounts | dev workflow, hot-reload, read-only mount |
| [03-tmpfs](./03-tmpfs/) | tmpfs | in-memory storage, sensitive data, ไม่เขียน disk |
| [04-volume-drivers](./04-volume-drivers/) | Volume Drivers | local driver options, size limit, NFS overview |

## Mount Types เปรียบเทียบ

```
Named Volume          Bind Mount            tmpfs
─────────────         ──────────────        ──────────────
/var/lib/docker/      path บน host ใดก็ได้   RAM เท่านั้น
volumes/mydata/       ที่คุณระบุเอง           หายเมื่อ stop

Docker manage         คุณ manage             ไม่มี disk I/O
  └ portable          └ ต้อง path ตรงกัน      └ เหมาะ secret/cache

ใช้กับ production DB   ใช้กับ dev hot-reload  ใช้กับ sensitive data
```
