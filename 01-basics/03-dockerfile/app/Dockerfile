# Best-practices Dockerfile — รวมทุก concept ที่เรียนใน Lab 03
FROM python:3.12-alpine

# LABEL — metadata สำหรับ organization และ tooling
LABEL org.opencontainers.image.title="lab03-app" \
      org.opencontainers.image.version="1.0"

# ARG — ใช้ได้แค่ตอน build (ไม่ติดมาใน image)
ARG APP_VERSION=1.0
ARG BUILD_DATE=unknown

# ENV — คงอยู่ใน container runtime
ENV APP_VERSION=${APP_VERSION} \
    BUILD_DATE=${BUILD_DATE} \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# COPY ดีกว่า ADD สำหรับ local files
COPY app.py .

# รวม RUN เป็น layer เดียว + cleanup ในที่เดียวกัน
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python app.py whoami || exit 1

ENTRYPOINT ["python", "app.py"]
CMD ["hello", "world"]
