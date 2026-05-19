# Lab 01: Cache Mounts

เป้าหมาย: เข้าใจว่า `--mount=type=cache` ทำหน้าที่อะไร ทำไมถึงต้องใช้ และดูผลลัพธ์เปรียบเทียบจริงๆ

---

## Cache mount คืออะไร?

โดย default Docker layer cache ทำงานในระดับ **layer ทั้งก้อน** — ถ้า input ของ `RUN` เปลี่ยน (เช่น `requirements.txt` ขยับ 1 บรรทัด) → layer นั้นถูก invalidate ทั้งก้อน → คำสั่ง `pip install` ต้อง **ดาวน์โหลด wheels ใหม่หมด** เพราะ cache ของ pip (`/root/.cache/pip`) ถูกทิ้งไปกับ layer เก่า

**Cache mount** เป็น feature ของ BuildKit ที่ mount โฟลเดอร์ขึ้นมาเฉพาะตอน `RUN` ทำงาน โดย **เนื้อหาใน mount นี้ไม่ถูกเก็บลง layer** แต่ persist ไว้ใน BuildKit cache แยกต่างหาก → build ครั้งถัดไป mount เดิมยังมีของอยู่

```dockerfile
# syntax=docker/dockerfile:1.7
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

**บรรทัด `# syntax=...`** สำคัญมาก — บอก BuildKit ว่าให้ใช้ frontend version ที่รองรับ feature นี้

---

## โครงสร้าง Lab

```
01-cache-mounts/
├── app/
│   ├── Dockerfile.no-cache   # traditional pip install --no-cache-dir
│   ├── Dockerfile.cache      # pip install + --mount=type=cache
│   ├── requirements.txt      # 10 packages รวม numpy/pandas/scikit-learn
│   └── app.py                # trivial — แค่ให้มีไฟล์ COPY
├── run-comparison.sh         # benchmark script
└── README.md
```

---

## ทดลอง

```bash
bash run-comparison.sh
```

Script จะทำ:
1. ลบ builder cache ทั้งหมด
2. Build ทั้งสอง Dockerfile (cold) — ดาวน์โหลดทุกอย่างจาก network
3. **ต่อท้าย comment ใน `requirements.txt`** → invalidate `RUN pip install` layer
4. Build อีกครั้ง (warm) แล้วเทียบเวลา

### ตัวอย่างผลลัพธ์บนเครื่อง dev (network ~100 Mbps)

```
Build #1 (cold):
  no-cache: ~40s
  cache:    ~50s   ← ช้ากว่าเล็กน้อย (overhead ของ cache mount initialization)

Build #2 (warm, layer invalidated):
  no-cache: ~34s   ← ดาวน์โหลด PyPI ใหม่ทั้งหมด
  cache:    ~32s   ← Using cached wheels จาก /root/.cache/pip
```

### ทำไม speedup ไม่ดราม่าเท่าที่คาด?

เพราะ **download ไม่ใช่ bottleneck เสมอไป** บนเครื่องนี้:
- network เร็ว → download numpy 17MB ใช้แค่ 1-2 วินาที
- bottleneck จริงคือ **unpack + install** wheels ขนาดใหญ่ (numpy, pandas, scikit-learn รวมกัน ~100MB unpacked)

**Cache mount ช่วยมากในกรณี:**
- 🌐 Network ช้า / มี latency สูง (CI runner ในบาง region, VPN, mobile tethering)
- 📦 มี packages เยอะมาก (Node.js npm install มักได้ 5-10x speedup)
- 🔁 มี dependency ที่ compile from source (Rust crates, C extensions)
- 💸 CI ที่จ่ายตาม minute → ลดเวลา = ลดเงิน

### หลักฐานว่า cache hit จริง

รัน build ตัว cache ด้วย verbose:
```bash
cd app
echo "# bump-$(date +%s)" >> requirements.txt
docker build -f Dockerfile.cache -t test:cache . --progress=plain 2>&1 | grep "Using cached"
```

จะเห็น pip บอก **"Using cached <package>.whl"** ทุก package — ยืนยันว่า wheels มาจาก cache mount ไม่ได้ดาวน์โหลดใหม่

---

## Sharing modes

```dockerfile
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked  ...
```

- `shared` (default) — หลาย build ใช้ cache เดียวกันได้พร้อมกัน เหมาะกับ read-heavy เช่น pip cache
- `locked` — lock ระหว่าง build ใช้กับ apt/dpkg ที่ไม่ทน concurrent write
- `private` — แต่ละ build มี cache ของตัวเอง

---

## ⚠️ ข้อระวัง

- Cache mount เก็บ data ที่ host **ไม่ติดไปกับ image** → ถ้า build บนเครื่องอื่น cache ไม่มีตามไป (ยกเว้นใช้ `--cache-to=type=registry` ส่งขึ้น registry)
- ลบ cache: `docker buildx prune --filter type=exec.cachemount`

---

## 🧹 Cleanup
```bash
docker rmi lab-buildkit-nocache:test lab-buildkit-cache:test
docker buildx prune -f
```
