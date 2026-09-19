// Seed Firestore dari Book2.csv - stok = 0 (tidak ambil dari Excel)
// Jalankan: node seed_firestore.js
// Butuh: npm i firebase-admin

const admin = require('firebase-admin');
const fs = require('fs');
const serviceAccount = require('./serviceAccountKey.json'); // download dari Firebase Console

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();

async function seed() {
  const data = JSON.parse(fs.readFileSync('./data_import.json', 'utf8'));
  const tenantId = 'demo-tenant-ax180'; // ganti dengan tenantId asli
  console.log(`Import ${data.length} SKU - stok 0 (DRAFT) - 9 batch`);

  let batch = db.batch();
  let count = 0;
  let batchNum = 1;

  for (let i = 0; i < data.length; i++) {
    const r = data[i];
    const ref = db.collection('tenants').doc(tenantId).collection('spareparts').doc(r.kode);
    batch.set(ref, {
      tenantId: tenantId,
      kode: r.kode,
      nama: r.nama,
      motorType: r.motorType,
      barcode: r.kode,
      stok: 0, // TIDAK AMBIL DARI EXCEL - cek real di gudang
      minStok: 5,
      alamat: '', // isi nanti saat scan fisik
      rak: '', bin: '',
      kategori: 'MEDIUM',
      harga: {
        modal: Math.round(r.retail * 0.85),
        retail: r.retail,
        pajakPersen: 11,
        pajakRp: r.pajakRp,
        jual: r.jual
      },
      substitusi: [],
      kompatibel: r.motorType.split('/').map(s=>s.trim()).filter(Boolean),
      status: 'DRAFT', // akan jadi VERIFIED setelah scan fisik
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, {merge: true});
    count++;

    if (count === 500 || i === data.length - 1) {
      await batch.commit();
      console.log(`Batch ${batchNum} committed (${count} docs)`);
      batch = db.batch();
      count = 0;
      batchNum++;
    }
  }
  console.log('Selesai - semua stok 0, cek real via scan HP di gudang');
}
seed().catch(console.error);
