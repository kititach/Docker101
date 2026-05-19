FROM python:3.12-alpine
WORKDIR /app

# GOOD: COPY requirements ก่อน — pip install ถูก cache ตราบใดที่ requirements ไม่เปลี่ยน
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# COPY source code ทีหลัง — cache miss ที่นี่ไม่กระทบ pip layer
COPY . .

CMD ["python", "app.py"]
