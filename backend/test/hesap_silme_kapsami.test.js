// HESAP SİLME KAPSAMI (15 Eki güvenlik denetimi, karar 4): silinen hesabın
// ilişkili tablolardaki kişisel içeriği de kaldırılır — mesajlar, ilan
// açıklaması/konumu/fotoğrafı, teklif notu, talepler, yorumlar, bildirimler,
// oturum kayıtları, OTP kayıtları. Yasal/güvenlik gerekçeli kayıtlar kalır.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { silmeTalepleriniIsle } = await import('../src/routes/sohbet_talep.js');

let db, sunucu, taban, kat, hiz;
const KALDIRILDI = '[Hesap silindiği için içerik kaldırıldı]';

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
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, ageConfirmed: true, phone: tel, password: 'sifre1234', name: `Silme ${tel.slice(-2)}`, email: `s${tel}@ornek.com`, role: rol, otpCode: globalThis.__sonOtp } });
  const me = await istek('/api/v1/users/me', { token: r.json.accessToken });
  return { token: r.json.accessToken, id: me.json.id, tel };
}
async function sil(k) {
  const r = await istek('/api/v1/profiles/me/deletion-request', { yontem: 'POST', token: k.token, govde: { reason: 'Kişisel gerekçe metni', password: 'sifre1234' } });
  assert.equal(r.durum, 200);
  await db.prepare('UPDATE account_requests SET scheduled_for = ? WHERE id = ?').run('2000-01-01T00:00:00.000Z', r.json.id);
  assert.equal(await silmeTalepleriniIsle(db), 1);
}
const bir = (sql, ...p) => db.prepare(sql).get(...p);

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
after(async () => { sunucu?.close(); await db?.close(); });

