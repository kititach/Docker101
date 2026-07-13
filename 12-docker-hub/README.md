

```bash
docker login
docker build -t easy-web:v1 .
docker tag easy-web:v1 ชื่อยูสเซอร์DockerHubของคุณ/easy-web:v1
docker push ชื่อยูสเซอร์DockerHubของคุณ/easy-web:v1
```

# ตรวจสอบ
```bash
docker run -d -p 80:80 ชื่อยูสเซอร์ของคุณ/easy-web:v1
```

# update (version image)

แก้ไข ไฟล์ที่ต้องการ update

# ทำการ build ใหม่พร้อมเปลี่ยน tag version
```bash
docker build -t easy-web:v2 .
docker tag easy-web:v2 ชื่อยูสเซอร์ของคุณ/easy-web:v2
docker push ชื่อยูสเซอร์ของคุณ/easy-web:v2
```

# ปล. ในวงการ DevOps มีธรรมเนียมปฏิบัติอย่างหนึ่งคือ "Image ตัวไหนที่ใหม่ที่สุด ณ ตอนนั้น ควรจะถูกแปะป้ายคำว่า latest ควบคู่ไปด้วยเสมอ"

# แปะป้ายล่าสุดพ่วงเข้าไป
```bash
docker tag easy-web:v2 ชื่อยูสเซอร์ของคุณ/easy-web:latest

# Push ตัวล่าสุดขึ้นไปอัปเดตคลัง
docker push ชื่อยูสเซอร์ของคุณ/easy-web:latest
```
