// Deploy firestore.rules via Firebase Rules REST API.
// Jalankan: node tools/deploy_rules.js
const { GoogleAuth } = require('google-auth-library');
const fs = require('fs');
const path = require('path');

const PROJECT = 'gudang-saas-platform';
const BASE = 'https://firebaserules.googleapis.com/v1';

async function main() {
  const auth = new GoogleAuth({
    keyFile: path.join(__dirname, '..', 'serviceAccountKey.json'),
    scopes: ['https://www.googleapis.com/auth/cloud-platform'],
  });
  const client = await auth.getClient();
  const source = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');

  // 1. Buat ruleset baru
  const rs = (await client.request({
    url: `${BASE}/projects/${PROJECT}/rulesets`,
    method: 'POST',
    data: { source: { files: [{ name: 'firestore.rules', content: source }] } },
  })).data;
  console.log('Ruleset:', rs.name);

  // 2. Arahkan rilis cloud.firestore ke ruleset baru
  const relName = `projects/${PROJECT}/releases/cloud.firestore`;
  const rel = (await client.request({
    url: `${BASE}/${relName}`,
    method: 'PATCH',
    data: { release: { name: relName, rulesetName: rs.name } },
  })).data;
  console.log('RULES LIVE:', rel.rulesetName);
}

main().catch((e) => {
  console.error('RULES GAGAL:', e.response ? `${e.response.status} ${JSON.stringify(e.response.data).slice(0, 500)}` : e.message);
  process.exit(1);
});
