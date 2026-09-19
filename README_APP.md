# APP SCAFFOLD - Gudang SaaS

**Lokasi:** `C:\Users\Lenovo\Documents\sistem gudang\app\`

## Struktur Plug n Play (Siap Develop)

```
lib/
├── core/
│   ├── firebase_service.dart      → tenantId + Firestore instance
│   ├── auth_service.dart          → Email/PIN + Custom Claim role
│   └── scanner_service.dart       → ML Kit wrapper
└── features/
    ├── stock/          → CORE: 500 SKU, IN/OUT, alamat A-02-04, Opname, Laporan
    │   ├── stock_model.dart
    │   ├── stock_repository.dart
    │   └── stock_page.dart
    ├── services/       → ADDON: WO Bengkel
    ├── nota/           → ADDON: Nota thermal
    ├── gudang_lanjutan/→ ADDON: Print label, Two-Bin, Forecast
    └── crm/            → ADDON: Follow-up Nopol
```

## Cara Develop (Butuh Flutter SDK)

1. Install Flutter: https://docs.flutter.dev/get-started/install/windows
2. Install Firebase CLI: `npm i -g firebase-tools`
3. Di folder `app`:
```bash
flutter pub get
flutterfire configure --project gudang-saas-platform
flutter run -d chrome
flutter build apk --release
```

## Tenant Test Data
- Part Code: `05523M79K500` → Retail 17120 + TAX 1883 = Jual 19003 (AX 180 VIENTO)
- Gudang: 3.5×4m, 2 Rak Silver Foto 1, Alamat A-02-04-M05
- Kapasitas: **3000 SKU Max** per tenant (batch import 500/batch)

## Kapasitas 3000 SKU
- Import: 6 batch × 500 (Firestore limit)
- List: Paginated 50 awal, search load 3000 ke memory (3MB) atau pakai Algolia jika lambat
- Free Tier: 3000 docs × 1KB = 3MB < 1GB, 3000 read sekali = 0.06 hari

## Next
- Isi `lib/features/stock/` dulu (MVP)
- Super Admin panel di `lib/core/admin_tenant.dart`

Lihat `../KONSEP_DEVELOP_SAAS.md` & `../ARCHITECTURE.md`
