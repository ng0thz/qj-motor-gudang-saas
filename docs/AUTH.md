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
| `mekanik` | Baca stok + WO | Tulis apa pun (read-only) |
| `ops_manager` | Semua di atas + approve opname + PO + hapus + kelola user | — |
| `direksi_readonly` | Baca laporan harian | Tulis apa pun |
| `super_admin` | Semua tenant (khusus developer/owner platform) | — |

Penegakan ganda: UI menyembunyikan/menolak aksi sensitif (mis. tombol Approve cek `canApprove`),
dan **Firestore Rules menolak di server** walau request dimanipulasi.

## Untuk developer

### 1. Aktifkan provider
Firebase Console → Authentication → Sign-in method → aktifkan **Email/Password**.

### 2. Buat user pertama (butuh service account, lokal saja)
```bash
cd app
npm i firebase-admin   # sekali saja
node tools/create_user.js ops@qjmotor.com Rahasia123 qj-motor ops_manager "Ops Manager"
node tools/create_user.js adi@qjmotor.com Rahasia123 qj-motor staff_gudang "Adi"
node tools/create_user.js frontdesk@qjmotor.com Rahasia123 qj-motor frontdesk "Frontdesk"
```
Script membuat user Auth + custom claims `{tenantId, role}` + dokumen `users/{uid}` (fallback bila claims belum refresh).

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

### 5. Batasan yang disadari
- Mekanik masih login anonymous + profil `users/{uid}` (PIN via Function belum dibuat).
- Belum ada App Check / 2FA / auto-lock; password policy ikut default Firebase.
- Token claims di-refresh saat login; bila role diubah admin, user harus logout-login ulang.
