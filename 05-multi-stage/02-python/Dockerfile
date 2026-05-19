# Stage 1: Builder — python:3.12 full มี gcc + build tools สำหรับ compile C extensions
FROM python:3.12 AS builder
WORKDIR /build
COPY requirements.txt .
# --prefix=/deps: ติดตั้งใน path แยก เพื่อ COPY ไปยัง stage ถัดไปได้ง่าย
RUN pip install --no-cache-dir --prefix=/deps -r requirements.txt

# Stage 2: Runtime — slim ใช้ glibc เหมือน builder จึง compatible กับ compiled extensions
# (Alpine ใช้ musl libc ซึ่งไม่ compatible กับ binary ที่ compile บน glibc)
FROM python:3.12-slim AS runtime
WORKDIR /app
COPY --from=builder /deps /usr/local
COPY app.py .
RUN groupadd -r app && useradd -r -g app app
USER app
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s \
  CMD curl -f http://localhost:8080/health || exit 1
CMD ["python", "app.py"]
