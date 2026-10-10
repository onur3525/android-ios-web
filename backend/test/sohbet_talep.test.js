// Uçtan uca: ilan sohbeti, teklif talebi durum makinesi, hesap silme, yasal kabul.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { veritabaniAc, simdi } = await import('../src/db.js');
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { silmeTalepleriniIsle, talepSureleriniIsle } = await import('../src/routes/sohbet_talep.js');
const { olaylar } = await import('../src/olaylar.js');

let db, sunucu, taban, kat, hiz, alan, usta, yabanci;

async function istek(yol, { yontem = 'GET', govde, token } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
async function kisi(tel, rol) {
  await db.prepare('UPDATE otp_codes SET created_at = ? WHERE phone = ?').run('2000-01-01T00:00:00.000Z', tel);
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { phone: tel, password: 'sifre1234', name: `Kişi ${tel.slice(-2)}`, email: `k${tel}@ornek.com`, role: rol, otpCode: globalThis.__sonOtp } });
  const me = await istek('/api/v1/users/me', { token: r.json.accessToken });
  return { token: r.json.accessToken, id: me.json.id };
}

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  const s = await db.prepare('SELECT c.name k, s.name h FROM services s JOIN categories c ON c.id = s.category_id LIMIT 1').get();
  kat = s.k;
  hiz = s.h;
  alan = await kisi('5310000001', 'CUSTOMER');
  usta = await kisi('5310000002', 'PROVIDER');
  yabanci = await kisi('5310000003', 'CUSTOMER');
});
after(async () => {
  sunucu?.close();
  await db?.close();
});

test('ilan sohbeti: iletişim açılmadan mesaj yok; taraf olmayan göremez; olay yayınlanır', async () => {
  const l = await istek('/api/v1/listings', { yontem: 'POST', token: alan.token, govde: { title: hiz, location: 'Buca', description: 'musluk akıtıyor tamir lazım' } });
  const o = await istek('/api/v1/offers', { yontem: 'POST', token: usta.token, govde: { listingId: l.json.id, amountTl: 700, note: '' } });
  const kapali = await istek('/api/v1/messages', { yontem: 'POST', token: alan.token, govde: { offerId: o.json.id, text: 'Merhaba' } });
  assert.equal(kapali.durum, 409);
  await istek(`/api/v1/offers/${o.json.id}/communication`, { yontem: 'POST', token: alan.token });
  let yayin = null;
  olaylar.once('message.new', (d) => (yayin = d));
  const m = await istek('/api/v1/messages', { yontem: 'POST', token: alan.token, govde: { offerId: o.json.id, text: 'Merhaba, ne zaman gelirsiniz?', idempotencyKey: 'k1' } });
  assert.equal(m.durum, 200);
  assert.equal(yayin.offerId, o.json.id);
  const ayni = await istek('/api/v1/messages', { yontem: 'POST', token: alan.token, govde: { offerId: o.json.id, text: 'Merhaba, ne zaman gelirsiniz?', idempotencyKey: 'k1' } });
  assert.equal(ayni.json.id, m.json.id);
  assert.equal((await istek(`/api/v1/messages/${o.json.id}`, { token: yabanci.token })).durum, 404);
  const gecmis = await istek(`/api/v1/messages/${o.json.id}`, { token: usta.token });
  assert.equal(gecmis.json.length, 1);
  const konusmalar = await istek('/api/v1/messages/conversations', { token: usta.token });
  assert.equal(konusmalar.json[0].unread, 1);
  await istek(`/api/v1/messages/${o.json.id}/read`, { yontem: 'POST', token: usta.token });
  assert.equal((await istek('/api/v1/messages/conversations', { token: usta.token })).json[0].unread, 0);
});

