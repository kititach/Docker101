# Numeric UID — ใช้กับ FROM scratch / distroless ที่ไม่มี /etc/passwd
# Kubernetes runAsNonRoot policy ตรวจสอบจาก UID ตัวเลขเท่านั้น
FROM alpine:3.20
COPY app.sh /app.sh
RUN chmod +x /app.sh && chown 10001:10001 /app.sh
USER 10001:10001
CMD ["/app.sh"]
