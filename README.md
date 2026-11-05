# SRINAM Beauty Salon — เว็บจองคิวพร้อมหลังบ้าน

เว็บ React + Vite + Supabase + Vercel รองรับมือถือ ระบบจองคิวรอยืนยัน และผู้ดูแลอนุมัติ/ยกเลิกคิว

## 1. สร้าง Supabase

1. ไปที่ https://supabase.com/dashboard → **New project** → ตั้งชื่อ `srinam-beauty` และรอสร้างเสร็จ
2. ไปที่ **SQL Editor** → New query → คัดลอกเนื้อหาทั้งหมดใน `supabase/schema.sql` → Run
3. ไปที่ **Authentication → Users → Add user** สร้างผู้ดูแลด้วยอีเมลและรหัสผ่านที่แข็งแรง เลือกยืนยันอีเมลให้เรียบร้อย (หรือใช้ flow ที่ระบบแนะนำ)
4. กลับไป SQL Editor แล้วรันคำสั่งด้านล่างโดยเปลี่ยนอีเมลเป็นบัญชีที่สร้าง:

```sql
insert into public.admins(user_id)
select id from auth.users where email = 'your-email@example.com'
on conflict do nothing;
```

5. ไปที่ **Project Settings → API Keys** (หรือ **Connect**) นำ **Project URL** และ **publishable key** (หรือ legacy `anon` key) มาใช้ **ห้ามใช้ `service_role` หรือ secret key ในเว็บ**

## 2. ทดลองในคอมพิวเตอร์

ติดตั้ง Node.js รุ่น LTS จาก https://nodejs.org/ และแตก ZIP นี้ จากนั้นเปิด Terminal ในโฟลเดอร์โปรเจกต์

```bash
npm install
cp .env.example .env
```

เปิดไฟล์ `.env` แล้วกรอก `VITE_SUPABASE_URL` และ `VITE_SUPABASE_ANON_KEY` จากขั้นตอน 1 จากนั้นรัน:

```bash
npm run dev
```

เปิดลิงก์ที่ Terminal แสดง (ปกติ http://localhost:5173)

## 3. นำขึ้น GitHub และ Vercel

1. สมัคร/เข้าสู่ระบบ https://github.com → สร้าง repository แบบ **Private** ชื่อ `srinam-beauty`
2. อัปโหลดไฟล์และโฟลเดอร์จาก ZIP นี้เข้า repository โดย **อย่าอัปโหลด `.env`, รหัสผ่าน หรือ secret key**
3. ไปที่ https://vercel.com/new → เชื่อม GitHub → Import `srinam-beauty`
4. Framework preset: **Vite**; Build Command: `npm run build`; Output Directory: `dist`
5. ใน **Environment Variables** เพิ่ม `VITE_SUPABASE_URL` และ `VITE_SUPABASE_ANON_KEY` ด้วยค่าจริงจาก Supabase (สำหรับ Production; เพิ่ม Preview ถ้าต้องการ)
6. กด **Deploy** → จะได้ URL เช่น `srinam-beauty.vercel.app` (ชื่อจริงขึ้นกับชื่อที่ว่าง)
7. ไปทดสอบจองคิวจากมือถือ และเปิดเมนู **หลังบ้าน** เพื่อเข้าสู่ระบบผู้ดูแล
8. หากแก้ Environment Variables หลัง Deploy ให้ **Redeploy** อีกครั้ง

## ข้อมูลสำคัญ

- เวลาอ้างอิง **Asia/Bangkok** ร้านเปิดจันทร์–เสาร์ 09:00–19:00 ปิดอาทิตย์ จองล่วงหน้าได้ 60 วัน
- บริการและระยะเวลาตัวอย่างแก้ไขราคา/ระยะเวลา/เปิดปิดบริการได้จากหลังบ้าน
- ทุกคำขอเริ่มที่ `pending`; ผู้ดูแลกด `confirmed` หรือ `cancelled`
- ช่วงเวลาคิวที่ `pending` และ `confirmed` จะถูกกันไว้ด้วย PostgreSQL exclusion constraint ป้องกันจองทับซ้อนแม้มีหลายคนจองพร้อมกัน
- ลูกค้าจะได้รับเลขอ้างอิงหลังส่งคำขอ แต่ **ยังไม่มีระบบส่ง SMS/LINE/อีเมล หรือหน้าติดตามสถานะด้วยเลขอ้างอิง** ต้องเพิ่มก่อนใช้ในร้านที่ต้องการแจ้งผลอัตโนมัติ
- ข้อมูลลูกค้าไม่เปิดให้อ่านสาธารณะ; หลังบ้านอ่านได้เฉพาะผู้ดูแลที่กำหนดใน `admins`
- ยังไม่มี CAPTCHA/rate limiting ต่อผู้ใช้ ควรเปิดการป้องกัน abuse ที่ edge หรือเพิ่ม CAPTCHA ก่อนโปรโมตเว็บไซต์สู่สาธารณะ
- หลังบ้านไม่มีการสร้างบัญชีผู้ดูแลจากหน้าเว็บ ต้องสร้างบัญชีใน Supabase ด้วยตนเอง
- ภาพหน้าแรกเป็นภาพจาก Unsplash ผ่าน URL ภายนอก ควรเปลี่ยนเป็นภาพร้านจริงก่อนเปิดใช้
- ตรวจสอบประกาศความเป็นส่วนตัวและการขอความยินยอมตามกฎหมายที่เกี่ยวข้องก่อนเก็บข้อมูลลูกค้าจริง

## ตรวจสอบก่อนเปิดร้าน

- [ ] ตั้งอีเมลผู้ดูแลใน `admins` ถูกต้อง
- [ ] ทดสอบจอง 1 คิว และยืนยันจากหลังบ้าน
- [ ] ทดสอบจองช่วงเวลาซ้ำแล้วถูกปฏิเสธ
- [ ] ทดสอบวันอาทิตย์และช่วงเวลานอกเวลาทำการ
- [ ] เปลี่ยนรูป โลโก้ ราคา โปรโมชั่น และรายละเอียดร้านให้ตรงกับข้อมูลจริง
- [ ] จัดเตรียมวิธีแจ้งลูกค้าเมื่อคิวยืนยัน (ปัจจุบันต้องติดต่อเอง)
- [ ] เพิ่มนโยบายความเป็นส่วนตัวและมาตรการป้องกันสแปม