test('teklif talebi: durum makinesi, taraf denetimi, mesaj ve değerlendirme', async () => {
  const t = await istek('/api/v1/teklif-talepleri', { yontem: 'POST', token: alan.token, govde: { saglayiciId: usta.id, kategori: kat, hizmet: hiz, aciklama: 'evde priz arızası var', iletisimTercihi: 'yalnizMesaj' } });
  assert.equal(t.durum, 200, JSON.stringify(t.json));
  assert.equal(t.json.durum, 'BEKLEMEDE');
  assert.equal(t.json.saglayiciAdi, 'Kişi 02');
  const id = t.json.id;
  assert.equal((await istek(`/api/v1/teklif-talepleri/${id}`, { token: yabanci.token })).durum, 404, 'taraf olmayan göremez');
  assert.equal((await istek(`/api/v1/teklif-talepleri/${id}/mesajlar`, { yontem: 'POST', token: alan.token, govde: { metin: 'selam' } })).durum, 409, 'teklif öncesi mesaj yok');
  assert.equal((await istek(`/api/v1/teklif-talepleri/${id}/teklif`, { yontem: 'POST', token: alan.token, govde: { fiyat: 500 } })).durum, 403);
  const tk = await istek(`/api/v1/teklif-talepleri/${id}/teklif`, { yontem: 'POST', token: usta.token, govde: { fiyat: 500, aciklama: 'Malzeme dahil' } });
  assert.equal(tk.json.durum, 'TEKLIF_GELDI');
  await istek(`/api/v1/teklif-talepleri/${id}/mesajlar`, { yontem: 'POST', token: alan.token, govde: { metin: 'Yarın uygun musunuz?' } });
  const sec = await istek(`/api/v1/teklif-talepleri/${id}/sec`, { yontem: 'POST', token: alan.token });
  assert.equal(sec.json.durum, 'SECILDI');
  const tam = await istek(`/api/v1/teklif-talepleri/${id}/tamamla`, { yontem: 'POST', token: alan.token });
  assert.equal(tam.json.durum, 'TAMAMLANDI');
  assert.equal(tam.json.mesajlar.length, 1);
  const y = await istek(`/api/v1/teklif-talepleri/${id}/review`, { yontem: 'POST', token: alan.token, govde: { stars: 4, text: 'İyi iş' } });
  assert.equal(y.durum, 200);
  const ustaListe = await istek('/api/v1/teklif-talepleri', { token: usta.token });
  assert.equal(ustaListe.json.length, 1);
});

test('teklif talebi: teklif 30 saatte süresi doluyor; usta yalnız beklemedeyken reddeder', async () => {
  const t = await istek('/api/v1/teklif-talepleri', { yontem: 'POST', token: alan.token, govde: { saglayiciId: usta.id, kategori: kat, hizmet: hiz, aciklama: 'kombi bakımı yaptırmak istiyorum', iletisimTercihi: 'telefonGoster' } });
  await istek(`/api/v1/teklif-talepleri/${t.json.id}/teklif`, { yontem: 'POST', token: usta.token, govde: { fiyat: 900 } });
  assert.equal((await istek(`/api/v1/teklif-talepleri/${t.json.id}/reddet`, { yontem: 'POST', token: usta.token, govde: {} })).durum, 409);
  await db.prepare('UPDATE teklif_talepleri SET teklif_tarihi = ? WHERE id = ?').run('2000-01-01T00:00:00.000Z', t.json.id);
  await talepSureleriniIsle(db);
  assert.equal((await istek(`/api/v1/teklif-talepleri/${t.json.id}`, { token: alan.token })).json.durum, 'SURESI_DOLDU');
});

