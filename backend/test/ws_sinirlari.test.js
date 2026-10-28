// WEBSOCKET SINIRLARI (29 Eki, güvenlik incelemesi): kötü niyetli istemci
// parçalı mesajla, denetim çerçevesiyle, mesaj yağmuruyla ya da çok sayıda
// kimliksiz bağlantıyla sunucu belleğini/veritabanını tüketemez. Normal
// (parçalı dahil) mesajlaşma çalışmaya devam eder.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import net from 'node:net';
import { randomBytes } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { gercekZamanliKur, WS_SINIRLARI } = await import('../src/gercek_zamanli.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');

let db, sunucu, hub, port, token;

/** Ham TCP üzerinden WebSocket: çerçeveler elle kurulur. */
async function ham() {
  const c = net.connect(port, '127.0.0.1');
  const gelen = [];
  let tampon = Buffer.alloc(0);
  let el = false;
  const durum = { kapandi: false };
  c.on('close', () => { durum.kapandi = true; });
  c.on('error', () => {});
  c.on('data', (d) => {
    tampon = Buffer.concat([tampon, d]);
    if (!el) {
      const i = tampon.indexOf('\r\n\r\n');
      if (i < 0) return;
      el = true;
      tampon = tampon.subarray(i + 4);
    }
    for (;;) {
      if (tampon.length < 2) return;
      let n = tampon[1] & 0x7f; let o = 2;
      if (n === 126) { if (tampon.length < 4) return; n = tampon.readUInt16BE(2); o = 4; }
      if (tampon.length < o + n) return;
      gelen.push(tampon.subarray(o, o + n).toString());
      tampon = tampon.subarray(o + n);
    }
  });
  c.write(`GET /socket.io/?EIO=4&transport=websocket HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: ${randomBytes(16).toString('base64')}\r\nSec-WebSocket-Version: 13\r\n\r\n`);
  const cerceve = (op, fin, veri) => {
    const yuk = Buffer.from(veri);
    const maske = randomBytes(4);
    const m = Buffer.from(yuk);
    for (let i = 0; i < m.length; i++) m[i] ^= maske[i & 3];
    let bas;
    if (m.length < 126) bas = Buffer.from([(fin ? 0x80 : 0) | op, 0x80 | m.length]);
    else { bas = Buffer.alloc(4); bas[0] = (fin ? 0x80 : 0) | op; bas[1] = 0x80 | 126; bas.writeUInt16BE(m.length, 2); }
    return Buffer.concat([bas, maske, m]);
  };
  const bekle = async (kosul, ms = 3000) => {
    const son = Date.now() + ms;
    while (Date.now() < son) {
      if (kosul()) return true;
      await new Promise((ok) => setTimeout(ok, 20));
    }
    return kosul();
  };
  await bekle(() => gelen.some((p) => p.startsWith('0{')));
  return { c, gelen, durum, bekle, gonder: (op, fin, veri) => c.write(cerceve(op, fin, veri)) };
}

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  hub = gercekZamanliKur(sunucu, db);
  await new Promise((ok) => sunucu.listen(0, ok));
  port = sunucu.address().port;
  const taban = `http://127.0.0.1:${port}`;
  const istek = async (yol, govde) => {
    const r = await fetch(taban + yol, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(govde) });
    const m = await r.text();
    return m ? JSON.parse(m) : null;
  };
  await istek('/api/v1/auth/otp/request', { phone: '5480000001', purpose: 'REGISTER' });
  const k = await istek('/api/v1/auth/register', { termsAccepted: true, aydinlatmaAccepted: true, ageConfirmed: true, phone: '5480000001', password: 'sifre1234', name: 'Soket Deneme', email: 'soket@ornek.com', role: 'CUSTOMER', otpCode: globalThis.__sonOtp });
  token = k.accessToken;
});
after(async () => { hub?.hepsiniKapat(); sunucu?.closeAllConnections?.(); sunucu?.close(); await db?.close(); });

test('FIN\'siz parçaların TOPLAMI sınırı aşınca bağlantı kapanır (kimlik beklenmez)', async () => {
  const w = await ham();
  const parca = 'a'.repeat(30_000);
  w.gonder(0x1, false, parca);
  w.gonder(0x0, false, parca);
  w.gonder(0x0, false, parca); // toplam 90 KB > 64 KB
  assert.ok(await w.bekle(() => w.durum.kapandi), 'parça yağmuru kapatılmalı');
  assert.equal(hub.kimliksizler.size, 0, 'kapanan kimliksiz bağlantı izlenmeye devam etmemeli');
});

