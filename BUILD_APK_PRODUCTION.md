# BUILD APK PRODUCTION - QJ Motor (REAL)

**Tenant:** `qj-motor` - 4385 SKU - FREE Production
**Firebase:** `gudang-saas-platform` - Firestore Production asia-southeast2

## Sudah Di-Set
- `lib/core/firebase_service.dart` → `effectiveTenantId = 'qj-motor'`
- Firestore: `tenants/qj-motor/spareparts/05523M79K500` (4385 docs, stok 0 DRAFT)
- Rules: `firestore.rules` isolasi tenantId (deploy manual di console)

## Cara Build APK (Butuh Flutter SDK)

### Di Laptop Dev (Windows):
1. Install Flutter: https://docs.flutter.dev/get-started/install/windows
   - Download → unzip `C:\src\flutter` → tambah ke PATH → `flutter doctor`

2. Install Firebase CLI:
```bash
npm i -g firebase-tools
firebase login
```

3. Build:
```bash
cd "C:\Users\Lenovo\Documents\sistem gudang\app"
flutter pub get
flutterfire configure --project gudang-saas-platform
# Pilih Android + Web

# Test di Chrome
flutter run -d chrome

# Build APK Production
flutter build apk --release --dart-define=TENANT_ID=qj-motor
# Hasil: build/app/outputs/flutter-apk/app-release.apk (15-20 MB)

# Build AppBundle untuk Play Store (opsional)
flutter build appbundle
```

4. Install di HP:
- Copy `app-release.apk` ke 6 HP (Staff Gudang 1 + Frontdesk 1 + Mekanik 4)
- Install → Login:
  - Staff Gudang: `adi@qj-motor.com` / PIN
  - Frontdesk: `frontdesk@qj-motor.com`
  - Mekanik: Scan QR `MEK-01` + PIN

5. Test Scan:
- Buka app → Tap Scan → Scan barcode `05523M79K500` → Tampil:
  ```
  LEFT SIDE CONNECTOR STICKER
  AX 180 (VIENTO) ABS
  Retail 17,120 + TAX 1,883 = Jual 19,003
  Stok 0 → Scan fisik isi 8 → Stok 0→8 VERIFIED
  Kategori: MEDIUM | Jenis: BODY
  ```

## Tanpa Flutter SDK (Alternatif)
- Pakai `flutter build web` → deploy ke Firebase Hosting:
```bash
flutter build web --release
firebase deploy --only hosting
# Akses: https://gudang-saas-platform.web.app (login qj-motor)
```

## File Siap
- `lib/features/stock/stock_page.dart` - Sudah support 3000+ SKU pagination
- `data_import_classified.json` - 4385 SKU siap offline
- `seed_firestore_classified.js` - Sudah seed 9 batch

## Next
- Pasang SOP A3 di pintu kaca Foto 1 (meja Staff Gudang)
- Training 1 jam: Scan → Nopol → Tap Terima
