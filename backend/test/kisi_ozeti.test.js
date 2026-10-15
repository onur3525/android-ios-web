// GET /api/v1/users/:id/summary — karşı taraf özeti (15 Eki).
//   · İlişkisi olmayan göremez (404; varlık sızmaz).
//   · Ad/telefon görünürlüğü istemcideki MEVCUT kurallarla aynı:
//     ilan akışında iletişim açılınca, teklif talebinde teklif verilince
//     (telefon ayrıca "telefonumu göster" + süresi dolmamış iletişim).
//   · Hizmet veren profili herkese açık ama telefon ve mahalle YOK.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { maskeliAd, kisaAd } = await import('../src/routes/kisi_ozeti.js');

let db, sunucu, taban, kat, hiz;

async function istek(yol, { yontem = 'GET', govde, token } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
async function kisi(tel, rol, ad) {
  await db.prepare('UPDATE otp_codes SET created_at = ? WHERE phone = ?').run('2000-01-01T00:00:00.000Z', tel);
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { phone: tel, password: 'sifre1234', name: ad, email: `o${tel}@ornek.com`, role: rol, otpCode: globalThis.__sonOtp } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const me = await istek('/api/v1/users/me', { token: r.json.accessToken });
  await db.prepare('INSERT INTO addresses (user_id, city, district, neighborhood, updated_at) VALUES (?, ?, ?, ?, ?)')
    .run(me.json.id, 'İzmir', 'Karşıyaka', 'İmbatlı', new Date().toISOString());
  return { token: r.json.accessToken, id: me.json.id, tel };
}
const ozet = (kim, hedef) => istek(`/api/v1/users/${hedef.id}/summary`, { token: kim.token });

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  const s = await db.prepare('SELECT c.name k, s.name h FROM services s JOIN categories c ON c.id = s.category_id LIMIT 1').get();
  kat = s.k;
  hiz = s.h;
});
after(async () => {
  sunucu?.close();
  await db?.close();
});

test('ad biçimleri istemciyle aynı ve yeniden uygulanınca değişmez', () => {
  assert.equal(maskeliAd('Gönül Bütün'), 'G**** B****');
  assert.equal(maskeliAd(maskeliAd('Gönül Bütün')), 'G**** B****');
  assert.equal(kisaAd('Gönül Bütün'), 'Gönül B.');
  assert.equal(kisaAd(kisaAd('Gönül Bütün')), 'Gönül B.');
  assert.equal(kisaAd('Ali Can Öz'), 'Ali Can Ö.');
});

test('ilişkisi olmayan göremez; kimlik doğrulaması ve biçim denetimi', async () => {
  const a = await kisi('5320000001', 'CUSTOMER', 'Ayşe Yılmaz');
  const b = await kisi('5320000002', 'CUSTOMER', 'Berk Kaya');
  assert.equal((await ozet(a, b)).durum, 404);
  assert.equal((await ozet(a, a)).durum, 404, 'kendi bilgisi /users/me');
  assert.equal((await istek('/api/v1/users/x/summary', { token: a.token })).durum, 404);
  assert.equal((await istek(`/api/v1/users/${b.id}/summary`)).durum, 401);
});

test('ilan akışı: iletişim açılana kadar maskeli ad, telefon yok; açılınca tam ad ve telefon', async () => {
  const musteri = await kisi('5320000011', 'CUSTOMER', 'Gönül Bütün');
  const usta = await kisi('5320000012', 'PROVIDER', 'Usta Demir');
  const baskaUsta = await kisi('5320000013', 'PROVIDER', 'Usta Çelik');
  const l = await istek('/api/v1/listings', { yontem: 'POST', token: musteri.token, govde: { title: hiz, location: 'İmbatlı, Karşıyaka / İzmir', description: 'kombi su akıtıyor bakım lazım' } });
  assert.equal(l.durum, 200, JSON.stringify(l.json));

  // Açık ilan akışı: teklif vermemiş hizmet veren de maskeli görür.
  const akis = await ozet(baskaUsta, musteri);
  assert.equal(akis.durum, 200);
  assert.equal(akis.json.name, 'G**** B****');
  assert.equal(akis.json.nameMasked, true);
  assert.equal(akis.json.phone, null);
  assert.equal(akis.json.address.neighborhood, 'İmbatlı');

  const o = await istek('/api/v1/offers', { yontem: 'POST', token: usta.token, govde: { listingId: l.json.id, amountTl: 900, note: '' } });
  assert.equal(o.durum, 200, JSON.stringify(o.json));
  let s = await ozet(usta, musteri);
  assert.equal(s.json.name, 'G**** B****');
  assert.equal(s.json.phone, null);

  // Müşteri hizmet vereni tam adla görür; telefon iletişim açılmadan yok.
  let v = await ozet(musteri, usta);
  assert.equal(v.json.name, 'Usta Demir');
  assert.equal(v.json.phone, null);
  assert.equal(v.json.address.neighborhood, '', 'hizmet veren mahallesi açılmaz');

  await istek(`/api/v1/offers/${o.json.id}/communication`, { yontem: 'POST', token: musteri.token });
  s = await ozet(usta, musteri);
  assert.equal(s.json.name, 'Gönül Bütün');
  assert.equal(s.json.nameMasked, false);
  assert.equal(s.json.phone, musteri.tel);
  v = await ozet(musteri, usta);
  assert.equal(v.json.phone, usta.tel);

  // İletişim yalnız o teklifin taraflarına: diğer hizmet veren hâlâ maskeli, telefonsuz.
  const d = await ozet(baskaUsta, musteri);
  assert.equal(d.json.name, 'G**** B****');
  assert.equal(d.json.phone, null);
});

