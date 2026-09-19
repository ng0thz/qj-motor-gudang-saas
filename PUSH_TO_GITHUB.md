# PUSH KE GITHUB - Auto Build APK QJ Motor

**Tenant:** `qj-motor` - 4385 SKU - Production FREE - Firestore `gudang-saas-platform`

## Langkah (2 menit)

### 1. Buat Repo GitHub Baru
- Buka https://github.com/new
- Name: `qj-motor-gudang-saas`
- Private / Public → Create

### 2. Push dari Laptop (PowerShell)
```powershell
cd "C:\Users\Lenovo\Documents\sistem gudang\app"
git init
git add .
git commit -m "QJ Motor Production - 4385 SKU - stok 0"
git branch -M main
git remote add origin https://github.com/USERNAME/qj-motor-gudang-saas.git
git push -u origin main
```

### 3. Auto Build APK di Cloud
- Buka GitHub → Tab **Actions** → Workflow **Build APK QJ Motor** sedang jalan (3-5 menit)
- Selesai → Download **app-release-qj-motor.apk** di Artifacts
- Install di 6 HP QJ Motor (Staff Gudang 1 + Frontdesk 1 + Mekanik 4)

## File Sudah Siap
- `lib/features/stock/stock_page.dart` - Scan 05523M79K500 → Jual 19,003
- `lib/core/firebase_service.dart` - tenantId `qj-motor`
- `.github/workflows/build-apk.yml` - Auto build
- `firestore.rules` - isolasi tenant
- `data_import_classified.json` - 4385 SKU (sudah seed ke Firestore)

## Butuh google-services.json?
- Firebase Console → Project Settings → Your apps → Android → Download `google-services.json`
- Letakkan di `android/app/google-services.json` → commit → push lagi → auto build ulang

## Test Tanpa Build (Web)
```bash
flutter run -d chrome
# atau
firebase hosting:channel:deploy preview
```

---
**Setelah APK jadi:** Scan barcode `05523M79K500` di gudang 3.5×4m → stok 0 → isi real via scan fisik → VERIFIED
