# คู่มือติดตั้ง Docker CE บน Linux Mint / Ubuntu

## ข้อมูล Environment

| รายการ | รายละเอียด |
|--------|-----------|
| OS | Linux Mint 22.3 (Zena) — Ubuntu 24.04 Noble base |
| Docker CE | 29.5.0 |
| Docker Compose | v5.1.3 (plugin) |
| Docker Buildx | v0.34.0 |
| containerd | v2.2.3 |

---

## ทำไมต้องใช้ Docker CE ไม่ใช่ docker.io

| | `docker.io` (Ubuntu repo) | `docker-ce` (Official repo) |
|--|--|--|
| ที่มา | Ubuntu/Mint packagers | Docker Inc. |
| อัปเดต | ช้า (sync ตาม Ubuntu release) | เร็ว (ออกตาม Docker release) |
| Version | 29.1.3 | **29.5.0** |
| Compose | ต้องติดตั้งแยก | รวมเป็น plugin |
| Buildx | ต้องติดตั้งแยก | รวมเป็น plugin |
| แนะนำ | ไม่แนะนำ | ✅ แนะนำ |

---

## Package ที่ติดตั้ง

```
docker-ce                  — Docker daemon + CLI
docker-ce-cli              — Docker CLI
containerd.io              — Container runtime
docker-buildx-plugin       — Multi-arch build, BuildKit
docker-compose-plugin      — Docker Compose v2 (ใช้ผ่าน docker compose)
docker-ce-rootless-extras  — Rootless mode support
```

---

## วิธีติดตั้งทีละขั้น (Manual)

### ขั้นที่ 1 — ลบ Docker เก่า (ถ้ามี)

```bash
sudo apt-get remove -y \
    docker docker-engine docker.io \
    containerd runc docker-compose
```

### ขั้นที่ 2 — ติดตั้ง prerequisites

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
```

### ขั้นที่ 3 — เพิ่ม Docker GPG key

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

> **สำคัญสำหรับ Linux Mint:** ต้องใช้ Ubuntu codename (`noble`) ไม่ใช่ Mint codename (`zena`)

### ขั้นที่ 4 — เพิ่ม Docker repository

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
noble stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### ขั้นที่ 5 — ติดตั้ง Docker CE

```bash
sudo apt-get update
sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
```

### ขั้นที่ 6 — เปิด service

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

### ขั้นที่ 7 — เพิ่ม user เข้า docker group

```bash
sudo usermod -aG docker $USER
```

> หลังจากนี้ต้อง logout/login ใหม่ หรือรัน `newgrp docker` เพื่อให้ group มีผล หรือ reboot

### ขั้นที่ 8 — ทดสอบ

```bash
docker run --rm hello-world
docker compose version
docker buildx version
```

---

## ใช้ script ติดตั้งอัตโนมัติ

```bash
sudo bash install-docker.sh
```

Script จะทำทุกขั้นตอนด้านบนโดยอัตโนมัติ พร้อม color output แสดงสถานะแต่ละ step

---

## หลังติดตั้ง — ใช้งาน Docker โดยไม่ต้องพิมพ์ sudo

หลัง logout/login ใหม่ หรือรัน `newgrp docker` แล้ว:

```bash
# ทดสอบไม่ต้องมี sudo
docker run --rm alpine echo "ทำงานได้โดยไม่ต้อง sudo"

# ดู version ทั้งหมด
docker version
docker compose version
docker buildx version

# ดูข้อมูล daemon
docker info
```

---

## ตรวจสอบสถานะ Docker service

```bash
# ดู status
sudo systemctl status docker

# ดู logs ของ daemon
sudo journalctl -u docker --since "1 hour ago"

# ดู socket
ls -la /var/run/docker.sock
```

---

## Uninstall (ถ้าต้องการถอน)

> **หมายเหตุ:** คำสั่ง uninstall ต้องรันใน terminal จริงเท่านั้น — ไม่สามารถรันผ่าน Claude Code ได้เพราะ `sudo` ต้องการ interactive terminal อ่านรหัสผ่าน
> ถ้าใช้ Claude Code ให้พิมพ์ `!` นำหน้าคำสั่ง เช่น `! sudo apt-get purge ...`

```bash
# ลบ packages
sudo apt-get purge -y \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin \
    docker-ce-rootless-extras

# ลบ data (ระวัง: ลบ images/containers/volumes ทั้งหมด)
sudo rm -rf /var/lib/docker /var/lib/containerd

# ลบ repo และ key
sudo rm /etc/apt/sources.list.d/docker.list
sudo rm /etc/apt/keyrings/docker.gpg

# ลบ packages ที่ไม่ใช้แล้ว
sudo apt-get autoremove -y
```

---

## Gotchas สำหรับ Linux Mint

1. **ห้ามใช้ Mint codename** ใน Docker repo — ต้องใช้ Ubuntu codename (`noble` สำหรับ Mint 22)
2. **`docker compose`** (มี space) คือ plugin version ใหม่, ต่างจาก `docker-compose` (มี dash) ซึ่งเป็น standalone เก่า
3. หลัง `usermod -aG docker` ต้อง re-login จริงๆ — `sudo` ก็ไม่พอ group จะยังไม่ถูก apply
