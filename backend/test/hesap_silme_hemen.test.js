// SİLME TALEBİNİ HEMEN UYGULA (4 Kas, işletmeci kararı)
//  · Yalnız kullanıcının AÇTIĞI bekleyen silme talebi; talepsiz silme yok.
//  · Yalnız süper yönetici (+ yeniden doğrulama); moderatör yapamaz.
//  · Otomatik silmeyle aynı kurallar: anonimleştirme, talep COMPLETED,
//    denetim kaydı; telefon ve e-posta hemen boşa çıkar (yeni kayıt açılır).
//  · İkinci kez uygulanamaz.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const { simdi } = await import('../src/db.js');
const { degisiklikOnayi, onayKimligi } = await import('./admin_onay.js');

let db, sunucu, taban;
const cerezler = {};
async function istek(yol, { yontem = 'GET', govde, token } = {}) {
  const r = await fetch(taban + yol, { method: yontem, headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: govde ? JSON.stringify(govde) : undefined });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
async function admin(cerez, yol, yontem = 'POST', govde = {}) {
  await degisiklikOnayi(taban, yol, yontem, cerez);
  const r = await fetch(taban + yol, { method: yontem, headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1', Cookie: cerez }, body: yontem === 'GET' ? undefined : JSON.stringify(govde) });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
async function yoneticiOl(email, rol) {
  const sir = base32Uret();
  await db.prepare(`INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)`)
    .run(randomUUID(), email, rol, rol, sifreOzetle('GucluSifre12345'), sirSifrele(sir), simdi());
  const a = await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email, password: 'GucluSifre12345' }) });
  const c = a.headers.get('set-cookie').split(';')[0];
  await fetch(`${taban}/admin/v1/auth/mfa`, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: c, 'X-HC-Admin': '1' }, body: JSON.stringify({ code: totpUret(sir) }) });
  onayKimligi(c, 'GucluSifre12345', sir);
  return c;
}
const kayit = (tel, email) => istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, aydinlatmaAccepted: true, phone: tel, password: 'GucluSifre12', name: 'Silinecek Kişi', email, role: 'CUSTOMER' } });

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  cerezler.sa = await yoneticiOl('sa@hc.test', 'super_admin');
  cerezler.mod = await yoneticiOl('mod@hc.test', 'moderator');
});
after(async () => { sunucu?.closeAllConnections?.(); sunucu?.close(); await db?.close(); });

test('kullanıcının silme talebi süper yöneticice hemen uygulanır; numara ve e-posta boşa çıkar', async () => {
  const tel = '5560000001';
  const r = await kayit(tel, 'sil@ornek.com');
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const t = await istek('/api/v1/profiles/me/deletion-request', { yontem: 'POST', token: r.json.accessToken, govde: { password: 'GucluSifre12' } });
  assert.equal(t.durum, 200, JSON.stringify(t.json));
  const talepId = t.json.id;

  const mod = await admin(cerezler.mod, `/admin/v1/account-requests/${talepId}/apply-now`);
  assert.equal(mod.durum, 403, 'moderatör uygulayamaz');

  const sa = await admin(cerezler.sa, `/admin/v1/account-requests/${talepId}/apply-now`);
  assert.equal(sa.durum, 200, JSON.stringify(sa.json));
  assert.equal(sa.json.ok, true);

  const u = await db.prepare('SELECT * FROM users WHERE id = (SELECT user_id FROM account_requests WHERE id = ?)').get(talepId);
  assert.ok(u.deleted_at, 'hesap silindi');
  assert.equal(u.email, null);
  assert.notEqual(u.phone, tel);
  assert.equal(u.name, 'Silinmiş Kullanıcı');
  assert.equal((await db.prepare('SELECT status FROM account_requests WHERE id = ?').get(talepId)).status, 'COMPLETED');
  const d = await db.prepare(`SELECT * FROM audit_log WHERE action = 'user.deletion.apply_now'`).get();
  assert.ok(d, 'denetim kaydı');
  assert.ok(!JSON.stringify(d).includes(tel) && !JSON.stringify(d).includes('sil@ornek.com'), 'denetimde kişisel veri yok');

  // Eski oturum kapandı; aynı numara ve e-postayla yeni hesap açılır.
  assert.equal((await istek('/api/v1/users/me', { token: r.json.accessToken })).durum, 401);
  const yeni = await kayit(tel, 'sil@ornek.com');
  assert.equal(yeni.durum, 200, JSON.stringify(yeni.json));

  // İkinci kez uygulanamaz.
  assert.equal((await admin(cerezler.sa, `/admin/v1/account-requests/${talepId}/apply-now`)).durum, 409);
});

test('talepsiz hesap silinemez; olmayan talep 404', async () => {
  assert.equal((await admin(cerezler.sa, `/admin/v1/account-requests/${randomUUID()}/apply-now`)).durum, 404);
  // Dondurma talebi silme talebi sayılmaz.
  const r = await kayit('5560000002', 'dondur@ornek.com');
  const f = await istek('/api/v1/profiles/me/freeze', { yontem: 'POST', token: r.json.accessToken, govde: {} });
  assert.equal(f.durum, 200, JSON.stringify(f.json));
  assert.equal((await admin(cerezler.sa, `/admin/v1/account-requests/${f.json.id}/apply-now`)).durum, 404);
});