test('meşru parçalı mesaj çalışır: kimlik paketi üç parça hâlinde', async () => {
  const w = await ham();
  const paket = `40/ws,${JSON.stringify({ token })}`;
  const u = Math.ceil(paket.length / 3);
  w.gonder(0x1, false, paket.slice(0, u));
  w.gonder(0x0, false, paket.slice(u, 2 * u));
  w.gonder(0x0, true, paket.slice(2 * u));
  assert.ok(await w.bekle(() => w.gelen.some((p) => p.startsWith('40/ws,{"sid"'))), 'kimlik doğrulanmalı');
  assert.equal(w.durum.kapandi, false);
  w.c.destroy();
});

test('protokol ihlalleri kapatır: büyük/parçalı denetim çerçevesi, başlangıçsız devam, yarım mesaj varken yeni mesaj', async () => {
  const a = await ham();
  a.gonder(0x9, true, 'x'.repeat(WS_SINIRLARI.AZAMI_DENETIM_YUKU + 1));
  assert.ok(await a.bekle(() => a.durum.kapandi), '125 bayttan büyük ping');
  const b = await ham();
  b.gonder(0x9, false, 'x');
  assert.ok(await b.bekle(() => b.durum.kapandi), 'parçalı ping');
  const c = await ham();
  c.gonder(0x0, true, 'devam');
  assert.ok(await c.bekle(() => c.durum.kapandi), 'başlangıçsız devam çerçevesi');
  const d = await ham();
  d.gonder(0x1, false, 'yarim');
  d.gonder(0x1, true, 'yeni');
  assert.ok(await d.bekle(() => d.durum.kapandi), 'yarım mesaj varken yeni mesaj');
});

test('mesaj hızı: normal sayıda açık kalır, sınır aşılınca kapanır', async () => {
  const w = await ham();
  w.gonder(0x1, true, `40/ws,${JSON.stringify({ token })}`);
  assert.ok(await w.bekle(() => w.gelen.some((p) => p.startsWith('40/ws,{"sid"'))));
  for (let i = 0; i < 20; i++) w.gonder(0x1, true, '3');
  await new Promise((ok) => setTimeout(ok, 300));
  assert.equal(w.durum.kapandi, false, 'normal kullanım kapatılmamalı');
  for (let i = 0; i < WS_SINIRLARI.AZAMI_MESAJ; i++) w.gonder(0x1, true, '3');
  assert.ok(await w.bekle(() => w.durum.kapandi), 'mesaj yağmuru kapatılmalı');
  const p = await ham();
  for (let i = 0; i <= WS_SINIRLARI.AZAMI_MESAJ; i++) p.gonder(0x9, true, 'p');
  assert.ok(await p.bekle(() => p.durum.kapandi), 'ping yağmuru da sayılır');
});

test('IP başına kimliksiz bağlantı sınırı; kimlik doğrulanınca sayıdan düşer', async () => {
  const acik = [];
  for (let i = 0; i < WS_SINIRLARI.IP_BASINA_KIMLIKSIZ; i++) acik.push(await ham());
  const fazla = await ham();
  assert.ok(await fazla.bekle(() => fazla.durum.kapandi), 'sınırı aşan kimliksiz bağlantı kapanmalı');
  for (const w of acik) assert.equal(w.durum.kapandi, false);
  // Biri kimlik doğrularsa yer açılır.
  acik[0].gonder(0x1, true, `40/ws,${JSON.stringify({ token })}`);
  assert.ok(await acik[0].bekle(() => acik[0].gelen.some((p) => p.startsWith('40/ws,{"sid"'))));
  const yeni = await ham();
  await new Promise((ok) => setTimeout(ok, 200));
  assert.equal(yeni.durum.kapandi, false, 'kimliği doğrulanan bağlantı kimliksiz sayılmamalı');
  for (const w of [...acik, yeni]) w.c.destroy();
  await new Promise((ok) => setTimeout(ok, 200));
  assert.equal(hub.kimliksizler.size, 0, 'kapanınca izleme temizlenmeli');
});

test('kimlik bir kez doğrulanır: tekrar eden kimlik paketi yeniden sorgu yaptırmaz', async () => {
  const w = await ham();
  w.gonder(0x1, true, `40/ws,${JSON.stringify({ token })}`);
  assert.ok(await w.bekle(() => w.gelen.filter((p) => p.startsWith('40/ws,{"sid"')).length === 1));
  w.gonder(0x1, true, `40/ws,${JSON.stringify({ token })}`);
  await new Promise((ok) => setTimeout(ok, 300));
  assert.equal(w.gelen.filter((p) => p.startsWith('40/ws,{"sid"')).length, 1);
  w.c.destroy();
});
