FROM python:3.12-alpine
RUN pip install --no-cache-dir flask==3.0.3 && \
    addgroup -S app && adduser -S -G app -u 10001 app
WORKDIR /app
COPY --chown=10001:10001 app.py .
USER 10001:10001
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s \
  CMD wget -qO- http://localhost:8080/health || exit 1
CMD ["python", "app.py"]