test('yasal kabul: yalnız kabul isteyen + yayındaki sürüm; sürüm değişince yeniden istenir', async () => {
  const z = simdi();
  await db.prepare(`INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_at) VALUES (?, 'kvkk', 1, 'metin bir', 'aaa', '2026-10-01', 'PUBLISHED', ?)`).run(randomUUID(), z);
  let bekleyen = (await istek('/api/v1/legal/pending-acceptances', { token: alan.token })).json;
  assert.deepEqual(bekleyen.map((b) => b.slug), ['kvkk']);
  assert.equal((await istek('/api/v1/legal/kvkk/accept', { yontem: 'POST', token: alan.token, govde: { version: '1', sha256: 'yanlis' } })).durum, 409);
  assert.equal((await istek('/api/v1/legal/kvkk/accept', { yontem: 'POST', token: alan.token, govde: { version: '1', sha256: 'aaa', platform: 'android' } })).durum, 200);
  bekleyen = (await istek('/api/v1/legal/pending-acceptances', { token: alan.token })).json;
  assert.equal(bekleyen.length, 0);
  await db.prepare(`UPDATE legal_versions SET status = 'ARCHIVED' WHERE slug = 'kvkk'`).run();
  await db.prepare(`INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_at) VALUES (?, 'kvkk', 2, 'metin iki', 'bbb', '2026-10-02', 'PUBLISHED', ?)`).run(randomUUID(), z);
  bekleyen = (await istek('/api/v1/legal/pending-acceptances', { token: alan.token })).json;
  assert.equal(bekleyen[0].version, '2');
});

test('hesap silme: 30 gün sonra kişisel veri anonimleşir, oturum kapanır; iptal edilebilir', async () => {
  const r = await istek('/api/v1/profiles/me/deletion-request', { yontem: 'POST', token: yabanci.token, govde: { reason: 'Artık kullanmıyorum' } });
  assert.equal(r.json.status, 'PENDING');
  assert.equal((await istek('/api/v1/profiles/me/deletion-request', { yontem: 'POST', token: yabanci.token, govde: {} })).durum, 409);
  await db.prepare(`UPDATE account_requests SET scheduled_for = ? WHERE id = ?`).run('2000-01-01T00:00:00.000Z', r.json.id);
  assert.equal(await silmeTalepleriniIsle(db), 1);
  const u = await db.prepare('SELECT * FROM users WHERE id = ?').get(yabanci.id);
  assert.equal(u.name, 'Silinmiş Kullanıcı');
  assert.equal(u.email, null);
  assert.ok(u.deleted_at);
  assert.equal((await istek('/api/v1/users/me', { token: yabanci.token })).durum, 401);
  // Aynı numara yeniden kayıt olabilir (kişisel veri serbest kaldı)
  await db.prepare('UPDATE otp_codes SET created_at = ? WHERE phone = ?').run('2000-01-01T00:00:00.000Z', '5310000003');
  assert.equal((await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: '5310000003', purpose: 'REGISTER' } })).durum, 204);
});

test('push jetonu: kayıt, başka hesaba taşınma, yalnız sahibi siler', async () => {
  const t = 'fcmTokenOrnek_' + 'a'.repeat(40);
  assert.equal((await istek('/api/v1/devices/push-token', { yontem: 'POST', token: alan.token, govde: { token: t, platform: 'android' } })).durum, 204);
  assert.equal((await istek('/api/v1/devices/push-token', { yontem: 'POST', token: alan.token, govde: { token: 'kisa', platform: 'android' } })).durum, 400);
  assert.equal((await istek('/api/v1/devices/push-token', { yontem: 'POST', token: usta.token, govde: { token: t, platform: 'android' } })).durum, 204);
  assert.equal((await db.prepare('SELECT user_id FROM push_tokens WHERE token = ?').get(t)).user_id, usta.id);
  await istek('/api/v1/devices/push-token', { yontem: 'DELETE', token: alan.token, govde: { token: t } });
  assert.ok(await db.prepare('SELECT 1 FROM push_tokens WHERE token = ?').get(t), 'başkası silemez');
  await istek('/api/v1/devices/push-token', { yontem: 'DELETE', token: usta.token, govde: { token: t } });
  assert.equal(await db.prepare('SELECT 1 FROM push_tokens WHERE token = ?').get(t), undefined);
});
