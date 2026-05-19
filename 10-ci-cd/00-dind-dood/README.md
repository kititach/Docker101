# Lab 00: Docker-in-Docker (DinD) & Docker-out-of-Docker (DooD)

เป้าหมาย: ปูพื้นฐานความเข้าใจว่า "คอนเทนเนอร์ จะไปสร้างคอนเทนเนอร์ตัวใหม่ ได้อย่างไร?" เพื่อเตรียมความพร้อมสำหรับระบบ CI/CD

## ทฤษฎี: DinD vs DooD

1. **Docker-in-Docker (DinD)**
   - รัน Docker daemon ตัวใหม่ "ซ้อน" เข้าไปในคอนเทนเนอร์
   - ⚠️ ข้อเสีย: มีปัญหาเรื่องความปลอดภัยและประสิทธิภาพ เพราะต้องใช้โหมด `--privileged` และจัดการระบบไฟล์ซ้อนทับกัน (VFS)

2. **Docker-out-of-Docker (DooD)** 👈 *(แนะนำ)*
   - รันแค่ Docker CLI ในคอนเทนเนอร์ แล้วแชร์ "ท่อสื่อสาร" (`/var/run/docker.sock`) จากเครื่องแม่ลงไป
   - เมื่อคอนเทนเนอร์สั่ง `docker run` มันจะไปสั่งให้เครื่องแม่ (Host) เป็นคนสร้างให้
   - นี่คือวิธีที่ GitLab Runner หรือ Jenkins ส่วนใหญ่ใช้ทำงาน

---

## ภาคปฏิบัติ (Hands-on DooD)

เราจะลองรันคอนเทนเนอร์ธรรมดาขึ้นมา 1 ตัว แล้วทำให้มันสามารถสั่ง `docker ps` เพื่อดูคอนเทนเนอร์บนเครื่องแม่ได้!

### 1. รัน DooD Container
เราจะใช้ `docker-compose.yaml` ที่เตรียมไว้:
```bash
docker compose up -d
```

### 2. ทดลองสั่งงานจากข้างใน
เข้าไปใน container ที่ชื่อ `dood_agent`:
```bash
docker exec -it dood_agent sh
```

เมื่ออยู่ข้างในแล้ว ลองพิมพ์:
```bash
# ตรวจสอบเวอร์ชัน Docker 
docker version

# ดู container ที่รันอยู่ทั้งหมดบนเครื่อง (จะเห็นตัวเองและ container อื่นๆ ของเครื่องแม่)
docker ps

# ลองสร้าง Nginx container ตัวใหม่ (สั่งจากข้างในคอนเทนเนอร์!)
docker run -d -p 8081:80 --name hello_from_inside nginx:alpine
```

### 3. ออกมาดูผลลัพธ์ที่เครื่องแม่
กด `exit` หรือ `Ctrl+D` เพื่อกลับมาที่เครื่องแม่ แล้วลองพิมพ์ `docker ps`
คุณจะพบว่า `hello_from_inside` ถูกสร้างขึ้นมาจริงๆ บนเครื่องแม่ครับ!

---

## 🧹 การทำความสะอาด
```bash
docker rm -f hello_from_inside
docker compose down
```