test('hizmet alan ve hizmet veren silinince yazdıkları içerik kalkar; karşı tarafın mesajı ve yasal kayıtlar kalır', async () => {
  const alan = await kisi('5380000001', 'CUSTOMER');
  const usta = await kisi('5380000002', 'PROVIDER');

  // İlan + teklif + sohbet (iki taraf da yazar)
  const l = await istek('/api/v1/listings', { yontem: 'POST', token: alan.token, govde: { title: hiz, location: 'Buca Özel Sokak 5', description: 'Kapı kodu 1234, evde yalnızım' } });
  assert.equal(l.durum, 200, JSON.stringify(l.json));
  const o = await istek('/api/v1/offers', { yontem: 'POST', token: usta.token, govde: { listingId: l.json.id, amountTl: 700, note: 'Ustanın kişisel notu' } });
  await istek(`/api/v1/offers/${o.json.id}/communication`, { yontem: 'POST', token: alan.token });
  await istek('/api/v1/messages', { yontem: 'POST', token: alan.token, govde: { offerId: o.json.id, text: 'Adresim Buca, kapı kodu 1234' } });
  await istek('/api/v1/messages', { yontem: 'POST', token: usta.token, govde: { offerId: o.json.id, text: 'Ustanın kendi mesajı' } });

  // Teklif talebi: teklif, mesaj, tamamlanma, değerlendirme
  const t = await istek('/api/v1/teklif-talepleri', { yontem: 'POST', token: alan.token, govde: { saglayiciId: usta.id, kategori: kat, hizmet: hiz, aciklama: 'Evde priz arızası, telefonum 0532', iletisimTercihi: 'yalnizMesaj' } });
  assert.equal(t.durum, 200, JSON.stringify(t.json));
  await istek(`/api/v1/teklif-talepleri/${t.json.id}/teklif`, { yontem: 'POST', token: usta.token, govde: { fiyat: 500, aciklama: 'Ustanın teklif açıklaması' } });
  await istek(`/api/v1/teklif-talepleri/${t.json.id}/mesajlar`, { yontem: 'POST', token: alan.token, govde: { metin: 'Talep mesajım' } });
  await istek(`/api/v1/teklif-talepleri/${t.json.id}/sec`, { yontem: 'POST', token: alan.token });
  await istek(`/api/v1/teklif-talepleri/${t.json.id}/tamamla`, { yontem: 'POST', token: alan.token });
  const y = await istek(`/api/v1/teklif-talepleri/${t.json.id}/review`, { yontem: 'POST', token: alan.token, govde: { stars: 4, text: 'Yorumumda adım geçiyor' } });
  assert.equal(y.durum, 200, JSON.stringify(y.json));
  assert.ok(await bir('SELECT 1 FROM notifications WHERE user_id = ?', alan.id), 'silmeden önce bildirimi var');

  // ── Hizmet alan silinir ──
  await sil(alan);
  const ilan = await bir('SELECT * FROM listings WHERE id = ?', l.json.id);
  assert.equal(ilan.description, KALDIRILDI);
  assert.equal(ilan.location, '-');
  assert.equal(ilan.photo_refs_json, '[]');
  assert.equal(ilan.status, 'USER_DELETED');
  assert.equal((await bir('SELECT text FROM messages WHERE sender_id = ?', alan.id)).text, KALDIRILDI);
  assert.equal((await bir('SELECT text FROM messages WHERE sender_id = ?', usta.id)).text, 'Ustanın kendi mesajı', 'karşı tarafın mesajı onundur');
  const talep = await bir('SELECT * FROM teklif_talepleri WHERE id = ?', t.json.id);
  assert.equal(talep.aciklama, KALDIRILDI);
  assert.ok(talep.silindi_at, 'mesajlaşma kapandı');
  assert.equal((await bir('SELECT metin FROM teklif_mesajlari WHERE gonderen_id = ?', alan.id)).metin, KALDIRILDI);
  const yorum = await bir('SELECT * FROM reviews WHERE author_id = ?', alan.id);
  assert.equal(yorum.text, KALDIRILDI);
  assert.equal(yorum.stars, 4, 'yıldız anonim kalır (puan bütünlüğü)');
  assert.equal(await bir('SELECT 1 FROM notifications WHERE user_id = ?', alan.id), undefined);
  assert.equal(await bir('SELECT 1 FROM user_sessions WHERE user_id = ?', alan.id), undefined);
  assert.equal(await bir('SELECT 1 FROM otp_codes WHERE phone = ?', alan.tel), undefined);
  assert.equal((await bir('SELECT reason FROM account_requests WHERE user_id = ?', alan.id)).reason, null);
  // Yasal gerekçeyle KALANLAR: sözleşme onayı ispatı, silme talebinin kaydı.
  assert.ok(await bir(`SELECT 1 FROM account_requests WHERE user_id = ? AND status = 'COMPLETED'`, alan.id));

  // ── Hizmet veren silinir ──
  await sil(usta);
  const teklif = await bir('SELECT * FROM offers WHERE id = ?', o.json.id);
  assert.equal(teklif.note, KALDIRILDI);
  assert.equal((await bir('SELECT text FROM messages WHERE sender_id = ?', usta.id)).text, KALDIRILDI);
  assert.equal((await bir('SELECT teklif_aciklamasi FROM teklif_talepleri WHERE id = ?', t.json.id)).teklif_aciklamasi, KALDIRILDI);
  const hakkinda = await bir('SELECT * FROM reviews WHERE provider_id = ?', usta.id);
  assert.equal(hakkinda.status, 'ADMIN_DELETED', 'silinen hizmet veren hakkındaki yorum yayından kalkar');
  assert.equal(hakkinda.removed_reason, 'ACCOUNT_DELETED');
});

