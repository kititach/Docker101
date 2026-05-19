FROM python:3.12-alpine
WORKDIR /app
COPY app.py .
# CMD ทั้งหมดถูก override ได้เมื่อส่ง arguments ตอน docker run
CMD ["python", "app.py", "hello", "docker"]
