// Replace Firestore qj-motor dengan Book3 (2596 SKU).
// - Upsert merge: kode/nama/motor/harga/kategori/jenis diupdate, STOK & alamat TETAP.
// - Hapus doc yang tidak ada di Book3.
// Jalankan: node replace_book3.js
const admin = require('firebase-admin');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const fs = require('fs');

const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({ credential: admin.cert(serviceAccount) });
const db = getFirestore();

const tenantId = 'qj-motor';

async function main() {
  const data = JSON.parse(fs.readFileSync('./data_import_classified.json', 'utf8'));
  console.log(`Book3 unik: ${data.length}`);
  const newCodes = new Set(data.map(r => r.kode));

  // Upsert (merge, stok tidak tersentuh)
  let batch = db.batch(); let c = 0; let done = 0;
  const sorted = [...data].sort((a, b) => (a.prioritas - b.prioritas) || a.kode.localeCompare(b.kode));
  for (const r of sorted) {
    const ref = db.collection('tenants').doc(tenantId).collection('spareparts').doc(r.kode);
    batch.set(ref, {
      tenantId, kode: r.kode, nama: r.nama, motorType: r.motorType,
      barcode: r.kode,
      harga: { modal: Math.round(r.retail * 0.85), retail: r.retail, pajakPersen: 11, pajakRp: r.pajakRp, jual: r.jual },
      kompatibel: r.motorType.split('/').map(s => s.trim()).filter(Boolean),
      kategori: r.kategori_moving, jenisPart: r.jenis_part,
      prioritas: r.prioritas, status: 'DRAFT',
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    c++; done++;
    if (c >= 400) { await batch.commit(); console.log(`Upsert ${done}/${sorted.length}`); batch = db.batch(); c = 0; }
  }
  if (c > 0) await batch.commit();
  console.log(`Upsert selesai: ${done}`);

  // Hapus yang tidak ada di Book3
  const snap = await db.collection('tenants').doc(tenantId).collection('spareparts').select().get();
  let del = db.batch(); let dc = 0; let deleted = 0;
  for (const d of snap.docs) {
    if (!newCodes.has(d.id)) {
      del.delete(d.ref); dc++; deleted++;
      if (dc >= 400) { await del.commit(); del = db.batch(); dc = 0; }
    }
  }
  if (dc > 0) await del.commit();
  console.log(`Dihapus (tidak ada di Book3): ${deleted}`);
  console.log(`Total di Firestore: ${snap.size - deleted + (sorted.length - (snap.size - deleted) < 0 ? 0 : 0)} (cek ulang di bawah)`);

  const verify = await db.collection('tenants').doc(tenantId).collection('spareparts').count().get();
  console.log(`Verifikasi count Firestore: ${verify.data().count}`);
}
main().catch(e => { console.error(e); process.exit(1); });
