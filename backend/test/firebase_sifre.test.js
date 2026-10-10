// ŞİFRE KAYNAĞI TUTARLILIĞI — Firebase'e bağlı hesapta giriş, şifre
// doğrulama (hesap silme adımı), rol ekleme ve şifre değiştirme AYNI
// kaynağı kullanır. Firebase Identity Toolkit REST'i SAHTE (gerçek ağ yok).
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
const { config } = await import('../src/config.js');
const { sifreDogrula } = await import('../src/auth.js');

let db, sunucu, taban;
const asilFetch = globalThis.fetch;
// Sahte Firebase: e-posta → şifre
const fb = new Map();
const cagrilar = [];
let fbDurum = 'normal'; // 'normal' | 'kapali' (ağ hatası) | 'guncellemeHatasi'

before(async () => {
  config.firebaseWebApiKey = 'acik-web-anahtari-test';
  globalThis.fetch = async (url, secenek) => {
    const u = String(url);
    if (!u.startsWith('https://identitytoolkit.googleapis.com/')) return asilFetch(url, secenek);
    const govde = JSON.parse(secenek.body);
    cagrilar.push({ yol: new URL(u).pathname, govde });
    if (fbDurum === 'kapali') throw new Error('ağ yok');
    if (u.includes('accounts:signInWithPassword')) {
      if (fb.get(govde.email) !== govde.password) return new Response(JSON.stringify({ error: { message: 'INVALID_LOGIN_CREDENTIALS' } }), { status: 400 });
      return new Response(JSON.stringify(govde.returnSecureToken ? { idToken: `tok:${govde.email}` } : {}), { status: 200 });
    }
    if (u.includes('accounts:update')) {
      if (fbDurum === 'guncellemeHatasi') return new Response('{}', { status: 500 });
      fb.set(govde.idToken.slice(4), govde.password);
      return new Response('{}', { status: 200 });
    }
    return new Response('{}', { status: 404 });
  };
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => {
  globalThis.fetch = asilFetch;
  config.firebaseWebApiKey = '';
  sunucu.closeAllConnections?.();
  sunucu.close();
  await db?.close();
});

async function istek(yol, { yontem = 'GET', govde, token } = {}) {
  const r = await asilFetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}

/** Yerel şifresi 'sifre1234' olan hesap; firebase=true ise Firebase'e bağlı. */
async function hesap(tel, { firebase = true } = {}) {
  await db.prepare('UPDATE otp_codes SET created_at = ? WHERE phone = ?').run('2000-01-01T00:00:00.000Z', tel);
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const email = `k${tel}@ornek.com`;
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { phone: tel, password: 'sifre1234', name: 'Kişi', email, role: 'CUSTOMER', otpCode: globalThis.__sonOtp } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const me = await istek('/api/v1/users/me', { token: r.json.accessToken });
  if (firebase) {
    await db.prepare('UPDATE users SET firebase_uid = ? WHERE id = ?').run(`fb-${randomUUID()}`, me.json.id);
    fb.set(email, 'sifre1234');
  }
  return { token: r.json.accessToken, id: me.json.id, email, tel };
}
const yerelOzet = async (id) => (await db.prepare('SELECT password_hash FROM users WHERE id = ?').get(id)).password_hash;

test('Firebase\'den e-postayla sıfırlanan şifre: giriş, şifre doğrulama (hesap silme adımı) ve rol ekleme AYNI şifreyi kabul eder', async () => {
  const h = await hesap('5350000001');
  fb.set(h.email, 'YeniSifre99'); // kullanıcı şifresini Firebase e-postasıyla sıfırladı; yerel özet eski
  assert.equal((await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: h.tel, password: 'YeniSifre99' } })).durum, 200);
  // Önceden: giriş olurken hesap silmenin şifre adımı bu DOĞRU şifreyi reddediyordu.
  assert.equal((await istek('/api/v1/auth/verify-password', { yontem: 'POST', token: h.token, govde: { password: 'YeniSifre99' } })).durum, 204);
  assert.equal((await istek('/api/v1/auth/verify-password', { yontem: 'POST', token: h.token, govde: { password: 'sifre1234' } })).durum, 400, 'eski şifre artık geçersiz');
  // Yerel özet eşitlendi: Firebase'e ulaşılamazsa yedek doğrulama ESKİ şifreyi kabul etmez.
  assert.ok(sifreDogrula('YeniSifre99', await yerelOzet(h.id)));
  fbDurum = 'kapali';
  try {
    assert.equal((await istek('/api/v1/auth/verify-password', { yontem: 'POST', token: h.token, govde: { password: 'sifre1234' } })).durum, 400);
    assert.equal((await istek('/api/v1/auth/verify-password', { yontem: 'POST', token: h.token, govde: { password: 'YeniSifre99' } })).durum, 204);
  } finally { fbDurum = 'normal'; }
  // Rol ekleme de aynı kaynağı kullanır.
  await db.prepare('UPDATE otp_codes SET created_at = ? WHERE phone = ?').run('2000-01-01T00:00:00.000Z', h.tel);
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: h.tel, purpose: 'ROLE_ADD' } });
  assert.equal((await istek('/api/v1/auth/roles/add', { yontem: 'POST', token: h.token, govde: { role: 'PROVIDER', password: 'YeniSifre99', otpCode: globalThis.__sonOtp } })).durum, 204);
  // Hesap silme talebi akışı (Flutter: şifre doğrula → talep) uçtan uca geçer.
  assert.equal((await istek('/api/v1/profiles/me/deletion-request', { yontem: 'POST', token: h.token, govde: {} })).durum, 200);
});

