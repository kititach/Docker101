# Stage 1: Install ALL deps (รวม devDependencies: nodemon, jest)
FROM node:20-alpine AS deps-all
WORKDIR /app
COPY package.json .
RUN npm install

# Stage 2: Install เฉพาะ production deps
FROM node:20-alpine AS deps-prod
WORKDIR /app
COPY package.json .
RUN npm install --omit=dev

# Stage 3: Runtime — copy เฉพาะ prod deps + source code
FROM node:20-alpine AS runtime
WORKDIR /app
COPY --from=deps-prod /app/node_modules ./node_modules
COPY src/ ./src/
RUN addgroup -S app && adduser -S app -G app
USER app
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s \
  CMD wget -qO- http://localhost:8080/health || exit 1
CMD ["node", "src/server.js"]
