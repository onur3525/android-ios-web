// CORS: yalnız izin listesindeki tam köken; '*' yok; admin yolları kapsam dışı.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
process.env.HC_SESSIZ = '1';
process.env.HC_CORS_ORIGINS = 'https://hizmetcep.com';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
let db, sunucu, taban;
before(async () => {
  db = await testDb();
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => { sunucu?.close(); await db?.close(); });

test('izinli köken: ön kontrol 204 + izinler, gerçek istekte köken yansıtılır', async () => {
  const on = await fetch(taban + '/api/v1/categories', { method: 'OPTIONS', headers: { Origin: 'https://hizmetcep.com', 'Access-Control-Request-Method': 'POST' } });
  assert.equal(on.status, 204);
  assert.equal(on.headers.get('access-control-allow-origin'), 'https://hizmetcep.com');
  assert.match(on.headers.get('access-control-allow-headers'), /Authorization/);
  assert.match(on.headers.get('access-control-allow-headers'), /Idempotency-Key/);
  assert.equal(on.headers.get('access-control-allow-credentials'), null);
  const g = await fetch(taban + '/api/v1/categories', { headers: { Origin: 'https://hizmetcep.com' } });
  assert.equal(g.status, 200);
  assert.equal(g.headers.get('access-control-allow-origin'), 'https://hizmetcep.com');
  assert.match(g.headers.get('vary') ?? '', /Origin/);
});

test('izinsiz köken ve admin yolu: CORS başlığı YOK', async () => {
  for (const o of ['https://kotu.example', 'https://onur3525.github.io', 'null']) {
    const r = await fetch(taban + '/api/v1/categories', { headers: { Origin: o } });
    assert.equal(r.headers.get('access-control-allow-origin'), null, o);
  }
  const on = await fetch(taban + '/api/v1/categories', { method: 'OPTIONS', headers: { Origin: 'https://kotu.example' } });
  assert.equal(on.headers.get('access-control-allow-origin'), null);
  const a = await fetch(taban + '/admin/v1/auth/me', { headers: { Origin: 'https://hizmetcep.com' } });
  assert.equal(a.headers.get('access-control-allow-origin'), null);
});

test('kökensiz istekler (mobil uygulama) aynen çalışır', async () => {
  const r = await fetch(taban + '/api/v1/categories');
  assert.equal(r.status, 200);
  assert.equal(r.headers.get('access-control-allow-origin'), null);
});
