// Buat user login + set tenant & role (custom claims) + profil users/{uid}.
// Jalankan dari folder app/:
//   node tools/create_user.js <email> <password> <tenantId> <role> [nama] [--telp=...] [--jabatan=...]
// Contoh: node tools/create_user.js adi@qjmotor.com Rahasia123 qj-motor staff_gudang "Adi" --telp=0812 --jabatan="Admin Gudang"
// Role: super_admin | ops_manager | staff_gudang | frontdesk | kepala_mekanik | mekanik | direksi_readonly
// Butuh: npm i firebase-admin, file serviceAccountKey.json (JANGAN di-commit, sudah di .gitignore).
const admin = require('firebase-admin');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const serviceAccount = require('../serviceAccountKey.json');
admin.initializeApp({ credential: admin.cert(serviceAccount) });

async function main() {
  const args = process.argv.slice(2);
  const opts = {};
  const rest = [];
  for (const a of args) {
    const m = a.match(/^--([^=]+)=(.*)$/);
    if (m) opts[m[1]] = m[2]; else rest.push(a);
  }
  const [email, password, tenantId, role, ...namaParts] = rest;
  const nama = namaParts.join(' ');
  if (!email || !password || !tenantId || !role) {
    console.error('Pakai: node tools/create_user.js <email> <password> <tenantId> <role> [nama]');
    process.exit(1);
  }
  const valid = ['super_admin', 'ops_manager', 'staff_gudang', 'frontdesk', 'kepala_mekanik', 'mekanik', 'admin_sales', 'direksi_readonly'];
  if (!valid.includes(role)) {
    console.error(`Role harus salah satu: ${valid.join(', ')}`);
    process.exit(1);
  }

  let user;
  try {
    user = await getAuth().createUser({ email, password, displayName: nama || email });
    console.log(`User dibuat: ${user.uid}`);
  } catch (e) {
    if (e.code === 'auth/email-already-exists') {
      user = await getAuth().getUserByEmail(email);
      console.log(`User sudah ada, pakai uid: ${user.uid}`);
      if (password) await getAuth().updateUser(user.uid, { password });
    } else {
      throw e;
    }
  }

  await getAuth().setCustomUserClaims(user.uid, { tenantId, role });
  await getFirestore().collection('users').doc(user.uid).set({
    email, tenantId, role, nama: nama || email,
    telp: opts.telp || '', jabatan: opts.jabatan || '', aktif: true,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  // Buat dokumen tenant bila belum ada
  await getFirestore().collection('tenants').doc(tenantId).set({
    nama: tenantId, status: 'aktif', updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log(`OK: ${email} -> tenant=${tenantId} role=${role}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
