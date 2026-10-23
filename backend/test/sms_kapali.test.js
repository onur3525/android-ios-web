// SUNUCU SMS'İ KAPALI (23 Eki, işletmeci kararı "A")
//   Doğrulama kodlarını Firebase gönderir. SMS sağlayıcısı yoksa yönetici
//   bildirimleri SMS DENEMEZ (başarısız kayıt üretmez), e-postayla gider;
//   panel SMS'i uyarı saymaz. Sağlayıcı tanımlanınca SMS yeniden devreye girer.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { config } = await import('../src/config.js');
const { simdi } = await import('../src/db.js');
const { kullaniciyaBildir } = await import('../src/bildirim.js');
const { genelDurum } = await import('../src/sistem_izleme.js');
const { kanalKaynaklari } = await import('../src/entegrasyon.js');

let db; let u; const eskiSms = { ...config.sms };
before(async () => {
  db = await testDb();
  const id = randomUUID();
  await db.prepare(`INSERT INTO users (id, phone, email, name, password_hash, phone_verified, email_verified, roles, active_role, status, terms_accepted, failed_logins, created_at, updated_at)
    VALUES (?, '5390000001', 'k@ornek.com', 'Kişi Bir', 'x', TRUE, TRUE, 'CUSTOMER', 'CUSTOMER', 'ACTIVE', TRUE, 0, ?, ?)`).run(id, simdi(), simdi());
  u = await db.prepare('SELECT * FROM users WHERE id = ?').get(id);
});
after(async () => { Object.assign(config.sms, eskiSms); await db?.close(); });

test('SMS sağlayıcısı yokken bildirim yalnız e-postayla gider; başarısız SMS kaydı oluşmaz', async () => {
  config.sms.ad = 'yok';
  const r = await kullaniciyaBildir(db, u, 'ILAN_KALDIRILDI', { ILAN: 'Test (No: 1)', NEDEN: 'Kurallara aykırı içerik' });
  assert.deepEqual(r.map((x) => x.channel), ['EMAIL']);
  assert.equal((await db.prepare(`SELECT COUNT(*) n FROM outbound_messages WHERE channel = 'SMS'`).get()).n, 0);
  const kanallar = await kanalKaynaklari(db);
  const sms = kanallar.find((k) => k.type === 'SMS');
  assert.equal(sms.source, 'yok');
  const g = genelDurum({ veritabaniOk: true, api: { last15m: { requests: 0 } }, kaynak: { cpu: {}, memory: { percent: 5 } }, yedek: { configured: true, checkOk: true, status: 'AVAILABLE' }, entegrasyonlar: [], silmeTukenen: 0, kanallar: [sms] });
  assert.equal(g.status, 'OK', 'bilinçli kapalı SMS uyarı değildir');
});

test('SMS sağlayıcısı varsa SMS de denenir (yeniden devreye girer)', async () => {
  Object.assign(config.sms, eskiSms); // test ortamı: geliştirme kaydı
  const r = await kullaniciyaBildir(db, u, 'ILAN_KALDIRILDI', { ILAN: 'Test (No: 2)', NEDEN: 'Kurallara aykırı içerik' });
  assert.deepEqual(r.map((x) => x.channel), ['SMS', 'EMAIL']);
});
