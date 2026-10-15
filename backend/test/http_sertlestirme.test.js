// 15 Eki güvenlik denetimi: API yanıtlarında HSTS (üretim), bozuk yüzde
// kodlaması 500 yerine 400 / yok sayılır.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { request } from 'node:http';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { config } = await import('../src/config.js');

let db, sunucu, port;
before(async () => {
  db = await testDb();
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  port = sunucu.address().port;
});
after(async () => { sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

// fetch bozuk yolları normalize ettiği için ham HTTP isteği.
const ham = (yol, basliklar = {}) => new Promise((ok, red) => {
  const r = request({ host: '127.0.0.1', port, path: yol, headers: basliklar }, (y) => {
    let g = ''; y.on('data', (p) => { g += p; }); y.on('end', () => ok({ durum: y.statusCode, basliklar: y.headers, govde: g }));
  });
  r.on('error', red); r.end();
});

test('HSTS yalnız Secure çerez ortamında (üretim) eklenir', async () => {
  const eski = config.cerezSecure;
  try {
    config.cerezSecure = false;
    assert.equal((await ham('/api/v1/legal')).basliklar['strict-transport-security'], undefined);
    config.cerezSecure = true;
    assert.match((await ham('/api/v1/legal')).basliklar['strict-transport-security'], /max-age=31536000/);
  } finally { config.cerezSecure = eski; }
});

test('bozuk yüzde kodlu yol parametresi 500 değil 400', async () => {
  const r = await ham('/api/v1/legal/%E0%A4%A');
  assert.equal(r.durum, 400, r.govde);
});

test('bozuk yüzde kodlu çerez isteği düşürmez', async () => {
  const r = await ham('/api/v1/legal', { Cookie: 'x=%E0%A4%A; y=1' });
  assert.equal(r.durum, 200, r.govde);
});
