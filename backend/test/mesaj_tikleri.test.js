// MESAJ TİKLERİ (29 Eki, kullanıcı bulgusu): "mesaj karşıya ulaşmadan iki
// tik olmamalı; okunanların hepsi mavi olmalı."
//   SENT (tek tik) → DELIVERED (alıcının açık uygulamasına ulaştı) → READ
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { gercekZamanliKur } = await import('../src/gercek_zamanli.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { olaylar } = await import('../src/olaylar.js');
const { ANLIK_HABER_KANALI, anlikHaberleriYayinla } = await import('../src/anlik_haber.js');

let db, sunucu, taban, hub, alan, usta, offerId, kat, hiz;

async function istek(yol, { yontem = 'GET', govde, token } = {}) {
  const r = await fetch(taban + yol, { method: yontem, headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: govde ? JSON.stringify(govde) : undefined });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
async function kisi(tel, rol) {
  await db.prepare('DELETE FROM rate_limits').run();
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, aydinlatmaAccepted: true, phone: tel, password: 'sifre1234', name: 'Kişi', email: `t${tel}@ornek.com`, role: rol, otpCode: globalThis.__sonOtp } });
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
  return { ws, gelen, bekle, emit: (ad, veri) => ws.send(`42/ws,${JSON.stringify([ad, veri])}`) };
}
const sus = (ms) => new Promise((ok) => setTimeout(ok, ms));
const durumu = async (k, id) => (await istek(`/api/v1/messages/${offerId}`, { token: k.token })).json.find((m) => m.id === id).status;

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  hub = gercekZamanliKur(sunucu, db);
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  const s = await db.prepare('SELECT c.name k, s.name h FROM services s JOIN categories c ON c.id = s.category_id LIMIT 1').get();
  kat = s.k; hiz = s.h;
  alan = await kisi('5490000001', 'CUSTOMER');
  usta = await kisi('5490000002', 'PROVIDER');
  const l = await istek('/api/v1/listings', { yontem: 'POST', token: alan.token, govde: { title: hiz, location: 'Bornova', description: 'balkon kapısı ayarı yapılacak' } });
  offerId = (await istek('/api/v1/offers', { yontem: 'POST', token: usta.token, govde: { listingId: l.json.id, amountTl: 400, note: '' } })).json.id;
  await istek(`/api/v1/offers/${offerId}/communication`, { yontem: 'POST', token: alan.token });
});
after(async () => { hub?.hepsiniKapat(); sunucu?.closeAllConnections?.(); sunucu?.close(); await db?.close(); });

test('ilan sohbeti: gönderince SENT; alıcı listeyi çekince DELIVERED; okuyunca READ', async () => {
  const m = await istek('/api/v1/messages', { yontem: 'POST', token: usta.token, govde: { offerId, text: 'merhaba', idempotencyKey: 'tik-1' } });
  assert.equal(m.json.status, 'SENT', 'alıcıya ulaşmadan iki tik yok');
  assert.equal(await durumu(usta, m.json.id), 'SENT', 'gönderenin kendi okuması iletildi saymaz');
  await istek('/api/v1/messages/conversations', { token: alan.token });
  assert.equal(await durumu(usta, m.json.id), 'DELIVERED');
  await istek(`/api/v1/messages/${offerId}/read`, { yontem: 'POST', token: alan.token });
  assert.equal(await durumu(usta, m.json.id), 'READ');
});

test('ilan sohbeti: alıcı sohbet odasındaysa mesaj anında DELIVERED, gönderene olay gider', async () => {
  const a = sio(alan.token);
  const u = sio(usta.token);
  assert.ok(await a.bekle((p) => p.startsWith('40/ws')));
  assert.ok(await u.bekle((p) => p.startsWith('40/ws')));
  a.emit('conversation.join', { offerId });
  u.emit('conversation.join', { offerId });
  await sus(150);
  const m = await istek('/api/v1/messages', { yontem: 'POST', token: usta.token, govde: { offerId, text: 'orada mısınız', idempotencyKey: 'tik-2' } });
  assert.ok(await a.bekle((p) => p.includes('message.new') && p.includes(m.json.id)), 'alıcıya ulaştı');
  assert.ok(await u.bekle((p) => p.includes('message.delivered')), 'gönderene iletildi olayı');
  assert.equal((await db.prepare('SELECT delivered_at FROM messages WHERE id = ?').get(m.json.id)).delivered_at != null, true);
  a.ws.close(); u.ws.close();
});

test('ilan sohbeti: okundu işareti sohbetteki bütün gelen mesajları kapsar (gri kalan yok)', async () => {
  const ids = [];
  for (let i = 0; i < 3; i++) {
    ids.push((await istek('/api/v1/messages', { yontem: 'POST', token: usta.token, govde: { offerId, text: `mesaj ${i}`, idempotencyKey: `tik-3-${i}` } })).json.id);
  }
  await istek(`/api/v1/messages/${offerId}/read`, { yontem: 'POST', token: alan.token });
  for (const id of ids) assert.equal(await durumu(usta, id), 'READ');
  const n = await db.prepare('SELECT COUNT(*) n FROM messages WHERE offer_id = ? AND read_at IS NOT NULL AND delivered_at IS NULL').get(offerId);
  assert.equal(Number(n.n), 0, 'okunan mesaj iletildi de sayılır');
});

test('teklif talebi sohbeti: iletildi alıcı çekince; okundu; gönderene TALEP_DURUM haberi', async () => {
  const t = await istek('/api/v1/teklif-talepleri', { yontem: 'POST', token: alan.token, govde: { saglayiciId: usta.id, kategori: kat, hizmet: hiz, aciklama: 'mutfak musluğu damlatıyor', iletisimTercihi: 'yalnizMesaj' } });
  await istek(`/api/v1/teklif-talepleri/${t.json.id}/teklif`, { yontem: 'POST', token: usta.token, govde: { fiyat: 600, aciklama: 'Yarın gelebilirim' } });
  const haberler = [];
  const dinle = ({ h } = {}) => haberler.push(...(h ?? []));
  olaylar.on(ANLIK_HABER_KANALI, dinle);
  try {
    const g = await istek(`/api/v1/teklif-talepleri/${t.json.id}/mesajlar`, { yontem: 'POST', token: alan.token, govde: { metin: 'Saat kaçta?' } });
    const mesaj = () => g.json.mesajlar.at(-1);
    assert.equal(mesaj().iletildi, false);
    assert.equal(mesaj().okundu, false);
    const benim = async () => (await istek(`/api/v1/teklif-talepleri/${t.json.id}`, { token: alan.token })).json.mesajlar.at(-1);

    await istek('/api/v1/teklif-talepleri', { token: usta.token }); // alıcının uygulaması listeyi çekti
    assert.equal((await benim()).iletildi, true);
    assert.equal((await benim()).okundu, false);

    await istek(`/api/v1/teklif-talepleri/${t.json.id}/okundu`, { yontem: 'POST', token: usta.token });
    assert.equal((await benim()).okundu, true);
    await anlikHaberleriYayinla();
    assert.ok(haberler.some(([k, tur]) => k === alan.id && tur === 'TALEP_DURUM'), JSON.stringify(haberler));
  } finally {
    olaylar.off?.(ANLIK_HABER_KANALI, dinle);
  }
});
