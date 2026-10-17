import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from '../scripts/serve.mjs';

test('preview serves only explicit public assets and rejects arbitrary local files', async () => {
  const server = createServer();
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const root = `http://127.0.0.1:${server.address().port}`;
  try {
    for (const path of ['/', '/web/style.css', '/web/app.mjs', '/engine.mjs', '/examples/harbor.mstory']) {
      const res = await fetch(root + path); assert.equal(res.status, 200, path); assert.match(res.headers.get('content-security-policy'), /object-src 'none'/);
    }
    for (const path of ['/moon.mod', '/.git/config', '/%2e%2e/.git/config', '/examples/../../LICENSE', '/work/moon/credentials.json']) assert.equal((await fetch(root + path)).status, 404, path);
    assert.equal((await fetch(root, { method: 'POST' })).status, 404);
    assert.equal((await fetch(root, { method: 'HEAD' })).status, 200);
  } finally { await new Promise(resolve => server.close(resolve)); }
});
