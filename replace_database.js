// Replace database qj-motor dengan file baru - stok TIDAK diambil (tetap 0 / tetap real)
// Cara pakai:
// 1. Taruh file CSV baru di app/BookBaru.csv (format sama: Part Code;Part Name;Motor Type;Retail;TAX;Jual)
// 2. node replace_database.js BookBaru.csv --mode=update
// Mode:
//  --mode=update : update kode/nama/motor/harga saja, stok & alamat TETAP (aman, rekomendasi)
//  --mode=full   : hapus semua lalu isi ulang stok=0 (reset total)
const admin = require('firebase-admin');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const fs = require('fs');

const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({ credential: admin.cert(serviceAccount) });
const db = getFirestore();

const tenantId = 'qj-motor';
const csvFile = process.argv[2] || 'BookBaru.csv';
const mode = (process.argv.find(a=>a.startsWith('--mode=')) || '--mode=update').split('=')[1];

function parseCSV(path) {
  const text = fs.readFileSync(path, 'utf8').replace(/^\uFEFF/, '');
  const lines = text.split('\n').slice(2); // skip 2 header
  const rows = [];
  for (const line of lines) {
    if (!line.trim()) continue;
    const c = line.split(';');
    const kode = (c[0]||'').trim();
    if (!kode || kode === 'Part Code') continue;
    const nama = (c[1]||'').trim();
    const motor = (c[2]||'').trim();
    const retail = parseInt((c[3]||'').replace(/[^0-9]/g,'')) || 0;
    if (!nama && !retail) continue;
    rows.push({ kode, nama, motor, retail, pajakRp: Math.floor(retail*11/100), jual: retail + Math.floor(retail*11/100) });
  }
  return rows;
}

async function classify(nama) {
  const n = nama.toUpperCase();
  const fast = ['OIL','FILTER','SPARK PLUG','BRAKE','PAD ASSY','BELT','CHAIN','SPROCKET','CLAMP','GASKET','O RING','SEAL','BEARING','BOLT','NUT','WASHER','SCREW','CABLE'];
  if (fast.some(k=>n.includes(k))) return 'FAST';
  if (['CRANKSHAFT','CRANKCASE','CYLINDER','ENGINE','FRAME','FORK','SHOCK'].some(k=>n.includes(k))) return 'SLOW';
  return 'MEDIUM';
}

async function main() {
  console.log(`Tenant: ${tenantId} | File: ${csvFile} | Mode: ${mode}`);
  const rows = parseCSV(csvFile);
  console.log(`Parsed: ${rows.length} SKU (ada harga: ${rows.filter(r=>r.jual>0).length})`);

  if (mode === 'full') {
    console.log('Hapus semua spareparts lama...');
    const snap = await db.collection('tenants').doc(tenantId).collection('spareparts').get();
    let del = db.batch(); let n=0;
    for (const d of snap.docs) { del.delete(d.ref); n++; if(n>=400){await del.commit(); del=db.batch(); n=0;} }
    if(n>0) await del.commit();
    console.log(`Dihapus: ${snap.size} docs`);
  }

  let batch = db.batch(); let c=0; let done=0;
  // sort prioritas ada harga dulu
  rows.sort((a,b)=> (b.jual>0)-(a.jual>0) || a.kode.localeCompare(b.kode));
  for (const r of rows) {
    const ref = db.collection('tenants').doc(tenantId).collection('spareparts').doc(r.kode);
    const data = {
      tenantId, kode: r.kode, nama: r.nama, motorType: r.motor,
      barcode: r.kode,
      harga: { modal: Math.round(r.retail*0.85), retail: r.retail, pajakPersen: 11, pajakRp: r.pajakRp, jual: r.jual },
      kompatibel: r.motor.split('/').map(s=>s.trim()).filter(Boolean),
      kategori: await classify(r.nama),
      status: 'DRAFT',
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (mode === 'update') {
      batch.set(ref, data, {merge:true}); // stok & alamat tidak tersentuh
    } else {
      data.stok = 0; data.minStok = 5; data.alamat=''; data.rak=''; data.bin='';
      batch.set(ref, data, {merge:true});
    }
    c++; done++;
    if (c>=400) { await batch.commit(); console.log(`Batch ${done}/${rows.length}`); batch=db.batch(); c=0; }
  }
  if(c>0) await batch.commit();
  console.log(`SELESAI: ${done} SKU diupdate. Stok tidak diubah (mode update).`);
}
main().catch(e=>{console.error(e);process.exit(1);});
