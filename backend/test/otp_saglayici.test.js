// SMS sağlayıcısı ULAŞILAMAZ ya da HİÇ YAPILANDIRILMAMIŞSA OTP akışı:
//   · sessiz "gönderildi" yok — kayıt outbound_messages'ta FAILED,
//   · REGISTER/PHONE_CHANGE → 503 EXTERNAL_SERVICE_ERROR,
//   · FORGOT/LOGIN yanıtı NÖTR kalır (503 "numara kayıtlı" bilgisi sızdırmaz),
//   · başarısız gönderimin OTP kaydı geri alınır (60 sn bekleme boşa harcanmaz),
//   · gönderim yolu hiç yoksa numaraya BAKMADAN 503.
// ⚠ Gerçek SMS GÖNDERİLMEZ: webhook adresi kapalı bir yerel bağlantı
// noktasıdır (bağlantı reddedilir). Bu dosya gerçek sağlayıcıyı DOĞRULAMAZ.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_SESSIZ = '1';
process.env.HC_SMS_PROVIDER = 'webhook';
process.env.HC_SMS_WEBHOOK_URL = 'https://127.0.0.1:9/sms'; // kapalı port → bağlantı reddi
process.env.HC_SMS_WEBHOOK_TOKEN = 'yalniz-test';

const { simdi } = await import('../src/db.js');
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { config } = await import('../src/config.js');

let db, sunucu, taban;
const KAYITLI = '5327770001';

async function otpIste(phone, purpose) {
  const r = await fetch(`${taban}/api/v1/auth/otp/request`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ phone, purpose }),
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}

before(async () => {
  db = await testDb();
  await tohumla(db);
  await db.prepare(`INSERT INTO users (id, phone, email, name, password_hash, phone_verified, email_verified, roles, active_role, status, terms_accepted, failed_logins, created_at, updated_at)
    VALUES (?, ?, NULL, 'T', 'x', TRUE, FALSE, 'CUSTOMER', 'CUSTOMER', 'ACTIVE', TRUE, 0, ?, ?)`).run(randomUUID(), KAYITLI, simdi(), simdi());
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => {
  sunucu?.close();
  await db?.close();
});

test('sağlayıcı hatası: REGISTER 503 döner, FAILED kaydedilir, OTP kaydı geri alınır', async () => {
  const tel = '5327770002';
  const r = await otpIste(tel, 'REGISTER');
  assert.equal(r.durum, 503, JSON.stringify(r.json));
  assert.equal(r.json.error.code, 'EXTERNAL_SERVICE_ERROR');
  const m = await db.prepare(`SELECT status, body FROM outbound_messages WHERE target = ? ORDER BY created_at DESC`).get(`+90${tel}`);
  assert.equal(m.status, 'FAILED');
  assert.doesNotMatch(m.body, /\d{6}/, 'OTP kodu kayda düz yazılmamalı');
  const k = await db.prepare('SELECT COUNT(*) n FROM otp_codes WHERE phone = ?').get(tel);
  assert.equal(Number(k.n), 0, 'ulaşmayan kodun kaydı kalmamalı');
  // 60 sn bekleme uygulanmaz: hemen yeniden denenebilir (yine 503, 429 değil).
  assert.equal((await otpIste(tel, 'REGISTER')).durum, 503);
});

test('sağlayıcı hatası: FORGOT yanıtı kayıtlı ve kayıtsız numarada AYNI (nötr)', async () => {
  const kayitli = await otpIste(KAYITLI, 'FORGOT');
  const kayitsiz = await otpIste('5327770099', 'FORGOT');
  assert.equal(kayitli.durum, 204);
  assert.equal(kayitsiz.durum, 204);
  const m = await db.prepare(`SELECT status FROM outbound_messages WHERE target = ? ORDER BY created_at DESC`).get(`+90${KAYITLI}`);
  assert.equal(m.status, 'FAILED', 'başarısızlık kayıtta görünür olmalı');
});

test('gönderim yolu hiç yoksa (sağlayıcı tanımsız + entegrasyon yok) numaraya bakmadan 503', async () => {
  const eski = config.sms;
  config.sms = { ad: 'yok' }; // üretimde HC_SMS_PROVIDER tanımsız hâli
  try {
    const once = Number((await db.prepare('SELECT COUNT(*) n FROM outbound_messages').get()).n);
    for (const [tel, amac] of [[KAYITLI, 'FORGOT'], ['5327770098', 'FORGOT'], ['5327770097', 'REGISTER']]) {
      const r = await otpIste(tel, amac);
      assert.equal(r.durum, 503, `${tel}/${amac}`);
      assert.equal(r.json.error.code, 'EXTERNAL_SERVICE_ERROR');
    }
    const sonra = Number((await db.prepare('SELECT COUNT(*) n FROM outbound_messages').get()).n);
    assert.equal(sonra, once, 'gönderim yolu yokken sağlayıcıya istek denenmez');
  } finally {
    config.sms = eski;
  }
});

test('sağlayıcı tanımsızken doğrudan gönderim FAILED + açık neden (sessiz başarı yok)', async () => {
  const { gonder } = await import('../src/bildirim.js');
  const eski = config.eposta;
  config.eposta = { ad: 'yok' };
  try {
    const r = await gonder(db, { kanal: 'EMAIL', hedef: 'a@ornek.com', sablon: 'HESAP_ASKI_KALDIRILDI', degerler: {} });
    assert.equal(r.status, 'FAILED');
    const m = await db.prepare('SELECT provider_response FROM outbound_messages WHERE id = ?').get(r.id);
    assert.match(m.provider_response, /sağlayıcısı yapılandırılmamış/);
  } finally {
    config.eposta = eski;
  }
});
