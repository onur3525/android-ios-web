// KAYIT — Kullanım Sözleşmesi onayı SUNUCUDA zorunlu (15 Eki, işletmeci kararı).
// Önceden sunucu onayı hiç denetlemeden terms_accepted=TRUE yazıyordu.
// 16 Eki: ayrı 18 yaş beyanı kaldırıldı — yaş koşulu Kullanım Sözleşmesi
// madde 4'te; sözleşme kabulüyle beyan edilir.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { simdi } = await import('../src/db.js');
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');

let db, sunucu, taban;
before(async () => {
  db = await testDb();
  await tohumla(db);
  // Yayında bir Kullanım Koşulları ve Gizlilik Politikası sürümü olsun.
  for (const slug of ['terms', 'privacy', 'kvkk']) {
    await db.prepare(`INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_at)
      VALUES (?, ?, 1, 'metin', ?, '2026-10-15', 'PUBLISHED', ?)`).run(randomUUID(), slug, `ozet-${slug}`, simdi());
  }
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => { sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

async function istek(yol, govde) {
  const r = await fetch(taban + yol, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(govde) });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
async function kayit(tel, ek) {
  await db.prepare('UPDATE otp_codes SET created_at = ? WHERE phone = ?').run('2000-01-01T00:00:00.000Z', tel);
  await istek('/api/v1/auth/otp/request', { phone: tel, purpose: 'REGISTER' });
  return istek('/api/v1/auth/register', {
    phone: tel, password: 'sifre1234', name: 'Yaş Deneme', email: `y${tel}@ornek.com`, role: 'CUSTOMER',
    otpCode: globalThis.__sonOtp, platform: 'android', ...ek,
  });
}

test('koşul onayı olmadan kayıt reddedilir', async () => {
  const r = await kayit('5360000001', {});
  assert.equal(r.durum, 400);
  assert.equal(r.json.error.code, 'TERMS_REQUIRED');
  const r2 = await kayit('5360000001', { termsAccepted: 'true' });
  assert.equal(r2.json.error.code, 'TERMS_REQUIRED', 'yalnız gerçek true kabul edilir');
});

test('16 Eki: ayrı yaş beyanı istenmez; sözleşme onayıyla kayıt olur, beyan zamanı onay anıdır', async () => {
  const r = await kayit('5360000002', { termsAccepted: true, aydinlatmaAccepted: true });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const u = await db.prepare('SELECT age_confirmed_at, created_at FROM users WHERE phone = ?').get('5360000002');
  assert.ok(u.age_confirmed_at, 'sözleşme kabulüyle yaş beyanı zamanı kaydedilmeli');
  assert.equal(String(u.age_confirmed_at), String(u.created_at));
});

test('23 Eki: Aydınlatma Metni bilgilendirmesi olmadan kayıt SUNUCUDA reddedilir', async () => {
  for (const ek of [{ termsAccepted: true }, { termsAccepted: true, aydinlatmaAccepted: 'true' }]) {
    const r = await kayit('5360000003', ek);
    assert.equal(r.durum, 400);
    assert.equal(r.json.error.code, 'AYDINLATMA_REQUIRED');
  }
  assert.equal(await db.prepare('SELECT 1 FROM users WHERE phone = ?').get('5360000003'), undefined, 'hesap açılmaz');
});

test('onayla kayıt: yayındaki sürümlerin onayı (sürüm + SHA-256) kaydedilir', async () => {
  const r = await kayit('5360000005', { termsAccepted: true, aydinlatmaAccepted: true });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const u = await db.prepare('SELECT id, age_confirmed_at, terms_accepted FROM users WHERE phone = ?').get('5360000005');
  assert.ok(u.age_confirmed_at);
  const onaylar = await db.prepare('SELECT slug, version, sha256, platform FROM legal_acceptances WHERE user_id = ? ORDER BY slug').all(u.id);
  assert.deepEqual(onaylar.map((o) => [o.slug, Number(o.version), o.sha256, o.platform]),
    [['kvkk', 1, 'ozet-kvkk', 'android'], ['terms', 1, 'ozet-terms', 'android']]);
});

test('16 Eki: iki onaylı kayıt (aydinlatmaAccepted) Kullanım Sözleşmesi + Aydınlatma Metni onayı yazar; gizlilik yazılmaz', async () => {
  const r = await kayit('5360000004', { termsAccepted: true, aydinlatmaAccepted: true });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const u = await db.prepare('SELECT id FROM users WHERE phone = ?').get('5360000004');
  const onaylar = await db.prepare('SELECT slug FROM legal_acceptances WHERE user_id = ? ORDER BY slug').all(u.id);
  assert.deepEqual(onaylar.map((o) => o.slug), ['kvkk', 'terms']);
});
