# Module 05 — Multi-Stage Builds

แยก build environment ออกจาก runtime environment — build tools ไม่ติดมาใน final image

## Labs ในโมดูลนี้

| Lab | ภาษา | Build | Runtime | ลดขนาด |
|-----|------|-------|---------|--------|
| [01-go](./01-go/) | Go | `golang:1.22-alpine` 443 MB | `scratch` 7 MB | **-98%** |
| [02-python](./02-python/) | Python | `python:3.12` 1.64 GB | `python:3.12-slim` 203 MB | **-88%** |
| [03-nodejs](./03-nodejs/) | Node.js | all deps 383 MB | prod deps only 199 MB | **-48%** |

## ทำไม Multi-Stage?

```
Single-stage:  [build tools + runtime + source + compiled output]  → image ใหญ่
Multi-stage:   build tools ใช้แล้วทิ้ง, final image มีแค่ [runtime + output]
```

ประโยชน์:
- **Size** — image เล็กกว่า = pull เร็ว, deploy เร็ว
- **Security** — gcc, make, npm devDependencies ไม่ติดไปใน production
- **Secrets** — API key, SSH key ที่ใช้ตอน build ไม่รั่วใน layer
