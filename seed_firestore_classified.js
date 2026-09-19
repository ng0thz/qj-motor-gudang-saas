// Seed Firestore Classified - 4385 SKU - Prioritas Ada Harga Dulu, Stok 0
// File sumber: data_import_classified.json (sudah ada kategori_moving & jenis_part)
// Jalankan: node seed_firestore_classified.js

const fs = require('fs');
// const admin = require('firebase-admin');
// const serviceAccount = require('./serviceAccountKey.json');
// admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
// const db = admin.firestore();

// Untuk demo tanpa Firebase, simulasi batch
const data = JSON.parse(fs.readFileSync('C:\\Users\\Lenovo\\Documents\\sistem gudang\\app\\data_import_classified.json', 'utf8'));

// Sort prioritas: ada harga (1) dulu, lalu kode
data.sort((a,b) => a.prioritas - b.prioritas || a.kode.localeCompare(b.kode));

console.log(`Total: ${data.length}`);
console.log(`Ada Harga (prioritas 1): ${data.filter(d=>d.prioritas===1).length}`);
console.log(`Belum Ada Harga (2): ${data.filter(d=>d.prioritas===2).length}`);

const moving = {};
const jenis = {};
data.forEach(d=>{
  moving[d.kategori_moving] = (moving[d.kategori_moving]||0)+1;
  jenis[d.jenis_part] = (jenis[d.jenis_part]||0)+1;
});
console.log('Moving:', moving);
console.log('Jenis:', jenis);

// Simulasi import 9 batch x 500
const batchSize = 500;
const batches = Math.ceil(data.length / batchSize);
console.log(`\nAkan import ${batches} batch x 500 (stok=0, status=DRAFT)`);
for(let i=0;i<batches;i++){
  const chunk = data.slice(i*batchSize, (i+1)*batchSize);
  console.log(`Batch ${i+1}: ${chunk[0].kode} .. ${chunk[chunk.length-1].kode} (${chunk.length} docs) - stok 0`);
}

console.log('\nContoh dokumen Firestore:');
console.log(JSON.stringify({
  tenantId: 'demo-tenant-ax180',
  kode: data[0].kode,
  nama: data[0].nama,
  motorType: data[0].motorType,
  barcode: data[0].kode,
  stok: 0,
  minStok: data[0].kategori_moving==='FAST'?12:5,
  alamat: '',
  kategori: data[0].kategori_moving,
  jenisPart: data[0].jenis_part,
  prioritas: data[0].prioritas,
  status: 'DRAFT',
  harga: { retail: data[0].retail, pajakPersen:11, pajakRp: data[0].pajakRp, jual: data[0].jual }
}, null, 2));

console.log('\nSiap seed ke Firestore - stok tetap 0, cek real via scan HP di gudang 3.5x4m');
