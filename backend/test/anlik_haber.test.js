// ANLIK HABER (28 Eki, kullanıcı kararı): uygulama içi bildirim oluşunca
// yalnız o kullanıcının açık uygulamasına tür bilgisiyle haber gider; içerik
// taşımaz. Uygulama 30 sn yoklama yerine bu haberle yeniler.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { gercekZamanliKur } = await import('../src/gercek_zamanli.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { anlikHaberEkle, anlikHaberleriYayinla, ANLIK_HABER_KANALI } = await import('../src/anlik_haber.js');
const { olaylar } = await import('../src/olaylar.js');

let db, sunucu, taban, hub, alan, usta, yabanci, hizmet;

async function istek(yol, { yontem = 'GET', govde, token } = {}) {
  const r = await fetch(taban + yol, { method: yontem, headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: govde ? JSON.stringify(govde) : undefined });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
async function kisi(tel, rol) {
  await db.prepare(`DELETE FROM rate_limits`).run();
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, aydinlatmaAccepted: true, ageConfirmed: true, phone: tel, password: 'sifre1234', name: 'Kişi', email: `h${tel}@ornek.com`, role: rol, otpCode: globalThis.__sonOtp } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  return { token: r.json.accessToken, id: (await istek('/api/v1/users/me', { token: r.json.accessToken })).json.id };
}
function sio(token) {
  const ws = new WebSocket(`${taban.replace('http', 'ws')}/socket.io/?EIO=4&transport=websocket`);
  const gelen = [];
  ws.onmessage = (e) => {
    const p = String(e.data);
    if (p === '2') return ws.send('3');
    if (p.startsWith('0')) return ws.send(`40/ws,${JSON.stringify({ token })}`);
    gelen.push(p);
  };
  const bekle = async (kosul, ms = 3000) => {
    const son = Date.now() + ms;
    while (Date.now() < son) {
      const x = gelen.find(kosul);
      if (x) return x;
      await new Promise((ok) => setTimeout(ok, 30));
    }
    return null;
  };
  return { ws, gelen, bekle, haberler: () => gelen.filter((p) => p.includes(`"${ANLIK_HABER_KANALI}"`)).map((p) => JSON.parse(p.slice(p.indexOf('[')))[1].type) };
}
const sus = (ms) => new Promise((ok) => setTimeout(ok, ms));

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  hub = gercekZamanliKur(sunucu, db);
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  hizmet = (await db.prepare('SELECT name FROM services WHERE deleted_at IS NULL LIMIT 1').get()).name;
  alan = await kisi('5470000001', 'CUSTOMER');
  usta = await kisi('5470000002', 'PROVIDER');
  yabanci = await kisi('5470000003', 'PROVIDER');
  assert.equal((await istek('/api/v1/profiles/me/provider', { yontem: 'PUT', token: usta.token, govde: { categories: [hizmet], districts: [] } })).durum, 200);
});
after(async () => { hub?.hepsiniKapat(); sunucu?.closeAllConnections?.(); sunucu?.close(); await db?.close(); });

test('yeni ilan → eşleşen hizmet verene NEW_LISTING haberi; ilgisiz kullanıcıya haber yok; ilan sahibine yok', async () => {
  const u = sio(usta.token);
  const y = sio(yabanci.token);
  const a = sio(alan.token);
  for (const c of [u, y, a]) assert.ok(await c.bekle((p) => p.startsWith('40/ws')));
  const l = await istek('/api/v1/listings', { yontem: 'POST', token: alan.token, govde: { title: hizmet, location: 'Bayraklı', description: 'kapı kilidi değişecek acil' } });
  assert.ok(l.durum < 300, JSON.stringify(l.json));
  assert.ok(await u.bekle((p) => p.includes('NEW_LISTING')), 'eşleşen hizmet verene haber');
  await sus(200);
  assert.deepEqual(y.haberler(), [], 'kategorisi eşleşmeyen hizmet verene haber yok');
  assert.deepEqual(a.haberler(), [], 'ilan sahibine yeni ilan haberi yok');
  // Haber içerik taşımaz: yalnız tür.
  const ham = u.gelen.find((p) => p.includes('NEW_LISTING'));
  assert.deepEqual(JSON.parse(ham.slice(ham.indexOf('[')))[1], { type: 'NEW_LISTING' });

  // Teklif → ilan sahibine NEW_OFFER.
  const o = await istek('/api/v1/offers', { yontem: 'POST', token: usta.token, govde: { listingId: l.json.id, amountTl: 400, note: '' } });
  assert.ok(o.durum < 300, JSON.stringify(o.json));
  assert.ok(await a.bekle((p) => p.includes('NEW_OFFER')), 'ilan sahibine teklif haberi');
  for (const c of [u, y, a]) c.ws.close();
});

test('aynı kısa sürede çok haber tekilleştirilip paketlenir; büyük gruplar ~8 KB sınırını aşmaz', async () => {
  const yayin = [];
  const dinle = (v) => yayin.push(v);
  olaylar.on(ANLIK_HABER_KANALI, dinle);
  try {
    for (let i = 0; i < 250; i += 1) anlikHaberEkle(`00000000-0000-0000-0000-${String(i).padStart(12, '0')}`, 'ANNOUNCEMENT');
    anlikHaberEkle('00000000-0000-0000-0000-000000000001', 'ANNOUNCEMENT'); // tekrar
    await anlikHaberleriYayinla();
  } finally { olaylar.off(ANLIK_HABER_KANALI, dinle); }
  assert.equal(yayin.length, 3, '250 alıcı → 3 paket');
  assert.equal(yayin.reduce((n, p) => n + p.h.length, 0), 250, 'tekrar eden haber bir kez');
  for (const p of yayin) assert.ok(Buffer.byteLength(JSON.stringify({ k: ANLIK_HABER_KANALI, v: p, o: 'x'.repeat(36) })) < 7900);
});

test('bağlı olmayan kullanıcıya haber hata üretmez', async () => {
  anlikHaberEkle('11111111-1111-1111-1111-111111111111', 'NEW_OFFER');
  await anlikHaberleriYayinla();
});
