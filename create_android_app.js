const { GoogleAuth } = require('google-auth-library');
const fs = require('fs');

async function main() {
  const keyPath = './serviceAccountKey.json';
  const auth = new GoogleAuth({
    keyFile: keyPath,
    scopes: ['https://www.googleapis.com/auth/firebase', 'https://www.googleapis.com/auth/cloud-platform']
  });
  const client = await auth.getClient();
  const token = await client.getAccessToken();
  console.log('Token acquired');

  const projectId = 'gudang-saas-platform';
  const packageName = 'com.qjmotor.saas.gudang_saas';
  const displayName = 'QJ Motor Gudang';

  // Check existing apps
  let res = await client.request({ url: `https://firebase.googleapis.com/v1beta1/projects/${projectId}/androidApps`, method: 'GET' });
  console.log('Existing apps:', JSON.stringify(res.data, null, 2));
  
  const existing = (res.data.apps || []).find(a => a.packageName === packageName);
  if (existing) {
    console.log('App already exists:', existing.name);
    // Get config
    const cfg = await client.request({ url: `https://firebase.googleapis.com/v1beta1/${existing.name}/config`, method: 'GET' });
    fs.writeFileSync('./android/app/google-services.json', Buffer.from(cfg.data.configFilename ? '' : JSON.stringify(cfg.data, null, 2)));
    // Actually config is base64
    if (cfg.data.configFileContents) {
      fs.writeFileSync('./android/app/google-services.json', Buffer.from(cfg.data.configFileContents, 'base64'));
      console.log('Downloaded google-services.json');
    } else {
      console.log('Config response:', JSON.stringify(cfg.data, null, 2));
    }
    return;
  }

  // Create new Android app
  console.log('Creating Android app...');
  res = await client.request({
    url: `https://firebase.googleapis.com/v1beta1/projects/${projectId}/androidApps`,
    method: 'POST',
    data: {
      packageName: packageName,
      displayName: displayName
    }
  });
  console.log('Create response:', JSON.stringify(res.data, null, 2));
  
  // Wait for operation
  const opName = res.data.name;
  let op;
  for(let i=0;i<10;i++){
    await new Promise(r=>setTimeout(r,2000));
    const opRes = await client.request({ url: `https://firebase.googleapis.com/v1beta1/${opName}`, method: 'GET' });
    op = opRes.data;
    console.log(`Op status: ${op.done}`);
    if(op.done) break;
  }
  
  if(op && op.response) {
    const appName = op.response.name;
    console.log('App created:', appName);
    const cfg = await client.request({ url: `https://firebase.googleapis.com/v1beta1/${appName}/config`, method: 'GET' });
    if (cfg.data.configFileContents) {
      fs.mkdirSync('./android/app', {recursive:true});
      fs.writeFileSync('./android/app/google-services.json', Buffer.from(cfg.data.configFileContents, 'base64'));
      console.log('Downloaded google-services.json to android/app/');
    }
  }
}

main().catch(e=>{ console.error(e.response ? JSON.stringify(e.response.data,null,2) : e); process.exit(1); });
