// ŞİKÂYET ET + 5651 TRAFİK KAYDI + YASAL KİMLİK ARŞİVİ (29 Eki)
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { simdi } = await import('../src/db.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const { degisiklikOnayi, onayKimligi } = await import('./admin_onay.js');
const { silmeTalepleriniIsle } = await import('../src/routes/sohbet_talep.js');
const { yasalKayitBakimi } = await import('../src/trafik_kaydi.js');

const SIFRE = 'GucluSifre12345';
let db, sunucu, taban, hizmet, alan, usta, ucuncu;
const cerezler = {};

async function istek(yol, { yontem = 'GET', govde, token, rol = 'super_admin' } = {}) {
  const admin = yol.startsWith('/admin/');
  if (admin) await degisiklikOnayi(taban, yol, yontem, cerezler[rol]);
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: {
      ...(govde ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(admin ? { Cookie: cerezler[rol] ?? '', 'X-HC-Admin': '1' } : {}),
    },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  let json = null;
  try { json = m ? JSON.parse(m) : null; } catch { json = null; }
  return { durum: r.status, json, ham: m };
}
async function adminGiris(rol) {
  const sir = base32Uret();
  await db.prepare('INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
    .run(randomUUID(), `${rol}@sikayet.test`, rol, rol, sifreOzetle(SIFRE), sirSifrele(sir), simdi());
  const g = await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email: `${rol}@sikayet.test`, password: SIFRE }) });
  const c = g.headers.get('set-cookie').split(';')[0];
  const m = await fetch(`${taban}/admin/v1/auth/mfa`, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: c, 'X-HC-Admin': '1' }, body: JSON.stringify({ code: totpUret(sir) }) });
  assert.equal(m.status, 200);
  cerezler[rol] = c;
  onayKimligi(c, SIFRE, sir);
}
async function kisi(tel, rol) {
  await db.prepare('DELETE FROM rate_limits').run();
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, aydinlatmaAccepted: true, phone: tel, password: 'sifre1234', name: `Kişi ${tel.slice(-2)}`, email: `s${tel}@ornek.com`, role: rol, otpCode: globalThis.__sonOtp } });
  assert.equal(r.durum, 200, r.ham);
  return { token: r.json.accessToken, id: (await istek('/api/v1/users/me', { token: r.json.accessToken })).json.id };
}
async function ilanAc(k) {
  const l = await istek('/api/v1/listings', { yontem: 'POST', token: k.token, govde: { title: hizmet, location: 'Bornova', description: 'Mutfak dolabı kapağı tamiri gerekiyor' } });
  assert.ok(l.durum < 300, l.ham);
  return l.json.id;
}
const sikayet = (k, govde) => istek('/api/v1/reports', { yontem: 'POST', token: k.token, govde });

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  hizmet = (await db.prepare('SELECT name FROM services WHERE deleted_at IS NULL LIMIT 1').get()).name;
  alan = await kisi('5480000001', 'CUSTOMER');
  usta = await kisi('5480000002', 'PROVIDER');
  ucuncu = await kisi('5480000003', 'PROVIDER');
  await adminGiris('super_admin');
  await adminGiris('readonly');
});
after(async () => { sunucu?.closeAllConnections?.(); sunucu?.close(); await db?.close(); });

test('şikâyet: doğrulama kuralları (konu, neden, Diğer açıklaması, kendi içeriği)', async () => {
  const ilan = await ilanAc(alan);
  assert.equal((await sikayet(usta, { targetType: 'POST', targetId: ilan, reason: 'FRAUD' })).durum, 400);
  assert.equal((await sikayet(usta, { targetType: 'LISTING', targetId: ilan, reason: 'KÖTÜ' })).durum, 400);
  assert.equal((await sikayet(usta, { targetType: 'LISTING', targetId: ilan, reason: 'OTHER', note: 'kısa' })).durum, 400);
  assert.equal((await sikayet(usta, { targetType: 'LISTING', targetId: randomUUID(), reason: 'FRAUD' })).durum, 404);
  assert.equal((await sikayet(alan, { targetType: 'LISTING', targetId: ilan, reason: 'FRAUD' })).durum, 400, 'kendi ilanı');
  assert.equal((await sikayet(usta, { targetType: 'LISTING', targetId: ilan, reason: 'FRAUD', note: 'x'.repeat(501) })).durum, 400);
  const yok = await istek('/api/v1/reports', { yontem: 'POST', govde: { targetType: 'LISTING', targetId: ilan, reason: 'FRAUD' } });
  assert.equal(yok.durum, 401, 'oturum gerekir');
});

test('şikâyet: ilk kayıt OPEN; aynı içerik için ikinci şikâyet yeni kayıt açmaz', async () => {
  const ilan = await ilanAc(alan);
  const a = await sikayet(usta, { targetType: 'LISTING', targetId: ilan, reason: 'MISLEADING', note: 'Fiyat yanlış yazılmış' });
  assert.equal(a.durum, 200, a.ham);
  assert.equal(a.json.status, 'OPEN');
  const b = await sikayet(usta, { targetType: 'LISTING', targetId: ilan, reason: 'FRAUD' });
  assert.equal(b.json.id, a.json.id);
  assert.equal(b.json.duplicate, true);
  const s = await db.prepare('SELECT * FROM reports WHERE id = ?').get(a.json.id);
  assert.equal(s.target_owner_id, alan.id);
  assert.equal(s.reporter_id, usta.id);
});

