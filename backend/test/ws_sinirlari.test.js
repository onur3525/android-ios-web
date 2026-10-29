// WEBSOCKET SINIRLARI (29 Eki, güvenlik incelemesi): kötü niyetli istemci
// parçalı mesajla, denetim çerçevesiyle, mesaj yağmuruyla ya da çok sayıda
// kimliksiz bağlantıyla sunucu belleğini/veritabanını tüketemez. Normal
// (parçalı dahil) mesajlaşma çalışmaya devam eder.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import net from 'node:net';
import { randomBytes, randomUUID } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { gercekZamanliKur, WS_SINIRLARI } = await import('../src/gercek_zamanli.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { olaylar } = await import('../src/olaylar.js');
const { anlikHaberEkle, anlikHaberleriYayinla } = await import('../src/anlik_haber.js');

let db, sunucu, hub, port, token, taban, kullaniciId, usta, offerId;
const sus = (ms) => new Promise((ok) => setTimeout(ok, ms));

/**
 * Ham TCP üzerinden WebSocket: çerçeveler elle kurulur.
 * [basliklar]: el sıkışmaya eklenecek HTTP başlıkları (ör. X-Forwarded-For).
 * [yariAcik]: karşı taraf kapanışa YANIT VERMEYEN istemci (FIN göndermez).
 */
async function ham({ basliklar = {}, yariAcik = false } = {}) {
  const c = net.connect({ port, host: '127.0.0.1', allowHalfOpen: yariAcik });
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
  const ek = Object.entries(basliklar).map(([k, v]) => `${k}: ${v}\r\n`).join('');
  c.write(`GET /socket.io/?EIO=4&transport=websocket HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: ${randomBytes(16).toString('base64')}\r\nSec-WebSocket-Version: 13\r\n${ek}\r\n`);
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
  taban = `http://127.0.0.1:${port}`;
  const k = await kayit('5480000001', 'CUSTOMER');
  token = k.token;
  kullaniciId = k.id;
  // Normal akış testi için: ilan + teklif + açılmış iletişim (sohbet odası).
  usta = await kayit('5480000002', 'PROVIDER');
  const hizmet = (await db.prepare('SELECT name FROM services WHERE deleted_at IS NULL LIMIT 1').get()).name;
  const l = await istek('/api/v1/listings', { yontem: 'POST', token, govde: { title: hizmet, location: 'Bayraklı', description: 'kapı kilidi değişecek acil' } });
  offerId = (await istek('/api/v1/offers', { yontem: 'POST', token: usta.token, govde: { listingId: l.json.id, amountTl: 400, note: '' } })).json.id;
  await istek(`/api/v1/offers/${offerId}/communication`, { yontem: 'POST', token });
});

async function istek(yol, { yontem = 'GET', govde, token: t } = {}) {
  const r = await fetch(taban + yol, { method: yontem, headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(t ? { Authorization: `Bearer ${t}` } : {}) }, body: govde ? JSON.stringify(govde) : undefined });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
async function kayit(tel, rol) {
  await db.prepare('DELETE FROM rate_limits').run();
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, aydinlatmaAccepted: true, ageConfirmed: true, phone: tel, password: 'sifre1234', name: 'Soket Deneme', email: `s${tel}@ornek.com`, role: rol, otpCode: globalThis.__sonOtp } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  return { token: r.json.accessToken, id: (await istek('/api/v1/users/me', { token: r.json.accessToken })).json.id };
}
/** Kimliği doğrulanmış ham bağlantı. */
async function kimlikli(t = token, sec = {}) {
  const w = await ham(sec);
  w.gonder(0x1, true, `40/ws,${JSON.stringify({ token: t })}`);
  assert.ok(await w.bekle(() => w.gelen.some((p) => p.startsWith('40/ws,{"sid"'))), 'kimlik doğrulanmalı');
  return w;
}
/** Hub'daki sunucu tarafı bağlantı nesneleri. */
const sunucuBaglantilari = (id) => [...(hub.kullanicilar.get(id) ?? [])];
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

// ═══════════ 29 Eki — EKSİK TESTLER (güvenlik düzeltme planı) ═══════════

test('yazma tamponu: okumayan istemcide 1 MB aşılınca bağlantı kapanır; tampon sınırın üstüne çıkmaz', async () => {
  const w = await kimlikli();
  w.c.pause(); // istemci okumayı bırakır: sunucunun yazdıkları birikir
  const [b] = sunucuBaglantilari(kullaniciId);
  assert.ok(b, 'sunucu bağlantısı bulunmalı');
  const buyuk = 'x'.repeat(60_000);
  let enCok = 0;
  for (let i = 0; i < 3000 && !b.kapandi; i++) {
    b.olay('message.read', { offerId: buyuk });
    enCok = Math.max(enCok, b.soket.writableLength);
  }
  assert.equal(b.kapandi, true, 'okumayan istemci kapatılmalı');
  assert.ok(enCok <= WS_SINIRLARI.YAZMA_TAMPONU_SINIRI + 70_000, `tampon ${enCok} bayta çıktı`);
  w.c.destroy();
});

test('zorla kapatma: kapanışa yanıt vermeyen soket 5 sn sonra kesilir', async () => {
  const w = await ham({ yariAcik: true });
  const [b] = [...(hub.kimliksizler.get('127.0.0.1') ?? [])];
  assert.ok(b, 'kimliksiz bağlantı izlenmeli');
  w.gonder(0x0, true, 'devam'); // protokol ihlali → sunucu kapatır
  await sus(1000);
  assert.equal(b.kapandi, true);
  assert.equal(b.soket.destroyed, false, 'karşı taraf yanıt vermedi; soket henüz açık (yarı kapalı)');
  await sus(4600);
  assert.equal(b.soket.destroyed, true, '5 sn sonra zorla kapatılmalı');
  w.c.destroy();
});

