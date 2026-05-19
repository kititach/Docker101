FROM python:3.12-alpine

WORKDIR /app

COPY server.py .

ENV PORT=8080
ENV APP_NAME=hello-docker

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s \
  CMD wget -qO- http://localhost:8080 || exit 1

CMD ["python", "server.py"]
