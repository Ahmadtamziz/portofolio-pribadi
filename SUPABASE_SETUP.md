# Login Member & Moderasi Karya Supabase

Portal baru tersedia di `https://sobatkarya.my.id/member/` (setelah perubahan ter-deploy di Vercel). Pengunjung bisa melihat karya yang disetujui; member harus login untuk mengirim file; admin yang terdaftar mendapat antrean persetujuan.

## Setup Supabase satu kali
1. Buat project di Supabase, lalu buka **SQL Editor** dan jalankan isi `supabase/member-submissions.sql`.
2. Buka **Authentication > URL Configuration**. Atur Site URL ke `https://sobatkarya.my.id` (atau domain Vercel untuk uji coba) dan tambahkan URL redirect yang dipakai. Bila konfirmasi email aktif, gunakan tautan email untuk verifikasi.
3. Buka `member/index.html`, ganti `SUPABASE_URL` dan `SUPABASE_ANON_KEY` dengan Project URL dan **publishable/anon key** dari Project Settings > API. Nilai ini memang boleh ada di browser; **jangan pernah** taruh `service_role` / secret key di file HTML, GitHub, atau Vercel frontend.
4. Deploy commit ini ke Vercel. Pastikan root directory Vercel adalah root repository sehingga route `/member/` terlayani.
5. Daftarkan akun admin dengan email yang kamu kendalikan, verifikasi emailnya, lalu jalankan query di bagian terakhir file SQL dengan email tersebut. Admin tambahan hanya ditetapkan melalui SQL Dashboard.

## Yang disediakan
- Login email/password dan pendaftaran akun.
- Upload `.zip`, `.skill`, `.md` maksimal 10 MiB ke private bucket.
- Pengajuan dimulai berstatus `pending`; pengunjung hanya melihat metadata yang `approved`.
- Persetujuan/penolakan admin dilakukan server-side lewat RPC dan hanya akun pada `submission_admins` yang dapat melakukannya.
- Storage RLS membatasi unggah ke folder user sendiri. Karya yang disetujui diunduh menggunakan signed URL 60 detik.

Untuk memasang tautan dari beranda lama, tambahkan link `/member/` ke menu/section yang kamu inginkan. Jangan unggah file yang tidak aman untuk dibagikan: persetujuan hanya mengatur publikasi, bukan pemindaian malware.