test('teklif talebi: teklif gelince ad açılır; telefon tercihe ve süreye bağlı', async () => {
  const alan = await kisi('5320000021', 'CUSTOMER', 'Hande Su');
  const usta = await kisi('5320000022', 'PROVIDER', 'Kaan Er');
  const t = await istek('/api/v1/teklif-talepleri', { yontem: 'POST', token: alan.token, govde: { saglayiciId: usta.id, kategori: kat, hizmet: hiz, aciklama: 'acil kaçak kontrolü lazım', iletisimTercihi: 'telefonGoster' } });
  assert.equal(t.durum, 200, JSON.stringify(t.json));
  let s = await ozet(usta, alan);
  assert.equal(s.json.name, 'H**** S*');
  assert.equal(s.json.phone, null);
  assert.equal((await ozet(alan, usta)).json.phone, null, 'teklif öncesi hizmet veren telefonu yok');

  await istek(`/api/v1/teklif-talepleri/${t.json.id}/teklif`, { yontem: 'POST', token: usta.token, govde: { fiyat: 5000, aciklama: 'Hemen gelirim' } });
  s = await ozet(usta, alan);
  assert.equal(s.json.name, 'Hande Su');
  assert.equal(s.json.phone, alan.tel);
  assert.equal(s.json.address.neighborhood, 'İmbatlı');
  assert.equal((await ozet(alan, usta)).json.phone, usta.tel);

  // Süresi dolunca telefon kapanır, ad açık kalır.
  await db.prepare('UPDATE teklif_talepleri SET teklif_tarihi = ? WHERE id = ?').run(new Date(Date.now() - 31 * 3600 * 1000).toISOString(), t.json.id);
  s = await ozet(usta, alan);
  assert.equal(s.json.name, 'Hande Su');
  assert.equal(s.json.phone, null);
  assert.equal((await ozet(alan, usta)).json.phone, null);
});

test('teklif talebi "yalnız mesaj": teklif verilse de hizmet alanın telefonu açılmaz', async () => {
  const alan = await kisi('5320000031', 'CUSTOMER', 'Deniz Ak');
  const usta = await kisi('5320000032', 'PROVIDER', 'Mert Su');
  const t = await istek('/api/v1/teklif-talepleri', { yontem: 'POST', token: alan.token, govde: { saglayiciId: usta.id, kategori: kat, hizmet: hiz, aciklama: 'priz arızası var bakılsın', iletisimTercihi: 'yalnizMesaj' } });
  await istek(`/api/v1/teklif-talepleri/${t.json.id}/teklif`, { yontem: 'POST', token: usta.token, govde: { fiyat: 400 } });
  const s = await ozet(usta, alan);
  assert.equal(s.json.name, 'Deniz Ak');
  assert.equal(s.json.phone, null);
  assert.equal((await ozet(alan, usta)).json.phone, usta.tel, 'hizmet verenin telefonu iletişim açıkken görünür');
});

test('hizmet veren profili herkese açık: telefon ve mahalle yok; iş sayıları', async () => {
  const usta = await kisi('5320000041', 'PROVIDER', 'Selin Tunç');
  const yabanci = await kisi('5320000042', 'CUSTOMER', 'Ozan Ateş');
  const s = await ozet(yabanci, usta);
  assert.equal(s.durum, 200);
  assert.equal(s.json.name, 'Selin Tunç');
  assert.equal(s.json.phone, null);
  assert.equal(s.json.address.city, 'İzmir');
  assert.equal(s.json.address.neighborhood, '');
  assert.equal(s.json.completedJobsAsProvider, 0);
  assert.equal(s.json.photos.customer, null);
  // Askıdaki hizmet veren herkese açık değildir.
  await db.prepare(`UPDATE users SET status = 'SUSPENDED' WHERE id = ?`).run(usta.id);
  assert.equal((await ozet(yabanci, usta)).durum, 404);
});
