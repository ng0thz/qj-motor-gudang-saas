// Deploy build/web ke Firebase Hosting via REST API (tanpa firebase-tools,
// tanpa cek serviceusage yang ditolak untuk SA ini).
// Jalankan: node tools/deploy_hosting.js
const { GoogleAuth } = require('google-auth-library');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PROJECT = 'gudang-saas-platform';
const SITE = 'gudang-saas-platform';
const DIR = path.join(__dirname, '..', 'build', 'web');
const BASE = 'https://firebasehosting.googleapis.com/v1beta1';

function walk(dir, base = '') {
  const out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const rel = base ? `${base}/${e.name}` : e.name;
    if (e.isDirectory()) out.push(...walk(path.join(dir, e.name), rel));
    else out.push(rel);
  }
  return out;
}

async function main() {
  const auth = new GoogleAuth({
    keyFile: path.join(__dirname, '..', 'serviceAccountKey.json'),
    scopes: ['https://www.googleapis.com/auth/cloud-platform'],
  });
  const client = await auth.getClient();
  const token = async () => {
    const t = await client.getAccessToken();
    return t.token || t;
  };
  const req = (opts) => client.request(opts);

  const files = walk(DIR);
  console.log(`File: ${files.length}`);
  const hashes = {};   // path -> sha256 dari ISI GZIP (sesuai firebase-tools)
  const gzipped = {};  // path -> Buffer gzip
  for (const f of files) {
    const buf = require('zlib').gzipSync(
      fs.readFileSync(path.join(DIR, ...f.split('/'))), { level: 9 });
    gzipped['/' + f] = buf;
    hashes['/' + f] = crypto.createHash('sha256').update(buf).digest('hex');
  }

  // 1. Buat version
  const ver = (await req({
    url: `${BASE}/projects/${PROJECT}/sites/${SITE}/versions`,
    method: 'POST', data: { config: {} },
  })).data;
  const versionName = ver.name;
  console.log('Version:', versionName);

  // 2. Minta URL upload (uploadUrl = SATU base URL, uploadRequiredHashes = daftar hash)
  const pop = (await req({
    url: `${BASE}/${versionName}:populateFiles`,
    method: 'POST', data: { files: hashes },
  })).data;

  // 3. Upload tiap hash yang diminta ke {uploadUrl}/{hash}
  const byHash = {};
  for (const [p, h] of Object.entries(hashes)) byHash[h] = p;
  const needed = pop.uploadRequiredHashes || [];
  console.log(`Upload: ${needed.length} file`);
  for (const h of needed) {
    await req({
      url: `${pop.uploadUrl}/${h}`, method: 'POST',
      headers: { 'Content-Type': 'application/octet-stream' },
      data: gzipped[byHash[h]],
    }).catch((e) => {
      throw new Error(`upload ${byHash[h]} -> ${e.response ? e.response.status + ' ' + JSON.stringify(e.response.data).slice(0, 200) : e.message}`);
    });
  }

  // 4. Finalize
  await req({
    url: `${BASE}/${versionName}`, method: 'PATCH',
    params: { updateMask: 'status' }, data: { status: 'FINALIZED' },
  });
  console.log('Finalized');

  // 5. Release ke live
  const rel = (await req({
    url: `${BASE}/projects/-/sites/${SITE}/channels/live/releases`,
    method: 'POST', params: { versionName },
    data: {},
  })).data;
  console.log('LIVE:', rel.release && rel.release.version ? JSON.stringify(rel.release.version) : JSON.stringify(rel).slice(0, 200));
  console.log('URL: https://gudang-saas-platform.web.app');
}

main().catch((e) => {
  console.error('DEPLOY GAGAL:', e.response ? `${e.response.status} ${JSON.stringify(e.response.data).slice(0, 500)}` : e.message);
  process.exit(1);
});