test('yönetici: liste özetle gelir; REMOVE ilanı "Yönetim kaldırdı" yapar ve hedefin bütün açık şikâyetlerini kapatır', async () => {
  const ilan = await ilanAc(alan);
  const s1 = await sikayet(usta, { targetType: 'LISTING', targetId: ilan, reason: 'FRAUD' });
  await sikayet(ucuncu, { targetType: 'LISTING', targetId: ilan, reason: 'INSULT' });
  const liste = await istek('/admin/v1/reports?status=OPEN');
  assert.equal(liste.durum, 200, liste.ham);
  const satir = liste.json.find((x) => x.id === s1.json.id);
  assert.equal(satir.target.kind, 'LISTING');
  assert.equal(satir.openCountForTarget, 2);
  assert.equal((await istek(`/admin/v1/reports/${s1.json.id}/resolve`, { yontem: 'POST', govde: { action: 'REMOVE', reason: 'kısa' } })).durum, 400);
  const c = await istek(`/admin/v1/reports/${s1.json.id}/resolve`, { yontem: 'POST', govde: { action: 'REMOVE', reason: 'Dolandırıcılık şüphesi doğrulandı' } });
  assert.equal(c.durum, 200, c.ham);
  assert.equal(c.json.closedReports, 2);
  assert.equal((await db.prepare('SELECT status, removed_reason FROM listings WHERE id = ?').get(ilan)).status, 'ADMIN_REMOVED');
  const acik = await db.prepare(`SELECT COUNT(*) n FROM reports WHERE target_id = ? AND status = 'OPEN'`).get(ilan);
  assert.equal(Number(acik.n), 0);
  const d = await db.prepare(`SELECT action, after_json FROM audit_log WHERE action IN ('listing.remove','report.resolve') AND (target_id = ? OR target_id = ?) ORDER BY id`).all(ilan, s1.json.id);
  assert.deepEqual(d.map((x) => x.action), ['listing.remove', 'report.resolve']);
  assert.match(String(d[0].after_json), new RegExp(s1.json.id), 'kaldırma denetiminde şikâyet numarası');
  assert.equal((await istek(`/admin/v1/reports/${s1.json.id}/resolve`, { yontem: 'POST', govde: { action: 'DISMISS', reason: 'tekrar deneme' } })).durum, 409);
});

test('yönetici: kullanıcı şikâyeti → SUSPEND hesabı askıya alır; yorum → REMOVE; DISMISS; salt okur sonuçlandıramaz', async () => {
  const s = await sikayet(alan, { targetType: 'USER', targetId: ucuncu.id, reason: 'INSULT', note: 'Mesajda hakaret etti' });
  assert.equal(s.durum, 200, s.ham);
  assert.equal((await istek(`/admin/v1/reports/${s.json.id}/resolve`, { yontem: 'POST', govde: { action: 'REMOVE', reason: 'yanlış işlem' } })).durum, 400);
  assert.equal((await istek(`/admin/v1/reports/${s.json.id}/resolve`, { yontem: 'POST', rol: 'readonly', govde: { action: 'SUSPEND', reason: 'Hakaret içerikli mesaj' } })).durum, 403);
  const c = await istek(`/admin/v1/reports/${s.json.id}/resolve`, { yontem: 'POST', govde: { action: 'SUSPEND', reason: 'Hakaret içerikli mesaj' } });
  assert.equal(c.durum, 200, c.ham);
  assert.equal((await db.prepare('SELECT status FROM users WHERE id = ?').get(ucuncu.id)).status, 'SUSPENDED');

  const yorum = randomUUID();
  await db.prepare(`INSERT INTO reviews (id, provider_id, author_id, stars, text, status, created_at, published_at) VALUES (?, ?, ?, 1, 'Berbat ve kaba biri', 'PUBLISHED', ?, ?)`)
    .run(yorum, usta.id, alan.id, simdi(), simdi());
  const y = await sikayet(usta, { targetType: 'REVIEW', targetId: yorum, reason: 'INSULT' });
  assert.equal((await istek(`/admin/v1/reports/${y.json.id}/resolve`, { yontem: 'POST', govde: { action: 'REMOVE', reason: 'Hakaret içeren yorum' } })).durum, 200);
  assert.equal((await db.prepare('SELECT status FROM reviews WHERE id = ?').get(yorum)).status, 'ADMIN_DELETED');

  const ilan = await ilanAc(alan);
  const d = await sikayet(usta, { targetType: 'LISTING', targetId: ilan, reason: 'MISLEADING' });
  const r = await istek(`/admin/v1/reports/${d.json.id}/resolve`, { yontem: 'POST', govde: { action: 'DISMISS', reason: 'İlanda aykırılık yok' } });
  assert.equal(r.json.status, 'DISMISSED');
  assert.equal((await db.prepare('SELECT status FROM listings WHERE id = ?').get(ilan)).status, 'ACTIVE');
});

