// İLAN TELEFON GİZLİLİĞİ (KVKK takip denetimi E1, 22 Eki)
//   · İlan sahibi "yalnizMesaj" seçtiyse telefonu HİÇBİR karşı taraf
//     yanıtında dönmez: /contact/:offerId, /users/:id/summary,
//     /messages/conversations.
//   · "telefonGoster" seçiminde iletişim açılınca iki taraf da görür.
//   · İlgisiz kullanıcı ve iletişimi açılmamış teklif telefon göremez.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { ilanTelefonuGorunur } = await import('../src/routes/kisi_ozeti.js');

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
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, aydinlatmaAccepted: true, ageConfirmed: true, phone: tel, password: 'sifre1234', name: ad, email: `o${tel}@ornek.com`, role: rol, otpCode: globalThis.__sonOtp } });
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

async function ilanVeTeklif(sahip, usta, tercih) {
  const govde = { title: hiz, location: 'İmbatlı, Karşıyaka / İzmir', description: 'kombi su akıtıyor bakım lazım' };
  if (tercih) govde.iletisimTercihi = tercih;
  const l = await istek('/api/v1/listings', { yontem: 'POST', token: sahip.token, govde });
  assert.equal(l.durum, 200, JSON.stringify(l.json));
  const o = await istek('/api/v1/offers', { yontem: 'POST', token: usta.token, govde: { listingId: l.json.id, amountTl: 900, note: '' } });
  assert.equal(o.durum, 200, JSON.stringify(o.json));
  return { ilanId: l.json.id, teklifId: o.json.id };
}
const iletisimAc = (kim, teklifId) => istek(`/api/v1/offers/${teklifId}/communication`, { yontem: 'POST', token: kim.token });
const iletisim = (kim, teklifId) => istek(`/api/v1/contact/${teklifId}`, { token: kim.token });
async function sohbetKarsisi(kim, teklifId) {
  const k = await istek('/api/v1/messages/conversations', { token: kim.token });
  assert.equal(k.durum, 200);
  return k.json.find((s) => s.offer.id === teklifId)?.counterpart;
}

test('kural tablosu: tanınmayan tercih ve kapalı iletişim gizli', () => {
  assert.equal(ilanTelefonuGorunur({ iletisimAcik: false, karsiIlanSahibi: true, tercih: 'telefonGoster' }), false);
  assert.equal(ilanTelefonuGorunur({ iletisimAcik: false, karsiIlanSahibi: false }), false);
  assert.equal(ilanTelefonuGorunur({ iletisimAcik: true, karsiIlanSahibi: true, tercih: 'yalnizMesaj' }), false);
  assert.equal(ilanTelefonuGorunur({ iletisimAcik: true, karsiIlanSahibi: true, tercih: undefined }), false);
  assert.equal(ilanTelefonuGorunur({ iletisimAcik: true, karsiIlanSahibi: true, tercih: 'telefonGoster' }), true);
  assert.equal(ilanTelefonuGorunur({ iletisimAcik: true, karsiIlanSahibi: false }), true);
});

test('yalnizMesaj: ilan sahibinin telefonu hiçbir uçta dönmez; hizmet verenin telefonu sahibe görünür', async () => {
  const sahip = await kisi('5320000711', 'CUSTOMER', 'Gizli Sahip');
  const usta = await kisi('5320000712', 'PROVIDER', 'Usta Bir');
  const { teklifId } = await ilanVeTeklif(sahip, usta, 'yalnizMesaj');
  assert.equal((await iletisimAc(sahip, teklifId)).durum, 200);
  await istek('/api/v1/messages', { yontem: 'POST', token: sahip.token, govde: { offerId: teklifId, text: 'merhaba' } });

  // Hizmet veren tarafı: üç uç da telefonsuz.
  assert.equal((await iletisim(usta, teklifId)).json.counterpart.phone, null);
  const oz = await ozet(usta, sahip);
  assert.equal(oz.durum, 200);
  assert.equal(oz.json.phone, null);
  assert.equal(oz.json.name, 'Gizli Sahip', 'ad iletişim açılınca tam görünür (kural değişmedi)');
  const karsi = await sohbetKarsisi(usta, teklifId);
  assert.equal(karsi.phone, null);
  assert.equal(karsi.name, 'Gizli Sahip');
  // Yanıtların hiçbir yerinde numara geçmez.
  const hepsi = JSON.stringify([await iletisim(usta, teklifId), oz, await istek('/api/v1/messages/conversations', { token: usta.token })]);
  assert.equal(hepsi.includes(sahip.tel), false);

  // İlan sahibi tarafı: hizmet verenin telefonu görünür (önceki kural).
  assert.equal((await iletisim(sahip, teklifId)).json.counterpart.phone, usta.tel);
  assert.equal((await ozet(sahip, usta)).json.phone, usta.tel);
  assert.equal((await sohbetKarsisi(sahip, teklifId)).phone, usta.tel);
});