test('açık ilan ve açık teklif silmede kapanır', async () => {
  const alan = await kisi('5380000003', 'CUSTOMER');
  const usta = await kisi('5380000004', 'PROVIDER');
  const l = await istek('/api/v1/listings', { yontem: 'POST', token: alan.token, govde: { title: hiz, location: 'Konak', description: 'boya badana işi' } });
  const o = await istek('/api/v1/offers', { yontem: 'POST', token: usta.token, govde: { listingId: l.json.id, amountTl: 900, note: 'not' } });
  assert.equal((await bir('SELECT status FROM offers WHERE id = ?', o.json.id)).status, 'ACTIVE');
  await sil(usta);
  assert.equal((await bir('SELECT status FROM offers WHERE id = ?', o.json.id)).status, 'CLOSED');
  assert.equal((await bir('SELECT status FROM listings WHERE id = ?', l.json.id)).status, 'ACTIVE', 'karşı tarafın ilanı açık kalır');
});

// KVKK takip denetimi (22 Eki) E2 + B12: e-postayla açılan destek talebinin
// gönderen adı/adresi ve bakım test hesabı kayıtları da silinir; başka
// kişinin talebine ve cihaz kaydına dokunulmaz.
test('silmede e-posta destek talebinin gönderen bilgisi ve bakım cihaz kayıtları kalkar; başkasınınki kalır', async () => {
  const k = await kisi('5380000031', 'CUSTOMER');
  const baska = await kisi('5380000032', 'CUSTOMER');
  const z = new Date().toISOString();
  const talep = async (id, no, uid, eposta) => db.prepare(
    `INSERT INTO support_tickets (id, ticket_no, user_id, subject, message, status, created_at, updated_at, source, sender_email, sender_name, inbound_email_id)
     VALUES (?, ?, ?, 'Konu', 'İleti', 'OPEN', ?, ?, 'EMAIL', ?, 'Gönderen Ad', ?)`,
  ).run(id, no, uid, z, z, eposta, `gelen-${no}`);
  await talep('11111111-1111-4111-8111-111111111111', '990001', k.id, `s${k.tel}@ornek.com`);
  await talep('22222222-2222-4222-8222-222222222222', '990002', baska.id, `s${baska.tel}@ornek.com`);
  await talep('33333333-3333-4333-8333-333333333333', '990003', null, `s${k.tel}@ornek.com`);
  await db.prepare('UPDATE users SET maintenance_bypass = TRUE WHERE id IN (?, ?)').run(k.id, baska.id);
  const cihaz = (id, uid) => db.prepare('INSERT INTO maintenance_devices (id, user_id, device_hash, platform, created_at, last_seen_at) VALUES (?, ?, ?, ?, ?, ?)')
    .run(id, uid, `ozet-${id}`, 'android', z, z);
  await cihaz('44444444-4444-4444-8444-444444444444', k.id);
  await cihaz('55555555-5555-4555-8555-555555555555', baska.id);

  await sil(k);

  const t = await bir('SELECT * FROM support_tickets WHERE ticket_no = ?', '990001');
  assert.equal(t.sender_email, null);
  assert.equal(t.sender_name, null);
  assert.equal(t.status, 'CLOSED');
  assert.equal(t.ticket_no, '990001', 'kayıt (numara, tarih) kalır');
  const b = await bir('SELECT * FROM support_tickets WHERE ticket_no = ?', '990002');
  assert.equal(b.sender_email, `s${baska.tel}@ornek.com`, 'başkasının talebi değişmez');
  assert.equal(b.sender_name, 'Gönderen Ad');
  const bagsiz = await bir('SELECT * FROM support_tickets WHERE ticket_no = ?', '990003');
  assert.equal(bagsiz.sender_email, `s${k.tel}@ornek.com`, 'hesaba bağlanmamış e-posta talebine dokunulmaz (karar listesinde)');

  assert.equal((await bir('SELECT maintenance_bypass m FROM users WHERE id = ?', k.id)).m, 0);
  assert.equal((await bir('SELECT COUNT(*) n FROM maintenance_devices WHERE user_id = ?', k.id)).n, 0);
  assert.equal((await bir('SELECT maintenance_bypass m FROM users WHERE id = ?', baska.id)).m, 1);
  assert.equal((await bir('SELECT COUNT(*) n FROM maintenance_devices WHERE user_id = ?', baska.id)).n, 1);
});
