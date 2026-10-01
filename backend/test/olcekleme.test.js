// ÇOK ÖRNEKLİ ÇALIŞMA: iki ayrı backend örneği (ayrı HTTP sunucusu + ayrı
// gerçek zamanlı merkez) AYNI veritabanını ve olay yolunu paylaşır.
// Kullanıcı A örnek-1'e, kullanıcı B örnek-2'ye bağlıyken mesajlaşma
// çalışmalı; hız sınırı örnekler arasında ortak olmalı.
// CI'da HC_TEST_DB=postgres ile olay yolu GERÇEK LISTEN/NOTIFY'dır.
// + Dosya depolama (imzalı adres, erişim) ve entegrasyon sırları.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
process.env.HC_S3_ENDPOINT = 'https://r2.ornek-depo.com';
process.env.HC_S3_BUCKET = 'hizmetcep-medya';
process.env.HC_S3_REGION = 'auto';
process.env.HC_S3_ACCESS_KEY_ID = 'TESTANAHTAR123';
process.env.HC_S3_SECRET_ACCESS_KEY = 'testgizlianahtar-yalnizca-test';

const { veritabaniAc, simdi } = await import('../src/db.js');
const { uygulamaKur } = await import('../src/server.js');
const { gercekZamanliKur } = await import('../src/gercek_zamanli.js');
const { olaylar } = await import('../src/olaylar.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');

let db;
const ornek = [];

