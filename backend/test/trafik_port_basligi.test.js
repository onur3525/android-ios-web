// KÖKEN SIRRI + 5651 KAYNAK PORT (29 Eki)
//   · Kural açıkken (HC_ORIGIN_SECRET) sırsız/yanlış sırlı istek 403 alır;
//     sağlık uçları muaftır; WebSocket bağlantısı da reddedilir.
//   · Port başlığı YALNIZ kural açıkken ve sır doğruyken okunur;
//     başlık yoksa/bozuksa NULL (değer uydurulmaz).
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { connect } from 'node:net';

const SIR = 'k'.repeat(40);
process.env.HC_SESSIZ = '1';
process.env.HC_TRUST_PROXY_HOPS = '1';
process.env.HC_CLIENT_PORT_HEADER = 'X-HC-Client-Port';
process.env.HC_ORIGIN_SECRET = SIR;
const { kaynakPort, kokenDogrulandi } = await import('../src/http.js');
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { gercekZamanliKur } = await import('../src/gercek_zamanli.js');

let db, sunucu, hub, taban;
before(async () => {
  db = await testDb();
  sunucu = createServer(uygulamaKur(db));
  hub = gercekZamanliKur(sunucu, db);
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => { hub?.hepsiniKapat(); sunucu?.closeAllConnections?.(); sunucu?.close(); await db?.close(); });

const istek = (basliklar) => ({ headers: basliklar, socket: { remoteAddress: '10.0.0.5', remotePort: 44321 } });

test('köken sırrı: doğru sır kabul, yanlış/eksik sır red', () => {
  assert.equal(kokenDogrulandi(istek({ 'x-hc-origin-secret': SIR })), true);
  assert.equal(kokenDogrulandi(istek({ 'x-hc-origin-secret': `${SIR}x` })), false);
  assert.equal(kokenDogrulandi(istek({})), false);
  assert.equal(kokenDogrulandi(istek({}), null), true, 'kural kapalıyken her istek kabul');
});

test('kaynak port: sır doğruyken başlıktaki port; başlık yoksa/bozuksa NULL; kural kapalıyken okunmaz', () => {
  assert.equal(kaynakPort(istek({ 'x-hc-client-port': '51234' })), 51234);
  assert.equal(kaynakPort(istek({})), null);
  assert.equal(kaynakPort(istek({ 'x-hc-client-port': '70000' })), null);
  assert.equal(kaynakPort(istek({ 'x-hc-client-port': '12a' })), null);
  assert.equal(kaynakPort(istek({ 'x-hc-client-port': '51234' }), { kural: null }), null, 'sahte olabilir → okunmaz');
});

test('sunucu: sırsız istek 403; sırlı istek geçer; sağlık uçları muaf', async () => {
  const sirsiz = await fetch(`${taban}/api/v1/public/config`);
  assert.equal(sirsiz.status, 403);
  const sirli = await fetch(`${taban}/api/v1/legal/terms`, { headers: { 'X-HC-Origin-Secret': SIR } });
  assert.notEqual(sirli.status, 403);
  // /healthz dış sunucu sarmalayıcısındadır; burada /readyz uygulama dışıdır.
  // Muaf liste: uygulama içinde 403 dönmemeli (yol yoksa 404).
  const saglik = await fetch(`${taban}/healthz`);
  assert.notEqual(saglik.status, 403);
});

test('WebSocket: sırsız yükseltme 403 ile kapanır', async () => {
  const yanit = await new Promise((ok, red) => {
    const s = connect(sunucu.address().port, '127.0.0.1', () => {
      s.write('GET /socket.io/?EIO=4&transport=websocket HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
        + 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n');
    });
    let veri = '';
    s.on('data', (d) => { veri += d; });
    s.on('end', () => ok(veri));
    s.on('error', red);
  });
  assert.match(yanit, /^HTTP\/1\.1 403/);
});