test('trafik kaydı: kayıt, giriş ve oturumlu değişiklikler IP + kaynak port + zamanla yazılır; okundu işareti yazılmaz', async () => {
  const k = await kisi('5480000010', 'CUSTOMER');
  const kayitlar = async () => db.prepare('SELECT * FROM trafik_kayitlari WHERE user_id = ? ORDER BY id').all(k.id);
  const ilk = await kayitlar();
  assert.equal(ilk[0].olay, 'REGISTER');
  assert.ok(ilk[0].ip);
  assert.ok(Number.isInteger(ilk[0].kaynak_port), 'doğrudan bağlantıda soket portu');
  assert.ok(ilk[0].created_at);
  const ilan = await ilanAc(k);
  await istek('/api/v1/notifications/read-all', { yontem: 'POST', token: k.token });
  const son = await kayitlar();
  const ilanKaydi = son.find((x) => x.olay === 'POST /api/v1/listings');
  assert.ok(ilanKaydi, JSON.stringify(son.map((x) => x.olay)));
  assert.equal(ilanKaydi.hedef_id, ilan);
  assert.ok(!son.some((x) => x.olay.includes('read-all')), 'okundu işareti kayda değmez');
  await assert.rejects(() => db.prepare('UPDATE trafik_kayitlari SET ip = ? WHERE id = ?').run('1.1.1.1', ilanKaydi.id), /değiştirilemez/);
});

test('hesap silinince: oturumlar silinir, trafik kayıtları KALIR, kimlik 365 gün yasal arşive alınır; şikâyet açıklaması silinir', async () => {
  const k = await kisi('5480000020', 'CUSTOMER');
  const ilan = await ilanAc(alan);
  await sikayet(k, { targetType: 'LISTING', targetId: ilan, reason: 'OTHER', note: 'Telefonum 05321234567 arayın' });
  const once = Number((await db.prepare('SELECT COUNT(*) n FROM trafik_kayitlari WHERE user_id = ?').get(k.id)).n);
  assert.ok(once >= 2);
  await db.prepare(`INSERT INTO account_requests (id, user_id, type, status, created_at, scheduled_for) VALUES (?, ?, 'DELETION', 'PENDING', ?, ?)`)
    .run(randomUUID(), k.id, simdi(), new Date(Date.now() - 1000).toISOString());
  await silmeTalepleriniIsle(db);
  assert.equal((await db.prepare('SELECT name FROM users WHERE id = ?').get(k.id)).name, 'Silinmiş Kullanıcı');
  assert.equal(Number((await db.prepare('SELECT COUNT(*) n FROM user_sessions WHERE user_id = ?').get(k.id)).n), 0);
  assert.equal(Number((await db.prepare('SELECT COUNT(*) n FROM trafik_kayitlari WHERE user_id = ?').get(k.id)).n), once);
  const a = await db.prepare('SELECT * FROM yasal_kimlik_arsivi WHERE user_id = ?').get(k.id);
  assert.equal(a.telefon, '5480000020');
  assert.equal(a.ad, 'Kişi 20');
  const gun = (Date.parse(a.saklama_bitis) - Date.parse(a.silinme_tarihi)) / 86_400_000;
  assert.equal(Math.round(gun), 365);
  assert.equal((await db.prepare('SELECT note FROM reports WHERE reporter_id = ?').get(k.id)).note, null);
});

test('yasal kayıt bakımı: 365 günü dolan trafik/kimlik ve 2 yılı dolan sonuçlanmış şikâyet silinir; yenileri kalır', async () => {
  const eski = new Date(Date.now() - 366 * 86_400_000).toISOString();
  await db.prepare(`INSERT INTO trafik_kayitlari (user_id, olay, ip, created_at) VALUES (NULL, 'ESKI', '10.0.0.1', ?)`).run(eski);
  await db.prepare(`INSERT INTO yasal_kimlik_arsivi (user_id, silinme_tarihi, saklama_bitis) VALUES (?, ?, ?)`).run(randomUUID(), eski, new Date(Date.now() - 1000).toISOString());
  const sid = randomUUID();
  await db.prepare(`INSERT INTO reports (id, reporter_id, target_type, target_id, reason, status, resolved_at, created_at) VALUES (?, ?, 'USER', ?, 'FRAUD', 'DISMISSED', ?, ?)`)
    .run(sid, alan.id, usta.id, new Date(Date.now() - 731 * 86_400_000).toISOString(), eski);
  const r = await yasalKayitBakimi(db);
  assert.ok(r.trafik >= 1 && r.kimlik >= 1 && r.sikayet >= 1, JSON.stringify(r));
  assert.equal(await db.prepare(`SELECT 1 FROM trafik_kayitlari WHERE olay = 'ESKI'`).get(), undefined);
  assert.ok(Number((await db.prepare('SELECT COUNT(*) n FROM trafik_kayitlari').get()).n) > 0, 'yeni kayıtlar kalır');
  assert.equal(await db.prepare('SELECT 1 FROM reports WHERE id = ?').get(sid), undefined);
});
