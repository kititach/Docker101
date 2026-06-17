FROM python:3.12-alpine
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s \
  CMD wget -qO- http://127.0.0.1:8080/health || exit 1
CMD ["python", "app.py"]
