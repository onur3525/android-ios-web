// Geçici IP teşhisi (/teshis/ip) — HC_TRUST_PROXY_HOPS'u ÖLÇEREK belirlemek için.
// Kapalıyken uç yoktur; açıkken yalnız isteği yapanın bağlantı bilgisini döner.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');

let db, sunucu, taban;
before(async () => {
  db = await testDb();
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => {
  delete process.env.HC_IP_TESHIS;
  sunucu?.close();
  await db?.close();
});

test('HC_IP_TESHIS yokken uç YOK (404)', async () => {
  delete process.env.HC_IP_TESHIS;
  const r = await fetch(`${taban}/teshis/ip`);
  assert.equal(r.status, 404);
});

test('açıkken: sağdan numaralı X-Forwarded-For, soket ve seçilen IP; sır yok', async () => {
  process.env.HC_IP_TESHIS = 'true';
  const r = await fetch(`${taban}/teshis/ip`, { headers: { 'X-Forwarded-For': '203.0.113.9, 198.51.100.7, 10.0.0.5' } });
  assert.equal(r.status, 200);
  const j = await r.json();
  assert.deepEqual(j.xForwardedFor, ['203.0.113.9', '198.51.100.7', '10.0.0.5']);
  assert.deepEqual(j.sagdan, [{ sira: 1, ip: '10.0.0.5' }, { sira: 2, ip: '198.51.100.7' }, { sira: 3, ip: '203.0.113.9' }]);
  assert.equal(j.soket, '127.0.0.1');
  // Varsayılan hop 0: başlığa güvenilmez, soket seçilir (sahte değer seçilmez).
  assert.equal(j.yapilandirilanHop, 0);
  assert.equal(j.secilenIp, '127.0.0.1');
  assert.deepEqual(Object.keys(j).sort(), ['sagdan', 'secilenIp', 'soket', 'xForwardedFor', 'yapilandirilanHop']);
});

test('başlık çok uzunsa en fazla 10 değer döner', async () => {
  process.env.HC_IP_TESHIS = 'true';
  const uzun = Array.from({ length: 30 }, (_, i) => `198.51.100.${i}`).join(', ');
  const j = await (await fetch(`${taban}/teshis/ip`, { headers: { 'X-Forwarded-For': uzun } })).json();
  assert.equal(j.xForwardedFor.length, 10);
  assert.equal(j.sagdan[0].ip, '198.51.100.29');
});
