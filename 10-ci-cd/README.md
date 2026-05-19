# Module 10: CI/CD Integration

นี่คือปลายทางสุดท้ายของการนำ Docker ไปใช้งานจริง!
ใน Module นี้เราจะเรียนรู้วิธีการทำระบบอัตโนมัติ (Automated Pipeline) เพื่อให้คอมพิวเตอร์เป็นคน Build และแจกจ่าย Image ให้เราแทนการพิมพ์คำสั่งเองทีละบรรทัด

## ภาพรวมของ CI/CD สำหรับ Docker

กระบวนการ (Pipeline) ปกติจะมีลำดับดังนี้:
1. **Code Commit:** โปรแกรมเมอร์เขียนโค้ดและ Push ขึ้น Git
2. **Lint/Test:** รันเทสต์เบื้องต้น
3. **Build:** ระบบนำ Dockerfile ไปสั่ง `docker build` เป็น Image
4. **Push:** ระบบล็อกอินและ `docker push` ไปเก็บไว้ใน Registry (เช่น Docker Hub หรือ Private Registry)
5. **Deploy:** นำ Image ตัวใหม่ไปอัปเดตบน Server

## Labs ในหมวดนี้

1. **`00-dind-dood/`** — ทฤษฎีพื้นฐาน ว่าระบบ CI (ที่เป็น Container) สั่งรันคำสั่ง Docker ได้อย่างไร
2. **`01-github-actions/`** — ตัวอย่างการเซ็ตอัพ Pipeline ฟรีบน GitHub
3. **`02-gitlab-ci/`** — ตัวอย่างการเซ็ตอัพ Pipeline บน GitLab พร้อม Registry ฟรีในตัว
