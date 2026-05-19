# Lab 05: Database Backup & Restore

ในแล็บนี้เราจะจำลองสถานการณ์จริง (Real-world Use Case) ในการสำรองข้อมูล (Backup) และกู้คืนข้อมูล (Restore) จากฐานข้อมูล PostgreSQL ที่รันอยู่ใน Docker Container

**ทำไมถึงใช้วิธีก๊อปปี้โฟลเดอร์ดิบๆ (Raw Volume) ไม่ได้?**
เพราะในขณะที่ฐานข้อมูลกำลังทำงานอยู่ ไฟล์อาจจะถูกเขียนไม่สมบูรณ์ หากก๊อปปี้ไฟล์ดื้อๆ ข้อมูลอาจจะพัง (Corrupted) ได้ วิธีที่ถูกต้องคือต้องใช้เครื่องมือของ Database เอง (เช่น `pg_dump`) ผ่านทาง `docker compose exec`

---

## สิ่งที่แล็บนี้ทำตาม CLAUDE.md

- ใช้ **`compose.yaml`** (v2 format) ไม่ใช่ `docker-compose.yaml`
- รหัสผ่าน DB เก็บใน **Docker secret** (`POSTGRES_PASSWORD_FILE`) ไม่ใช่ plaintext ใน ENV
- มี **`healthcheck`** บน service `db` ด้วย `pg_isready`
- **ไม่ expose port 5432** ออก host — ทุก operation ใช้ `docker compose exec` (ลด attack surface และไม่ชน Postgres ตัวอื่น)
- `restore.sh` ใช้ **`ON_ERROR_STOP=1` + `--single-transaction`** — restore เป็น atomic, error เมื่อไหร่ rollback ทั้งหมด ไม่ปล่อยให้ DB อยู่ใน state ครึ่งๆ กลางๆ

---

## ขั้นตอนการทำ Lab

### 0. Setup secret file (ครั้งแรกเท่านั้น)

ไฟล์ `secrets/db_password.txt` **ไม่ได้อยู่ใน repo** (อยู่ใน `.gitignore`) — copy จาก `.example`:

```bash
cp secrets/db_password.txt.example secrets/db_password.txt
# (optional) ตั้งรหัสจริง: openssl rand -base64 24 > secrets/db_password.txt
```

### 1. สตาร์ท Database
```bash
docker compose up -d
```

รอจน healthcheck ผ่าน (สถานะ `healthy`):
```bash
docker compose ps
```

### 2. ทดลองรันสคริปต์ Backup
```bash
bash backup.sh
```
*สังเกตว่าจะมีไฟล์ `backup_....sql` ถูกสร้างขึ้นในโฟลเดอร์ `backups/`*

### 3. จำลองเหตุการณ์ "ฐานข้อมูลพัง / ลบข้อมูลผิด"
```bash
docker compose exec db psql -U user -d mydatabase -c "DROP TABLE employees;"
```

### 4. กู้คืนข้อมูล (Restore)
```bash
# แก้ชื่อไฟล์ด้านล่างให้ตรงกับไฟล์ในโฟลเดอร์ backups/ ของคุณ
bash restore.sh backups/backup_YYYYMMDD_HHMMSS.sql
```

### 5. ตรวจสอบข้อมูล
```bash
docker compose exec db psql -U user -d mydatabase -c "SELECT * FROM employees;"
```
ควรเห็น Alice / Bob / Charlie กลับมาครบ 3 แถว

### 6. (Optional) ทดสอบว่า restore.sh ไม่หลอกว่าสำเร็จ
ลองรัน restore กับไฟล์ SQL ที่มี error:
```bash
echo "SELECT * FROM table_that_does_not_exist;" > /tmp/bad.sql
bash restore.sh /tmp/bad.sql
echo "exit code: $?"
```
จะเห็นว่า script **exit ด้วย non-zero** และไม่ print `✅` — ต่างจาก version เดิมที่อาจ print สำเร็จทั้งที่พัง

---

## 🧹 การทำความสะอาด (Cleanup)
```bash
docker compose down -v
rm -rf backups/ secrets/db_password.txt  # ลบเฉพาะถ้าไม่เก็บไว้ใช้รอบหน้า
```

---

## โครงสร้างไฟล์

| ไฟล์ | หน้าที่ |
|------|--------|
| `compose.yaml` | postgres:15-alpine + secret + healthcheck (ไม่ expose port) |
| `init.sql` | seed table `employees` ตอน container บูตครั้งแรก |
| `secrets/db_password.txt` | รหัสผ่าน DB (mount เป็น secret เข้า container) |
| `backup.sh` | เรียก `pg_dump --clean --if-exists` ผ่าน `docker compose exec -T` |
| `restore.sh` | pipe ไฟล์ SQL กลับเข้า `psql` แบบ atomic (`ON_ERROR_STOP=1 --single-transaction`) |