test('uygulama içi şifre değiştirme Firebase şifresini de değiştirir; yeni şifreyle giriş olur, eskiyle olmaz', async () => {
  const h = await hesap('5350000002');
  cagrilar.length = 0;
  const r = await istek('/api/v1/auth/password/change', { yontem: 'POST', token: h.token, govde: { currentPassword: 'sifre1234', newPassword: 'Degisti2026' } });
  assert.equal(r.durum, 204, JSON.stringify(r.json));
  assert.equal(fb.get(h.email), 'Degisti2026', 'Firebase şifresi güncellenmeli');
  assert.ok(cagrilar.some((c) => c.yol.endsWith('accounts:update') && c.govde.idToken === `tok:${h.email}`));
  assert.ok(sifreDogrula('Degisti2026', await yerelOzet(h.id)));
  assert.equal((await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: h.tel, password: 'Degisti2026' } })).durum, 200);
  assert.equal((await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: h.tel, password: 'sifre1234' } })).durum, 401);
});

test('şifre değiştirme: yanlış mevcut şifre ya da Firebase hatası → iki kaynak da DEĞİŞMEZ', async () => {
  const h = await hesap('5350000003');
  const once = await yerelOzet(h.id);
  cagrilar.length = 0;
  assert.equal((await istek('/api/v1/auth/password/change', { yontem: 'POST', token: h.token, govde: { currentPassword: 'yanlis-sifre', newPassword: 'Degisti2026' } })).json.error.code, 'WRONG_PASSWORD');
  assert.ok(!cagrilar.some((c) => c.yol.endsWith('accounts:update')), 'yanlış şifrede Firebase güncellenmez');
  fbDurum = 'guncellemeHatasi';
  try {
    const r = await istek('/api/v1/auth/password/change', { yontem: 'POST', token: h.token, govde: { currentPassword: 'sifre1234', newPassword: 'Degisti2026' } });
    assert.equal(r.durum, 503);
  } finally { fbDurum = 'normal'; }
  assert.equal(await yerelOzet(h.id), once, 'yerel şifre değişmemeli');
  assert.equal(fb.get(h.email), 'sifre1234');
  assert.equal((await istek('/api/v1/users/me', { token: h.token })).durum, 200, 'oturum iptal edilmemeli');
});

test('Firebase\'e bağlı OLMAYAN hesap: davranış aynen (yalnız yerel özet, Firebase çağrısı yok)', async () => {
  const h = await hesap('5350000004', { firebase: false });
  cagrilar.length = 0;
  assert.equal((await istek('/api/v1/auth/verify-password', { yontem: 'POST', token: h.token, govde: { password: 'sifre1234' } })).durum, 204);
  assert.equal((await istek('/api/v1/auth/password/change', { yontem: 'POST', token: h.token, govde: { currentPassword: 'sifre1234', newPassword: 'Degisti2026' } })).durum, 204);
  assert.equal(cagrilar.length, 0);
  assert.ok(sifreDogrula('Degisti2026', await yerelOzet(h.id)));
  assert.ok(simdi());
});
