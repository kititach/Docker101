FROM python:3.12-alpine
WORKDIR /app

# BAD: COPY ทั้งหมดก่อน — แก้ไฟล์ใดก็ตาม pip install รันใหม่ทุกครั้ง
COPY . .
RUN pip install --no-cache-dir -r requirements.txt

CMD ["python", "app.py"]
