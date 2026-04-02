# 🚀 Docker 101: Deploy Web ง่ายๆ ด้วย Nginx

## 📌 Overview
โปรเจคนี้สอนตั้งแต่:
- ติดตั้ง Docker
- สร้าง Web (HTML)
- สร้าง Docker Image
- Run Container
- Deploy Web บนเครื่องจริง

---

# 🧱 1. Install Docker

## 🔹 Linux (Ubuntu / Mint)

```bash
sudo apt update 
sudo apt install -y docker.io
```
อธิบาย
| คำสั่ง        | ความหมาย            |
| ------------- | ------------------- |
| `apt update`  | อัปเดต package list |
| `apt install` | ติดตั้ง package     |
| `-y`          | ตอบ yes อัตโนมัติ   |

### เปิดใช้งาน Docker
```bash
sudo systemctl start docker
sudo systemctl enable docker
```
อธิบาย
| คำสั่ง             | ความหมาย                       |
| ------------------ | ------------------------------ |
| `systemctl start`  | เริ่ม service                  |
| `systemctl enable` | ให้ start อัตโนมัติหลัง reboot |

### ตรวจสอบเวอร์ชัน
```bash
docker --version
```
อธิบาย
| ส่วน        | ความหมาย                   |
| ----------- | -------------------------- |
| `docker`    | program                    |
| `--version` | แสดงเวอร์ชัน (long option) |

👉 -- = option แบบเต็ม (อ่านง่าย เช่น --help, --version)

## 🔹 ใช้งาน Docker โดยไม่ต้อง sudo
```bash
sudo usermod -aG docker $USER
newgrp docker
```
อธิบาย
| option    | ความหมาย                      |
| --------- | ----------------------------- |
| `usermod` | แก้ไข user                    |
| `-a`      | append (เพิ่มโดยไม่ลบของเดิม) |
| `-G`      | ระบุ group                    |
| `docker`  | group ที่ให้สิทธิ์            |
| `$USER`   | user ปัจจุบัน                 |


# 📁 2. Create Project Structure
```bash
docker-web/
│
├── Dockerfile
└── web1/    
    └── html/
        └── index.html
└── web2/    
    └── html/
        └── index.html
```
อธิบาย
| ไฟล์         | หน้าที่         |
| ------------ | --------------- |
| `Dockerfile` | ใช้ build image |
| `html/`      | เก็บไฟล์ web    |
| `index.html` | หน้าเว็บ        |

## Command
```bash
mkdir docker-web
cd docker-web

mkdir web1, web2
mkdir web1/html, web2/html
touch html/index.html
touch Dockerfile
```
อธิบาย
| คำสั่ง  | ความหมาย       |
| ------- | -------------- |
| `mkdir` | สร้าง folder   |
| `cd`    | เข้า directory |
| `touch` | สร้างไฟล์เปล่า |


# 📝 3. Create HTML Page
ไฟล์: html/index.html
```HTML
<!DOCTYPE html>
<html>
<head>
  <title>My Web</title>
</head>
<body>
  <h1>Hello from Docker 🚀</h1>
</body>
</html>
```

# 🐳 4. Create Dockerfile
ไฟล์: Dockerfile
```Dockerfile
FROM nginx:latest

COPY html/index.html /usr/share/nginx/html/index.html
```
อธิบาย
| คำสั่ง         | ความหมาย                 |
| -------------- | ------------------------ |
| `FROM`         | base image               |
| `nginx:latest` | image + version          |
| `COPY`         | copy file เข้า container |


# 🔨 5. Build Docker Image
```bash
docker build -t myweb:v1 .
```
อธิบาย
| option     | ความหมาย             |
| ---------- | -------------------- |
| `build`    | สร้าง image          |
| `-t`       | tag (ตั้งชื่อ image) |
| `myweb:v1` | ชื่อ:version         |
| `.`        | current directory    |

# 📦 6. Run Container
```bash
docker run -d --name web -p 8080:80 myweb:v1
```
อธิบาย
| option    | ความหมาย                   |
| --------- | -------------------------- |
| `run`     | สร้าง + รัน container      |
| `-d`      | detached mode (background) |
| `--name`  | ตั้งชื่อ container         |
| `-p`      | port mapping               |
| `8080:80` | host:container             |

# 🌐 7. Access Web
```bash
http://localhost:8080
```
หรือ
```bash
http://<IP-Server>:8080
```
# 🔄 8. Volume (แก้ไขไฟล์สด)
```bash
docker run -d --name web -p 8080:80 -v $(pwd)/html:/usr/share/nginx/html nginx:latest
```
อธิบาย
| option   | ความหมาย           |
| -------- | ------------------ |
| `-v`     | volume             |
| `$(pwd)` | path ปัจจุบัน      |
| `:`      | แยก host:container |

# 🛑 9. Stop / Remove
```bash
docker stop web
docker rm web
```
อธิบาย
| คำสั่ง | ความหมาย       |
| ------ | -------------- |
| `stop` | หยุด container |
| `rm`   | ลบ container   |

# 📊 10. Useful Commands
```bash
docker ps
docker ps -a
docker logs web
docker exec -it web bash
```
อธิบาย
| คำสั่ง | ความหมาย                |
| ------ | ----------------------- |
| `ps`   | ดู container ที่รันอยู่ |
| `-a`   | ดูทั้งหมด               |
| `logs` | ดู log                  |
| `exec` | เข้า container          |
| `-it`  | interactive + terminal  |

# 🚀 11. Deploy (Production)
```bash
docker run -d --name web -p 80:80 --restart unless-stopped myweb:v1
```
อธิบาย
| option           | ความหมาย                  |
| ---------------- | ------------------------- |
| `--restart`      | restart อัตโนมัติ         |
| `unless-stopped` | restart ยกเว้นเราจะสั่งหยุด |

