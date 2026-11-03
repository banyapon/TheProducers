const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const exported = {};
vm.runInNewContext(fs.readFileSync(__dirname + '/index.js', 'utf8'), {
  exports: exported,
  require: name => {
    if (name === 'firebase-functions/v2/https') return { onRequest: (_, handler) => handler };
    if (name === 'firebase-functions/params') return { defineSecret: () => ({ value: () => 'test-secret' }), defineString: () => ({ value: () => 'test-key' }) };
    if (name === 'firebase-admin') return { initializeApp() {}, auth: () => ({ verifyIdToken: async () => ({ uid: 'owner' }) }) };
    return require(name);
  }
});
async function request(operation, params) {
  const res = { code: 200, status(n) { this.code = n; return this; }, json(data) { this.data = data; return this; } };
  await exported.signCloudinaryUpload({ method: 'POST', get: () => 'Bearer test', body: { operation, params: { timestamp: Math.floor(Date.now() / 1000), ...params } } }, res);
  return res;
}
(async () => {
  assert.equal((await request('destroy', { public_id: 'the_producers/owner/songs/song', invalidate: 'true' })).code, 200);
  assert.equal((await request('destroy', { public_id: 'the_producers/other/songs/song' })).code, 403);
  assert.equal((await request('destroy', { public_id: 'the_producers/owner/../other/song' })).code, 403);
  assert.equal((await request('destroy', { public_id: 'the_producers/owner/songs/song', folder: 'x' })).code, 400);
  assert.equal((await request('upload', { folder: 'the_producers/owner/history', public_id: 'history.json' })).code, 200);
  console.log('RESET SIGNING: 5 checks passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