test('oda yarışı: yetki sorgusu sürerken bağlantı kapanırsa odaya EKLENMEZ', async () => {
  const w = await kimlikli();
  const asil = hub.katilabilir;
  hub.katilabilir = async (...a) => { await sus(300); return asil.apply(hub, a); };
  try {
    w.gonder(0x1, true, `42/ws,${JSON.stringify(['conversation.join', { offerId }])}`);
    await sus(50);
    w.c.destroy(); // sorgu sürerken kapanır
    await sus(500);
    assert.equal(hub.odalar.has(offerId), false, 'kapalı bağlantı odada kalmamalı');
  } finally {
    hub.katilabilir = asil;
  }
});

test('proxy ayarı TANIMSIZKEN X-Forwarded-For yok sayılır: sahte başlıkla IP sınırı atlatılamaz', async () => {
  // HC_TRUST_PROXY_HOPS tanımsız (bu dosya) → herkes soket adresiyle sayılır.
  const acik = [];
  for (let i = 0; i < WS_SINIRLARI.IP_BASINA_KIMLIKSIZ; i++) acik.push(await ham({ basliklar: { 'X-Forwarded-For': `10.0.0.${i + 1}` } }));
  const fazla = await ham({ basliklar: { 'X-Forwarded-For': '10.9.9.9' } });
  assert.ok(await fazla.bekle(() => fazla.durum.kapandi), 'farklı sahte başlık sınırı aşmamalı');
  assert.deepEqual([...hub.kimliksizler.keys()], ['127.0.0.1'], 'yalnız soket adresi kullanılmalı');
  for (const w of acik) w.c.destroy();
  await sus(200);
});

test('normal kullanım: kimlik, odaya giriş/çıkış, mesaj, bildirim, yeniden bağlanma — hiçbiri sınıra takılmaz', async () => {
  const w = await kimlikli();
  const katil = (x) => x.gonder(0x1, true, `42/ws,${JSON.stringify(['conversation.join', { offerId }])}`);
  const ayril = (x) => x.gonder(0x1, true, `42/ws,${JSON.stringify(['conversation.leave', { offerId }])}`);
  const mesaj = async (metin) => assert.ok((await istek('/api/v1/messages', { yontem: 'POST', token: usta.token, govde: { offerId, text: metin, idempotencyKey: randomUUID() } })).durum < 300);
  katil(w);
  await sus(150);
  await mesaj('Merhaba 1');
  assert.ok(await w.bekle(() => w.gelen.some((p) => p.includes('message.new') && p.includes('Merhaba 1'))), 'odadaki mesaj gelmeli');
  ayril(w);
  await sus(150);
  await mesaj('Merhaba 2');
  await sus(300);
  assert.equal(w.gelen.some((p) => p.includes('Merhaba 2')), false, 'odadan çıkınca mesaj gelmemeli');
  katil(w);
  await sus(150);
  // Hızlı sohbet: arka arkaya 10 mesaj (REST); soket tarafında yalnız gelen olaylar.
  for (let i = 0; i < 10; i++) await mesaj(`Hızlı ${i}`);
  assert.ok(await w.bekle(() => w.gelen.filter((p) => p.includes('Hızlı')).length === 10), '10 mesajın hepsi gelmeli');
  // Bildirim haberi.
  anlikHaberEkle(kullaniciId, 'NEW_OFFER');
  await anlikHaberleriYayinla();
  assert.ok(await w.bekle(() => w.gelen.some((p) => p.includes('notification.new'))));
  // Engine.IO ping/pong (sunucu her 25 sn ping atar; istemci 3 ile yanıtlar).
  for (let i = 0; i < 5; i++) w.gonder(0x1, true, '3');
  await sus(100);
  assert.equal(w.durum.kapandi, false, 'normal kullanım kapatılmamalı');
  // Yeniden bağlanma: kopma → yeni bağlantı → odaya yeniden katılma.
  w.c.destroy();
  await sus(100);
  const y = await kimlikli();
  katil(y);
  await sus(150);
  await mesaj('Yeniden bağlandım');
  assert.ok(await y.bekle(() => y.gelen.some((p) => p.includes('Yeniden bağlandım'))));
  assert.equal(y.durum.kapandi, false);
  y.c.destroy();
});

test('saldırı paketleri dururken meşru parçalı mesaj aynı bağlantıda bozulmaz', async () => {
  const w = await kimlikli();
  // Parçalı oda isteği (3 parça) çalışır.
  const paket = `42/ws,${JSON.stringify(['conversation.join', { offerId }])}`;
  const u = Math.ceil(paket.length / 3);
  w.gonder(0x1, false, paket.slice(0, u));
  w.gonder(0x0, false, paket.slice(u, 2 * u));
  w.gonder(0x0, true, paket.slice(2 * u));
  await sus(200);
  assert.ok([...(hub.odalar.get(offerId) ?? [])].some((b) => b.kullanici?.id === kullaniciId), 'parçalı istek işlenmeli');
  // Aynı bağlantıda sınır aşan parça → kapanır.
  w.gonder(0x1, false, 'a'.repeat(40_000));
  w.gonder(0x0, false, 'a'.repeat(40_000));
  assert.ok(await w.bekle(() => w.durum.kapandi));
  await sus(100);
  assert.equal([...(hub.odalar.get(offerId) ?? [])].some((b) => b.kapandi), false, 'kapanan bağlantı odadan çıkmalı');
});
