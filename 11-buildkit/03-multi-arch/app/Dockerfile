# BuildKit จะ inject build args เหล่านี้ให้อัตโนมัติเมื่อ build ด้วย --platform
# - TARGETPLATFORM = linux/amd64, linux/arm64, ...
# - TARGETARCH = amd64, arm64, ...
# - BUILDPLATFORM = platform ของเครื่องที่ build (สำหรับ cross-compile pattern)
# FROM ตรงๆ ก็ได้ — BuildKit จะ pull image ตรงตาม --platform ที่สั่ง
FROM python:3.12-alpine

ARG TARGETPLATFORM
ARG TARGETARCH

# พิมพ์ระหว่าง build ให้เห็นว่าตอนนี้ build platform ไหน
RUN echo "Building for: $TARGETPLATFORM (arch=$TARGETARCH)"

WORKDIR /app

RUN addgroup -S app && adduser -S -G app app

COPY server.py .

USER app

EXPOSE 8080

CMD ["python", "server.py"]