test('telefonGoster (ve varsayılan): iletişim açılınca iki taraf telefonu görür; açılmadan görmez', async () => {
  for (const [no, tercih] of [['21', 'telefonGoster'], ['31', undefined]]) {
    const sahip = await kisi(`53200007${no}`, 'CUSTOMER', 'Açık Sahip');
    const usta = await kisi(`53200007${Number(no) + 1}`, 'PROVIDER', 'Usta İki');
    const { teklifId } = await ilanVeTeklif(sahip, usta, tercih);
    assert.equal((await ozet(usta, sahip)).json.phone, null, 'iletişim açılmadan yok');
    assert.equal((await sohbetKarsisi(usta, teklifId)), undefined, 'iletişim açılmadan sohbet listelenmez');
    await iletisimAc(usta, teklifId);
    assert.equal((await iletisim(usta, teklifId)).json.counterpart.phone, sahip.tel);
    assert.equal((await ozet(usta, sahip)).json.phone, sahip.tel);
    assert.equal((await sohbetKarsisi(usta, teklifId)).phone, sahip.tel);
    assert.equal((await sohbetKarsisi(sahip, teklifId)).phone, usta.tel);
  }
});

test('ilgisiz kullanıcı ve iletişimi açılmamış başka hizmet veren telefonu göremez', async () => {
  const sahip = await kisi('5320000741', 'CUSTOMER', 'Üç Sahip');
  const usta = await kisi('5320000742', 'PROVIDER', 'Usta Üç');
  const baskaUsta = await kisi('5320000743', 'PROVIDER', 'Usta Dört');
  const yabanci = await kisi('5320000744', 'CUSTOMER', 'Yabancı Kişi');
  const { ilanId, teklifId } = await ilanVeTeklif(sahip, usta, 'telefonGoster');
  await iletisimAc(sahip, teklifId);
  const o2 = await istek('/api/v1/offers', { yontem: 'POST', token: baskaUsta.token, govde: { listingId: ilanId, amountTl: 800, note: '' } });
  assert.equal(o2.durum, 200, JSON.stringify(o2.json));

  assert.equal((await iletisim(yabanci, teklifId)).durum, 404);
  assert.equal((await ozet(yabanci, sahip)).durum, 404);
  assert.equal((await sohbetKarsisi(yabanci, teklifId)), undefined);
  assert.equal((await iletisim(baskaUsta, teklifId)).durum, 404, 'başkasının teklifine erişemez');
  assert.equal((await iletisim(baskaUsta, o2.json.id)).json.contactOpenAt, null);
  assert.equal((await ozet(baskaUsta, sahip)).json.phone, null);
  // E-posta hiçbir karşı taraf yanıtında yok.
  const s = await ozet(usta, sahip);
  assert.equal('email' in s.json, false);
  assert.equal(JSON.stringify(await istek('/api/v1/messages/conversations', { token: usta.token })).includes('@'), false);
});

test('geçersiz iletişim tercihiyle ilan açılamaz', async () => {
  const sahip = await kisi('5320000751', 'CUSTOMER', 'Dört Sahip');
  const r = await istek('/api/v1/listings', { yontem: 'POST', token: sahip.token, govde: { title: hiz, location: 'İmbatlı, Karşıyaka / İzmir', description: 'kombi su akıtıyor bakım lazım', iletisimTercihi: 'herkes' } });
  assert.equal(r.durum, 400);
});
