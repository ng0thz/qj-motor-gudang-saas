const admin = require('firebase-admin');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.cert(serviceAccount)
});
const db = getFirestore();

async function seed() {
  const dataPath = path.join(__dirname, 'data_import_classified.json');
  const data = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
  // Sort prioritas ada harga dulu
  data.sort((a,b) => a.prioritas - b.prioritas || a.kode.localeCompare(b.kode));
  
  const tenantId = 'qj-motor'; // REAL PRODUCTION - QJ Motor
  console.log(`Tenant: ${tenantId} - REAL PRODUCTION QJ Motor`);
  console.log(`Total: ${data.length} (Ada Harga: ${data.filter(d=>d.prioritas===1).length}, Belum: ${data.filter(d=>d.prioritas===2).length})`);
  
  const batchSize = 500;
  let batch = db.batch();
  let count = 0;
  let batchNum = 1;
  let totalDone = 0;

  for (let i = 0; i < data.length; i++) {
    const r = data[i];
    const ref = db.collection('tenants').doc(tenantId).collection('spareparts').doc(r.kode);
    batch.set(ref, {
      tenantId: tenantId,
      kode: r.kode,
      nama: r.nama,
      motorType: r.motorType,
      barcode: r.kode,
      stok: 0,
      minStok: r.kategori_moving === 'FAST' ? 12 : (r.kategori_moving === 'SLOW' ? 3 : 5),
      alamat: '',
      rak: '',
      bin: '',
      kategori: r.kategori_moving,
      jenisPart: r.jenis_part,
      prioritas: r.prioritas,
      status: 'DRAFT',
      harga: {
        modal: Math.round(r.retail * 0.85),
        retail: r.retail,
        pajakPersen: 11,
        pajakRp: r.pajakRp,
        jual: r.jual
      },
      kompatibel: r.motorType.split('/').map(s=>s.trim()).filter(Boolean),
      substitusi: [],
      updatedAt: FieldValue.serverTimestamp()
    }, {merge: true});
    count++;

    if (count === batchSize || i === data.length - 1) {
      await batch.commit();
      totalDone += count;
      console.log(`Batch ${batchNum} committed: ${count} docs (total ${totalDone}/${data.length}) - ${r.kode}`);
      batch = db.batch();
      count = 0;
      batchNum++;
    }
  }
  console.log('SELESAI - 4385 SKU stok 0 DRAFT, cek real via scan HP');
  // Buat tenant doc
  await db.collection('tenants').doc(tenantId).set({
    nama: 'QJ Motor',
    brand: 'QJ Motor',
    paket: 'FREE', // Free langsung versi real production
    maxSKU: 5000,
    maxUser: 15,
    status: 'aktif',
    isRealProduction: true,
    createdAt: FieldValue.serverTimestamp()
  }, {merge:true});
  console.log('Tenant doc created');
}

seed().catch(e=>{ console.error(e); process.exit(1); });
