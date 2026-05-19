FROM python:3.12-alpine

ARG APP_VERSION=1.0
ENV APP_VERSION=${APP_VERSION}

WORKDIR /app
COPY server.py .

RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s \
  CMD wget -qO- http://localhost:8080 || exit 1

CMD ["python", "server.py"]
