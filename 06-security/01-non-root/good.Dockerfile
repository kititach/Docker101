# GOOD: สร้าง non-root user แล้ว USER ก่อน CMD
FROM alpine:3.20
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --chown=appuser:appgroup app.sh /app.sh
RUN chmod +x /app.sh
USER appuser
CMD ["/app.sh"]
