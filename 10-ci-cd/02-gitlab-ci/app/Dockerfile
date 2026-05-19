FROM python:3.12-alpine

WORKDIR /app

# Non-root user — Principle of Least Privilege (CLAUDE.md ข้อ 7)
RUN addgroup -S app && adduser -S -G app app

COPY server.py .

USER app

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD wget -qO- http://localhost:8080/health || exit 1

CMD ["python", "server.py"]