async function ornekBaslat() {
  const s = createServer(uygulamaKur(db));
  gercekZamanliKur(s, db);
  await new Promise((ok) => s.listen(0, ok));
  return { s, taban: `http://127.0.0.1:${s.address().port}` };
}
async function istek(taban, yol, { yontem = 'GET', govde, token, cerez } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: {
      ...(govde ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(yol.startsWith('/admin/') ? { 'X-HC-Admin': '1', ...(cerez ? { Cookie: cerez } : {}) } : {}),
    },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null, setCookie: r.headers.get('set-cookie') };
}
async function kisi(taban, tel, rol) {
  await istek(taban, '/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek(taban, '/api/v1/auth/register', { yontem: 'POST', govde: { phone: tel, password: 'sifre1234', name: 'Kişi', email: `k${tel}@ornek.com`, role: rol, otpCode: globalThis.__sonOtp } });
  return { token: r.json.accessToken, id: (await istek(taban, '/api/v1/users/me', { token: r.json.accessToken })).json.id };
}
function sio(taban, token) {
  const ws = new WebSocket(`${taban.replace('http', 'ws')}/socket.io/?EIO=4&transport=websocket`);
  const gelen = [];
  ws.onmessage = (e) => {
    const p = String(e.data);
    if (p === '2') return ws.send('3');
    if (p.startsWith('0')) return ws.send(`40/ws,${JSON.stringify({ token })}`);
    gelen.push(p);
  };
  const bekle = async (k, ms = 4000) => {
    const son = Date.now() + ms;
    while (Date.now() < son) {
      const x = gelen.find(k);
      if (x) return x;
      await new Promise((ok) => setTimeout(ok, 30));
    }
    return null;
  };
  return { ws, bekle, emit: (a, v) => ws.send(`42/ws,${JSON.stringify([a, v])}`) };
}

before(async () => {
  db = process.env.HC_TEST_DB === 'postgres'
    ? await veritabaniAc({ surucu: 'postgres', url: process.env.HC_DATABASE_URL, ssl: false })
    : await veritabaniAc({ surucu: 'sqlite', yol: ':memory:' });
  await olaylar.kur(db);
  await tohumla(db);
  ornek.push(await ornekBaslat(), await ornekBaslat());
});
after(async () => {
  for (const o of ornek) { o.s.closeAllConnections?.(); o.s.close(); }
  await olaylar.kapat();
  await db.close();
});

test('farklı örneklere bağlı iki kullanıcı gerçek zamanlı mesajlaşır', async () => {
  const [o1, o2] = ornek;
  const hiz = (await db.prepare('SELECT name FROM services LIMIT 1').get()).name;
  const alan = await kisi(o1.taban, '5330000001', 'CUSTOMER');
  const usta = await kisi(o2.taban, '5330000002', 'PROVIDER');
  const l = await istek(o1.taban, '/api/v1/listings', { yontem: 'POST', token: alan.token, govde: { title: hiz, location: 'Gaziemir', description: 'klima montajı yapılacak bu hafta' } });
  const teklif = (await istek(o2.taban, '/api/v1/offers', { yontem: 'POST', token: usta.token, govde: { listingId: l.json.id, amountTl: 2500, note: '' } })).json;
  await istek(o1.taban, `/api/v1/offers/${teklif.id}/communication`, { yontem: 'POST', token: alan.token });
  // Usta örnek-2'ye, alan örnek-1'e bağlı
  const u = sio(o2.taban, usta.token);
  assert.ok(await u.bekle((p) => p.startsWith('40/ws')));
  u.emit('conversation.join', { offerId: teklif.id });
  await new Promise((ok) => setTimeout(ok, 150));
  // Mesaj örnek-1 üzerinden gönderilir
  await istek(o1.taban, '/api/v1/messages', { yontem: 'POST', token: alan.token, govde: { offerId: teklif.id, text: 'Örnekler arası merhaba', idempotencyKey: randomUUID() } });
  const p = await u.bekle((x) => x.startsWith('42/ws,["message.new"'));
  assert.ok(p, 'örnek-2\'deki usta, örnek-1\'de gönderilen mesajı almalı');
  assert.equal(JSON.parse(p.slice(6))[1].text, 'Örnekler arası merhaba');
  u.ws.close();
});

test('hız sınırı örnekler arasında ORTAK (sınır örnek sayısıyla çoğalmaz)', async () => {
  const [o1, o2] = ornek;
  let ret = 0;
  for (let i = 0; i < 40; i++) {
    const r = await istek(i % 2 ? o2.taban : o1.taban, '/api/v1/auth/login', { yontem: 'POST', govde: { phone: '5399999999', password: 'yanlis-sifre' } });
    if (r.durum === 429) ret++;
  }
  // Sınır 15 dk'da 30 deneme: iki örneğe dağıtılmış 40 denemenin 10'u reddedilmeli.
  assert.equal(ret, 10);
});

test('dosya: imzalı yükleme adresi Flutter kurallarına uyar; yalnız yetkili çözer', async () => {
  const [o1] = ornek;
  const sahip = await kisi(o1.taban, '5330000011', 'CUSTOMER');
  const yabanci = await kisi(o1.taban, '5330000012', 'CUSTOMER');
  assert.equal((await istek(o1.taban, '/api/v1/storage/upload-ref', { yontem: 'POST', token: sahip.token, govde: { kind: 'listing-photo', contentType: 'application/pdf', sizeBytes: 100 } })).durum, 400);
  assert.equal((await istek(o1.taban, '/api/v1/storage/upload-ref', { yontem: 'POST', token: sahip.token, govde: { kind: 'listing-photo', contentType: 'image/jpeg', sizeBytes: 11 * 1024 * 1024 } })).durum, 400);
  const r = await istek(o1.taban, '/api/v1/storage/upload-ref', { yontem: 'POST', token: sahip.token, govde: { kind: 'listing-photo', contentType: 'image/jpeg', sizeBytes: 200000 } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const u = new URL(r.json.uploadUrl);
  assert.equal(u.protocol, 'https:');
  assert.equal(u.host, 'hizmetcep-medya.r2.ornek-depo.com');
  for (const p of ['X-Amz-Algorithm', 'X-Amz-Credential', 'X-Amz-Date', 'X-Amz-Expires', 'X-Amz-Signature']) assert.ok(u.searchParams.get(p), p);
  assert.ok(Number(u.searchParams.get('X-Amz-Expires')) <= 7 * 86400);
  const ref = r.json.storageRef;
  assert.equal((await istek(o1.taban, `/api/v1/storage/resolve?ref=${encodeURIComponent(ref)}`, { token: sahip.token })).durum, 200);
  assert.equal((await istek(o1.taban, `/api/v1/storage/resolve?ref=${encodeURIComponent(ref)}`, { token: yabanci.token })).durum, 404);
  // Başkasının dosyası ilana eklenemez
  const hiz = (await db.prepare('SELECT name FROM services LIMIT 1').get()).name;
  assert.equal((await istek(o1.taban, '/api/v1/listings', { yontem: 'POST', token: yabanci.token, govde: { title: hiz, location: 'Konak', description: 'cam silme işi var acil', photoRefs: [ref] } })).durum, 400);
  assert.equal((await istek(o1.taban, '/api/v1/listings', { yontem: 'POST', token: sahip.token, govde: { title: hiz, location: 'Konak', description: 'cam silme işi var acil', photoRefs: [ref] } })).durum, 200);
});

test('entegrasyon: sır şifreli saklanır, hiçbir yanıtta düz dönmez', async () => {
  const [o1] = ornek;
  const sir = base32Uret();
  await db.prepare(`INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, 'super_admin', ?, ?, ?)`)
    .run(randomUUID(), 'ent@hc.test', 'E', sifreOzetle('GucluSifre12345'), sirSifrele(sir), simdi());
  const g = await istek(o1.taban, '/admin/v1/auth/login', { yontem: 'POST', govde: { email: 'ent@hc.test', password: 'GucluSifre12345' } });
  const c = g.setCookie.split(';')[0];
  await istek(o1.taban, '/admin/v1/auth/mfa', { yontem: 'POST', cerez: c, govde: { code: totpUret(sir) } });
  assert.equal((await istek(o1.taban, '/admin/v1/integrations', { yontem: 'POST', cerez: c, govde: { type: 'SMS', provider: 'webhook', config: { url: 'http://duz-http.com' } } })).durum, 400);
  const e = await istek(o1.taban, '/admin/v1/integrations', { yontem: 'POST', cerez: c, govde: { type: 'SMS', provider: 'webhook', config: { url: 'https://sms-kopru.ornek.com/gonder' } } });
  assert.equal((await istek(o1.taban, `/admin/v1/integrations/${e.json.id}`, { yontem: 'PATCH', cerez: c, govde: { active: true } })).durum, 409, 'sırsız etkinleşmez');
  const s = await istek(o1.taban, `/admin/v1/integrations/${e.json.id}/secret`, { yontem: 'PUT', cerez: c, govde: { token: 'cok-gizli-anahtar-9876' } });
  assert.equal(s.json.secretHint, '••••9876');
  const liste = await istek(o1.taban, '/admin/v1/integrations', { cerez: c });
  assert.ok(!JSON.stringify(liste.json).includes('cok-gizli-anahtar'));
  const kayit = await db.prepare('SELECT secret_enc FROM integrations WHERE id = ?').get(e.json.id);
  assert.ok(!kayit.secret_enc.includes('cok-gizli'));
  const denetim = JSON.stringify(await db.prepare(`SELECT * FROM audit_log WHERE target_id = ?`).all(e.json.id));
  assert.ok(!denetim.includes('cok-gizli-anahtar'), 'denetim kaydında da düz sır yok');
});
