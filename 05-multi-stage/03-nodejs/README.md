# Lab 03 — Node.js: ตัด devDependencies ออกจาก Runtime

## ผลวัดจริง

| Stage | Image | ขนาด |
|-------|-------|------|
| All deps (incl. nodemon, jest) | `node:20-alpine` | 383 MB |
| **Final** (prod deps only) | `node:20-alpine` | **199 MB** |

ลด **48%** โดยตัด devDependencies ออก

---

## Files

```
03-nodejs/
├── src/
│   ├── server.js   — Express HTTP server
│   └── utils.js
├── package.json    — express (prod) + nodemon, jest (dev)
├── Dockerfile
└── README.md
```

---

## Step 1 — ดู Dockerfile (3 stages)

```dockerfile
# Stage 1: install ALL deps (dev + prod)
FROM node:20-alpine AS deps-all
WORKDIR /app
COPY package.json .
RUN npm install

# Stage 2: install เฉพาะ production deps
FROM node:20-alpine AS deps-prod
WORKDIR /app
COPY package.json .
RUN npm install --omit=dev

# Stage 3: runtime — copy prod deps + source
FROM node:20-alpine AS runtime
COPY --from=deps-prod /app/node_modules ./node_modules
COPY src/ ./src/
USER node
```

---

## Step 2 — Build และเปรียบเทียบ

```bash
docker build -t ms-node:final .
docker build --target deps-all -t ms-node:all-deps .

docker images | grep ms-node
# ms-node:all-deps   383MB  ← nodemon + jest + express
# ms-node:final      199MB  ← express เท่านั้น
```

ดูขนาด node_modules จริง:
```bash
# all deps
docker run --rm ms-node:all-deps du -sh node_modules
# ~270MB

# prod deps only
docker run --rm ms-node:final du -sh node_modules
# ~80MB   ← ลดลงมาก เพราะไม่มี jest (+ dependencies)
```

---

## Step 3 — ทดสอบ

```bash
docker run -d --name node-app -p 9093:8080 ms-node:final

curl http://localhost:9093/
# {"message":"Hello, world! (node v20.x.x)","service":"node-app"}

curl http://localhost:9093/health
# OK
```

---

## Step 4 — ยืนยันว่า devDependencies ไม่อยู่ใน Final

```bash
# nodemon ไม่อยู่ใน final
docker run --rm ms-node:final npx nodemon --version 2>&1
# Cannot find module 'nodemon'

# jest ไม่อยู่ใน final
docker run --rm ms-node:final npx jest --version 2>&1
# Cannot find module 'jest'

# express ยังอยู่
docker run --rm ms-node:final node -e "require('express'); console.log('OK')"
# OK
```

---

## Step 5 — Pattern สำหรับ TypeScript

ถ้า project ใช้ TypeScript multi-stage จะมีค่ามากกว่า:

```dockerfile
# Stage 1: Build TypeScript → JavaScript
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json tsconfig.json .
RUN npm install              # รวม typescript compiler
COPY src/ ./src/
RUN npm run build            # tsc → dist/

# Stage 2: Runtime — ไม่มี TypeScript compiler, ไม่มี src/
FROM node:20-alpine AS runtime
WORKDIR /app
COPY package.json .
RUN npm install --omit=dev
COPY --from=builder /app/dist ./dist
USER node
CMD ["node", "dist/server.js"]
```

Final image: ไม่มี TypeScript compiler (~50MB), ไม่มี source .ts files, มีแค่ compiled .js

---

## Cleanup

```bash
docker rm -f node-app
docker rmi ms-node:final ms-node:all-deps
```
