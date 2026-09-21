# Login, Role & Security

## Cara login (user)

1. Buka app (online) → halaman Login QJ Motor.
2. Masukkan email + password yang dibuat Ops Manager.
3. App membaca `tenantId` + `role` dari akun → data otomatis dibatasi 1 tenant.
4. Keluar: tap ikon akun di kanan atas → **Keluar**. App kembali ke Login.
5. Tanpa internet / Firebase belum config: app masuk **mode offline** (baca data lokal, tanpa login).

## Role & hak akses

| Role | Bisa | Tidak bisa |
|---|---|---|
| `staff_gudang` | Stok IN/OUT/PINDAH, rak, barcode, harga, batch, opname hitung, WO, closing | Approve opname, hapus data, kelola user |
| `frontdesk` | WO + tracking + nota-ish, mutasi OUT, closing harian | Ubah master part, approve opname, PO |
| `kepala_mekanik` | WO + mutasi OUT + ikut opname hitung + baca laporan | Ubah master, approve opname, PO, kelola user |
| `admin_sales` | Booking PDI + baca WO/stok (HANYA PDI saat create) | WO servis, transaksi, master, laporan |
| `mekanik` | Baca stok + WO | Tulis apa pun (read-only) |
| `ops_manager` | Semua di atas + approve opname + PO + hapus + kelola user | — |
| `direksi_readonly` | Baca laporan harian | Tulis apa pun |
| `super_admin` | Semua tenant (khusus developer/owner platform) | — |

Penegakan ganda: UI menyembunyikan/menolak aksi sensitif (mis. tombol Approve cek `canApprove`),
dan **Firestore Rules menolak di server** walau request dimanipulasi.

## Untuk developer

### 1. Aktifkan provider
Firebase Console → Authentication → Sign-in method → aktifkan **Email/Password**.
Untuk tombol Google di web: aktifkan juga **Google** (tidak perlu SHA-1 untuk web).

### 2. Buat & kelola user — 2 cara

**Cara A — dari web app (disarankan, tanpa CLI):** login sebagai Ops Manager →
menu **Kelola User** → **Buat User** (nama, email, password awal, role).
Bisa juga: nonaktif/aktifkan, ganti role, kirim link reset password.
Tidak butuh Blaze/Functions: pembuatan memakai secondary Auth session,
hak akses dibaca Rules dari profil `users/{uid}` sebagai fallback claims.
Booting awal tetap butuh 1 akun ops pertama via Cara B.

**Cara B — via CLI (butuh service account, lokal saja)**
```bash
cd app
npm i firebase-admin   # sekali saja
node tools/create_user.js ops@qjmotor.com Rahasia123 qj-motor ops_manager "Ops Manager"
node tools/create_user.js adi@qjmotor.com Rahasia123 qj-motor staff_gudang "Adi"
node tools/create_user.js frontdesk@qjmotor.com Rahasia123 qj-motor frontdesk "Frontdesk"
```
Script membuat user Auth + custom claims `{tenantId, role}` + dokumen `users/{uid}` (fallback bila claims belum refresh).
Akun nonaktif: set `aktif=false` (dari web atau CLI) → login ditolak app DAN ditolak rules server.

### 3. Deploy rules
```bash
firebase deploy --only firestore:rules
```
File: `firestore.rules`. Cek path → user hanya bisa baca/tulis di `/tenants/{tenantId}` miliknya
(`sameTenant()`), kecuali `super_admin`. Field `tenantId` pada dokumen bersifat opsional
(dokumen lama tetap terbaca); semua create baru di app sudah menulisnya.

### 4. File rahasia (JANGAN di-commit, sudah di .gitignore)
- `serviceAccountKey.json` — hanya di laptop developer untuk script tools/seed.
- `android/app/google-services.json` — config Firebase Android.
- `lib/firebase_options.dart` — bila pakai flutterfire.

### 5. Login Google (khusus web)
Tombol "Masuk dengan Google" hanya tampil di web (`kIsWeb`), tidak di HP.
Syarat: email Google tersebut **sudah didaftarkan Ops** (ada `users/{uid}`),
kalau tidak login ditolak otomatis. Uid sama dengan akun email/password
bila emailnya sama → tenant & role ikut, tidak bentrok. Jangan ubah
pengaturan "one account per email" di Console.

### 6. Batasan yang disadari
- Mekanik masih login anonymous + profil `users/{uid}` (PIN via Function belum dibuat).
- Belum ada App Check / 2FA / auto-lock; password policy ikut default Firebase.
- Token claims di-refresh saat login; bila role diubah admin, user harus logout-login ulang.
- Tombol Google di APK butuh SHA-1 + `google-services.json` (PR pending) — sementara web saja.
