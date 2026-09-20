# Desktop (Web App) — Frontdesk & Operation Manager

## Konsep

Satu codebase Flutter → 2 keluaran:

| | Mobile (APK) | Desktop (Web) |
|---|---|---|
| Cara pakai | Install APK di HP | Buka URL di Chrome laptop/PC |
| Login | Sama (email+password) | Sama |
| Data | Sama (Firestore `qj-motor`) | Sama |
| Scan barcode | Kamera HP | Kamera laptop via browser (Chrome minta izin sekali) |
| Cocok untuk | Gudang, mekanik, keliling | Frontdesk (ketik cepat + layar lebar), OM (dashboard, laporan, verifikasi) |

## Status sekarang

- [x] Kode 100% kompatibel web (tidak ada plugin mobile-only).
- [x] CI otomatis build web tiap push (`build-web`, artifact `web-qj-motor`).
- [x] `firebase.json` sudah menunjuk Hosting ke `build/web`.
- [ ] **Sekali saja (laptop dev):** isi config Firebase asli → Web + APK jadi ONLINE.

## Aktivasi ONLINE (wajib sekali)

Tanpa ini app jalan tapi MODE OFFLINE (data lokal). Setelah ini, APK dan Web sama-sama online.

```bash
cd app
dart pub global activate flutterfire_cli
flutterfire configure --project=gudang-saas-platform
# pilih Android + Web saat ditanya → menghasilkan lib/firebase_options.dart (di-gitignore, tidak ikut commit)
```

Lalu di `lib/main.dart` ganti:
```dart
await Firebase.initializeApp();
```
menjadi:
```dart
import 'firebase_options.dart';
...
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```
Commit + push seperti biasa. `firebase_options.dart` tetap lokal (tidak bocor ke GitHub).

## Deploy Hosting (URL tetap untuk desktop)

Opsi A — otomatis via CI (disarankan):

1. Firebase Console → Project settings → Service accounts → Generate new private key
   (khusus CI, simpan baik-baik).
2. GitHub repo → Settings → Secrets → Actions → New secret
   `FIREBASE_SERVICE_ACCOUNT` = isi JSON tadi.
3. Push apa pun → job `build-web` otomatis deploy ke live channel.
4. URL: `https://gudang-saas-platform.web.app` (atau custom domain bila diset).

Opsi B — manual dari laptop:

```bash
cd app
flutter build web --release
firebase deploy --only hosting
```

## Catatan desktop

- Chrome di atas HTTP `localhost` atau HTTPS: kamera jalan. Hosting Firebase sudah HTTPS.
- Layout saat ini gaya mobile melebar penuh di layar besar — tetap fungsional.
  Polishing khusus desktop (tabel + panel ganda dashboard/laporan) adalah PR berikutnya bila diminta.
- Print label/nota: pakai dialog print browser (Ctrl+P) atau tombol PDF di app.
