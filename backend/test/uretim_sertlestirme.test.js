// PRODUCTION ÖNCESİ SON SERTLEŞTİRME — regresyon testleri
//   · Teklif talebi: taraf olmayan HİÇBİR uçta talebe erişemez (404); taraf,
//     aktif rolü ne olursa olsun kendi talebini okur (rol ≠ sahiplik)
//   · İlan/teklif/sohbet/bildirim/oturum/dosya uçlarında ID değiştirme (IDOR)
//   · Admin izin matrisi: rol × uç; iletişim maskesi (SMS/E-posta kayıtları)
//   · Gelen Talepler (destek talepleri): gerçek kayıt, sahiplik, admin yanıtı
//   · Hesap silme firebase_uid'yi temizler (yeniden kayıt çakışmaz)
//   · Çıkış / tek oturum sonlandırma o oturumun soketini kapatır
//   · SSRF: entegrasyon adresleri iç ağa çözülemez
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { simdi } = await import('../src/db.js');
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { gercekZamanliKur } = await import('../src/gercek_zamanli.js');
const { olaylar } = await import('../src/olaylar.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const { silmeTalepleriniIsle } = await import('../src/routes/sohbet_talep.js');
const { ozelAdresMi, disAdresSorunu, guvenliIstek, guvenliLookup } = await import('../src/ag_guvenligi.js');

let db, sunucu, taban;
const adminCerez = {};

async function istek(yol, { yontem = 'GET', govde, token, rol, gerekce } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: {
      ...(gerekce ? { 'X-HC-Reason': encodeURIComponent(gerekce) } : {}),
      ...(govde ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(yol.startsWith('/admin/') ? { 'X-HC-Admin': '1', Cookie: adminCerez[rol ?? 'super_admin'] ?? '' } : {}),
    },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}

async function kisi(tel, rol) {
  // Bu dosya çok sayıda hesap açar: IP başına OTP sınırı (saatte 20) test
  // kurulumunu engellemesin (sınırın kendisi bu dosyanın son testinde sınanır).
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'otp_ip:%'`).run();
  await db.prepare('UPDATE otp_codes SET created_at = ? WHERE phone = ?').run('2000-01-01T00:00:00.000Z', tel);
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, ageConfirmed: true, phone: tel, password: 'sifre1234', name: `Kişi ${tel.slice(-2)}`, email: `k${tel}@ornek.com`, role: rol, otpCode: globalThis.__sonOtp } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const me = await istek('/api/v1/users/me', { token: r.json.accessToken });
  return { token: r.json.accessToken, refresh: r.json.refreshToken, id: me.json.id };
}

async function adminGiris(rol) {
  const sir = base32Uret();
  const email = `${rol}@hc.test`;
  await db.prepare(`INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)`)
    .run(randomUUID(), email, rol, rol, sifreOzetle('GucluSifre12345'), sirSifrele(sir), simdi());
  const a = await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email, password: 'GucluSifre12345' }) });
  const c = a.headers.get('set-cookie').split(';')[0];
  const m = await fetch(`${taban}/admin/v1/auth/mfa`, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: c, 'X-HC-Admin': '1' }, body: JSON.stringify({ code: totpUret(sir) }) });
  assert.equal(m.status, 200);
  // MFA'dan hemen sonraki istek tam oturumla çalışmalı (oturum yükseltmesi beklenir).
  const me = await fetch(`${taban}/admin/v1/auth/me`, { headers: { Cookie: c } });
  assert.equal(me.status, 200, `${rol}: MFA sonrası ilk istek`);
  adminCerez[rol] = c;
}

let kat, hiz;
before(async () => {
  db = await testDb();
  await olaylar.kur(db);
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  gercekZamanliKur(sunucu, db);
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  for (const rol of ['super_admin', 'moderator', 'content', 'operations', 'readonly']) await adminGiris(rol);
  const s = await db.prepare('SELECT s.name hizmet, c.name kategori FROM services s JOIN categories c ON c.id = s.category_id LIMIT 1').get();
  kat = s.kategori; hiz = s.hizmet;
});
after(async () => {
  sunucu.closeAllConnections?.();
  sunucu.close();
  // Önce LISTEN bağlantısı (olcekleme.test.js ile aynı sıra), sonra havuz.
  await olaylar.kapat();
  await db?.close();
});

// ═════ 1-2 · TEKLİF TALEBİ: TARAF DENETİMİ ═════
test('teklif talebi: taraf olmayan hiçbir uçta talebe erişemez (404, varlık sızmaz)', async () => {
  const alan = await kisi('5340000001', 'CUSTOMER');
  const usta = await kisi('5340000002', 'PROVIDER');
  const yabanciAlan = await kisi('5340000003', 'CUSTOMER');
  const yabanciUsta = await kisi('5340000004', 'PROVIDER');
  const t = await istek('/api/v1/teklif-talepleri', { yontem: 'POST', token: alan.token, govde: { saglayiciId: usta.id, kategori: kat, hizmet: hiz, aciklama: 'mutfakta acil iş var', iletisimTercihi: 'yalnizMesaj' } });
  assert.equal(t.durum, 200, JSON.stringify(t.json));
  const id = t.json.id;
  for (const y of [yabanciAlan, yabanciUsta]) {
    assert.equal((await istek(`/api/v1/teklif-talepleri/${id}`, { token: y.token })).durum, 404);
    for (const [u, g] of [['teklif', { fiyat: 100 }], ['sec', {}], ['reddet', {}], ['tamamla', {}], ['mesajlar', { metin: 'selam' }], ['okundu', {}], ['review', { stars: 5, text: 'x' }]]) {
      assert.equal((await istek(`/api/v1/teklif-talepleri/${id}/${u}`, { yontem: 'POST', token: y.token, govde: g })).durum, 404, `${u}: taraf olmayan`);
    }
    const liste = await istek('/api/v1/teklif-talepleri', { token: y.token });
    assert.ok(!liste.json.some((x) => x.id === id), 'listede de görünmez');
  }
  // Var olmayan kimlikle aynı yanıt (varlık bilgisi sızmaz).
  assert.equal((await istek(`/api/v1/teklif-talepleri/${randomUUID()}`, { token: yabanciAlan.token })).durum, 404);
  // Talep durumu değişmemiş olmalı.
  assert.equal((await istek(`/api/v1/teklif-talepleri/${id}`, { token: alan.token })).json.durum, 'BEKLEMEDE');
});

test('teklif talebi: AKTİF ROL ile SAHİPLİK karışmaz', async () => {
  // İki rollü kullanıcı hizmet alan olarak talep açar, sonra hizmet veren rolüne geçer.
  const ikiRollu = await kisi('5340000011', 'CUSTOMER');
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: '5340000011', purpose: 'ROLE_ADD' } });
  assert.equal((await istek('/api/v1/auth/roles/add', { yontem: 'POST', token: ikiRollu.token, govde: { role: 'PROVIDER', password: 'sifre1234', otpCode: globalThis.__sonOtp } })).durum, 204);
  await istek('/api/v1/users/me/active-role', { yontem: 'POST', token: ikiRollu.token, govde: { role: 'CUSTOMER' } });
  const usta = await kisi('5340000012', 'PROVIDER');
  const t = await istek('/api/v1/teklif-talepleri', { yontem: 'POST', token: ikiRollu.token, govde: { saglayiciId: usta.id, kategori: kat, hizmet: hiz, aciklama: 'banyoda su kaçağı var', iletisimTercihi: 'telefonGoster' } });
  assert.equal(t.durum, 200);
  await istek('/api/v1/users/me/active-role', { yontem: 'POST', token: ikiRollu.token, govde: { role: 'PROVIDER' } });
  // Taraf olduğu talebi aktif rolü farklıyken de OKUR (ekran rolü ayrıca denetler).
  assert.equal((await istek(`/api/v1/teklif-talepleri/${t.json.id}`, { token: ikiRollu.token })).durum, 200);
  // Ama aktif rolü hizmet veren olsa da bu talebe TEKLİF VEREMEZ (talepteki yeri hizmet alan).
  assert.equal((await istek(`/api/v1/teklif-talepleri/${t.json.id}/teklif`, { yontem: 'POST', token: ikiRollu.token, govde: { fiyat: 100 } })).durum, 403);
  // Gerçek hizmet veren, aktif rolü hizmet alan iken teklif veremez (rol kapısı).
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: '5340000012', purpose: 'ROLE_ADD' } });
  await istek('/api/v1/auth/roles/add', { yontem: 'POST', token: usta.token, govde: { role: 'CUSTOMER', password: 'sifre1234', otpCode: globalThis.__sonOtp } });
  assert.equal((await istek(`/api/v1/teklif-talepleri/${t.json.id}/teklif`, { yontem: 'POST', token: usta.token, govde: { fiyat: 100 } })).durum, 403);
  await istek('/api/v1/users/me/active-role', { yontem: 'POST', token: usta.token, govde: { role: 'PROVIDER' } });
  assert.equal((await istek(`/api/v1/teklif-talepleri/${t.json.id}/teklif`, { yontem: 'POST', token: usta.token, govde: { fiyat: 100 } })).durum, 200);
});

// ═════ 1 · İLAN / TEKLİF / SOHBET / BİLDİRİM / OTURUM — IDOR ═════
test('IDOR: başkasının ilanı, teklifi, sohbeti, bildirimi, oturumu ve dosyası', async () => {
  const sahip = await kisi('5340000021', 'CUSTOMER');
  const usta = await kisi('5340000022', 'PROVIDER');
  const baskaMusteri = await kisi('5340000023', 'CUSTOMER');
  const baskaUsta = await kisi('5340000024', 'PROVIDER');
  const l = await istek('/api/v1/listings', { yontem: 'POST', token: sahip.token, govde: { title: hiz, location: 'Konak', description: 'salon boyanacak acil' } });
  const o = await istek('/api/v1/offers', { yontem: 'POST', token: usta.token, govde: { listingId: l.json.id, amountTl: 500, note: '' } });
  // İlan: başka hizmet alan göremez, düzenleyemez, silemez, seçim yapamaz, değerlendiremez.
  assert.equal((await istek(`/api/v1/listings/${l.json.id}`, { token: baskaMusteri.token })).durum, 404);
  assert.equal((await istek(`/api/v1/listings/${l.json.id}`, { yontem: 'PATCH', token: baskaMusteri.token, govde: { description: 'ele geçirildi bu ilan' } })).durum, 404);
  assert.equal((await istek(`/api/v1/listings/${l.json.id}`, { yontem: 'DELETE', token: baskaMusteri.token })).durum, 404);
  assert.notEqual((await istek(`/api/v1/listings/${l.json.id}/selected-offer`, { yontem: 'PUT', token: baskaMusteri.token, govde: { offerId: o.json.id } })).durum, 200);
  assert.notEqual((await istek(`/api/v1/listings/${l.json.id}/review`, { yontem: 'POST', token: baskaMusteri.token, govde: { stars: 1, text: 'x' } })).durum, 200);
  assert.equal((await istek(`/api/v1/listings/${l.json.id}`, { token: sahip.token })).json.selectedOfferId, null);
  // İletişim ve sohbet: yalnız iki taraf.
  for (const y of [baskaMusteri, baskaUsta]) {
    assert.equal((await istek(`/api/v1/contact/${o.json.id}`, { token: y.token })).durum, 404);
    assert.equal((await istek(`/api/v1/offers/${o.json.id}/communication`, { yontem: 'POST', token: y.token })).durum, 404);
    assert.equal((await istek(`/api/v1/messages/${o.json.id}`, { token: y.token })).durum, 404);
    assert.equal((await istek('/api/v1/messages', { yontem: 'POST', token: y.token, govde: { offerId: o.json.id, text: 'x' } })).durum, 404);
    assert.equal((await istek(`/api/v1/messages/${o.json.id}/read`, { yontem: 'POST', token: y.token })).durum, 404);
  }
  // Bildirim: başkasının bildirimi okundu işaretlenemez.
  const n = (await istek('/api/v1/notifications', { token: sahip.token })).json[0];
  assert.ok(n, 'sahibe teklif bildirimi düşmüş olmalı');
  assert.equal((await istek(`/api/v1/notifications/${n.id}/read`, { yontem: 'POST', token: baskaMusteri.token })).json.changed, 0);
  assert.equal((await istek('/api/v1/notifications/unread-count', { token: sahip.token })).json.count >= 1, true);
  // Oturum: başkasının oturumu sonlandırılamaz.
  const oturum = (await istek('/api/v1/auth/sessions', { token: sahip.token })).json[0];
  assert.equal((await istek(`/api/v1/auth/sessions/${oturum.jti}/revoke`, { yontem: 'POST', token: baskaMusteri.token })).durum, 404);
  assert.equal((await istek('/api/v1/users/me', { token: sahip.token })).durum, 200);
  // Dosya: başkasının bekleyen yüklemesi iptal edilemez.
  const ref = `u/${sahip.id}/${randomUUID()}.jpg`;
  await db.prepare(`INSERT INTO storage_objects (ref, owner_id, kind, content_type, size_bytes, status, created_at) VALUES (?, ?, 'listing-photo', 'image/jpeg', 10, 'PENDING', ?)`).run(ref, sahip.id, simdi());
  assert.equal((await istek('/api/v1/storage/uploads/pending', { yontem: 'DELETE', token: baskaMusteri.token, govde: { storageRef: ref } })).json.ok, false);
  assert.equal((await db.prepare('SELECT status FROM storage_objects WHERE ref = ?').get(ref)).status, 'PENDING');
  // Push jetonu: başkasının jetonu silinemez.
  await db.prepare(`INSERT INTO push_tokens (token, user_id, platform, created_at, last_seen) VALUES (?, ?, 'android', ?, ?)`).run('sahip-jetonu-xxxxxxxxxxxxxxxxxxx', sahip.id, simdi(), simdi());
  await istek('/api/v1/devices/push-token', { yontem: 'DELETE', token: baskaMusteri.token, govde: { token: 'sahip-jetonu-xxxxxxxxxxxxxxxxxxx' } });
  assert.equal((await db.prepare('SELECT user_id FROM push_tokens WHERE token = ?').get('sahip-jetonu-xxxxxxxxxxxxxxxxxxx')).user_id, sahip.id);
  // Kullanıcı token'ı admin API'sinde geçersiz.
  const r = await fetch(`${taban}/admin/v1/users`, { headers: { Authorization: `Bearer ${sahip.token}` } });
  assert.equal(r.status, 401);
});

// ═════ 3 · ADMİN İZİN MATRİSİ ═════
test('admin izin matrisi: her rol yalnız menüsündeki işlevlere erişir', async () => {
  const MATRIS = [
    // [yöntem, yol, izinli roller]
    ['GET', '/admin/v1/stats', ['super_admin', 'moderator', 'readonly']],
    ['GET', '/admin/v1/users', ['super_admin', 'moderator', 'readonly']],
    ['GET', '/admin/v1/listings', ['super_admin', 'moderator', 'readonly']],
    ['GET', '/admin/v1/offers', ['super_admin', 'moderator', 'readonly']],
    ['GET', '/admin/v1/teklif-talepleri', ['super_admin', 'moderator', 'readonly']],
    ['GET', '/admin/v1/reviews', ['super_admin', 'moderator', 'readonly']],
    ['GET', '/admin/v1/catalog/categories', ['super_admin', 'content', 'moderator', 'operations', 'readonly']],
    ['GET', '/admin/v1/regions/cities', ['super_admin', 'content', 'moderator', 'operations', 'readonly']],
    ['GET', '/admin/v1/legal', ['super_admin', 'content', 'readonly']],
    ['GET', '/admin/v1/support', ['super_admin', 'content', 'readonly']],
    ['GET', '/admin/v1/announcements', ['super_admin', 'content']],
    ['GET', '/admin/v1/config/app', ['super_admin', 'operations', 'readonly']],
    ['GET', '/admin/v1/notifications/outbound', ['super_admin', 'moderator', 'operations']],
    ['GET', '/admin/v1/account-requests', ['super_admin', 'moderator', 'readonly']],
    ['GET', '/admin/v1/support/tickets', ['super_admin', 'moderator', 'readonly']],
    ['GET', '/admin/v1/feedback', ['super_admin', 'moderator', 'readonly']],
    ['GET', '/admin/v1/integrations', ['super_admin', 'operations']],
    ['GET', '/admin/v1/deletion-queues', ['super_admin', 'operations']],
    ['GET', '/admin/v1/admins', ['super_admin']],
    ['GET', '/admin/v1/audit-log', ['super_admin']],
  ];
  for (const [yontem, yol, izinli] of MATRIS) {
    for (const rol of ['super_admin', 'moderator', 'content', 'operations', 'readonly']) {
      const r = await istek(yol.replace('/admin/v1', '/admin/v1'), { yontem, rol });
      if (izinli.includes(rol)) assert.equal(r.durum, 200, `${rol} ${yol}`);
      else assert.equal(r.durum, 403, `${rol} ${yol} reddedilmeli`);
    }
  }
  // Yazma uçları: salt okunur rol hiçbirini yapamaz.
  const kat0 = (await db.prepare('SELECT id FROM categories LIMIT 1').get()).id;
  for (const [yontem, yol, govde] of [
    ['PATCH', `/admin/v1/catalog/categories/${kat0}`, { sort: 1 }],
    ['POST', '/admin/v1/regions/cities', { name: 'Deneme İli' }],
    ['PUT', '/admin/v1/support', { description: 'açıklama metni uzun', email: 'd@e.com' }],
    ['POST', '/admin/v1/announcements', { title: 'Başlık', body: 'Duyuru metni' }],
    ['PUT', '/admin/v1/config/app/web', { maintenanceActive: false }],
    ['POST', '/admin/v1/admins', { email: 'x@y.z', name: 'X', role: 'readonly', password: 'GucluSifre12345' }],
  ]) {
    assert.equal((await istek(yol, { yontem, govde, rol: 'readonly' })).durum, 403, `readonly ${yontem} ${yol}`);
  }
  // Kritik işlemler yeniden doğrulama ister (MFA'dan > 5 dk sonra).
  await db.prepare('UPDATE admin_sessions SET reauth_at = ?').run('2000-01-01T00:00:00.000Z');
  const u = await kisi('5340000031', 'CUSTOMER');
  const r = await istek(`/admin/v1/users/${u.id}/suspend`, { yontem: 'POST', govde: { reason: 'deneme gerekçesi' }, rol: 'moderator' });
  assert.equal(r.json.error.code, 'REAUTH_REQUIRED');
  // Yıkıcı katalog/bölge kaldırma da yeniden doğrulama ister.
  const kat1 = (await db.prepare('SELECT id FROM categories LIMIT 1').get()).id;
  const hiz1 = (await db.prepare('SELECT id FROM services LIMIT 1').get()).id;
  const il1 = (await db.prepare('SELECT id FROM cities LIMIT 1').get()).id;
  for (const yol of [`/admin/v1/catalog/categories/${kat1}`, `/admin/v1/catalog/services/${hiz1}`, `/admin/v1/regions/cities/${il1}`]) {
    const x = await istek(yol, { yontem: 'DELETE', govde: { reason: 'deneme gerekçesi' }, rol: 'content' });
    assert.equal(x.json?.error?.code, 'REAUTH_REQUIRED', yol);
  }
  assert.ok(await db.prepare('SELECT 1 FROM categories WHERE id = ? AND deleted_at IS NULL').get(kat1), 'kategori silinmemiş olmalı');
  // CSRF: özel başlık olmadan yazma reddedilir.
  const csrf = await fetch(`${taban}/admin/v1/support/tickets/${randomUUID()}/close`, { method: 'POST', headers: { Cookie: adminCerez.super_admin, 'Content-Type': 'application/json' }, body: '{}' });
  assert.equal(csrf.status, 403);
});

test('yönetici yazışma görüntüleme gerekçe ister ve gerekçe denetime yazılır; iletişimsiz rol telefonla arayamaz', async () => {
  const sahip = await kisi('5340000093', 'CUSTOMER');
  const usta = await kisi('5340000094', 'PROVIDER');
  const l = await istek('/api/v1/listings', { yontem: 'POST', token: sahip.token, govde: { title: hiz, location: 'Konak', description: 'banyo tadilatı yapılacak' } });
  const o = await istek('/api/v1/offers', { yontem: 'POST', token: usta.token, govde: { listingId: l.json.id, amountTl: 800, note: '' } });
  assert.equal(o.durum, 200, JSON.stringify(o.json));
  const yol = `/admin/v1/chats/${o.json.id}/messages`;
  const gerekcesiz = await istek(yol, { rol: 'moderator' });
  assert.equal(gerekcesiz.durum, 400);
  assert.equal((await istek(yol, { rol: 'moderator', gerekce: 'abc' })).durum, 400, 'kısa gerekçe');
  assert.equal((await istek(`${yol}?reason=${encodeURIComponent('Şikâyet #12 incelemesi')}`, { rol: 'moderator' })).durum, 400, 'adres satırındaki gerekçe kabul edilmez (günlüğe düşer)');
  assert.equal((await istek(yol, { rol: 'moderator', gerekce: 'Şikâyet #12 incelemesi' })).durum, 200);
  const kayit = await db.prepare(`SELECT reason FROM audit_log WHERE action = 'chat.messages.view' AND target_id = ? ORDER BY created_at DESC`).get(o.json.id);
  assert.equal(kayit.reason, 'Şikâyet #12 incelemesi');
  assert.equal((await istek(yol, { rol: 'readonly', gerekce: 'yetkisiz deneme' })).durum, 403, 'gerekçe yetkinin yerini tutmaz');

  // Talep detayı da aynı kurala bağlı.
  const t = await istek('/api/v1/teklif-talepleri', { yontem: 'POST', token: sahip.token, govde: { saglayiciId: usta.id, kategori: kat, hizmet: hiz, aciklama: 'mutfak musluğu damlatıyor', iletisimTercihi: 'yalnizMesaj' } });
  assert.equal(t.durum, 200, JSON.stringify(t.json));
  assert.equal((await istek(`/admin/v1/teklif-talepleri/${t.json.id}`, { rol: 'super_admin' })).durum, 400);
  assert.equal((await istek(`/admin/v1/teklif-talepleri/${t.json.id}`, { rol: 'super_admin', gerekce: 'Destek talebi kontrolü' })).durum, 200);

  // readonly: maskeli liste; telefon/e-postayla arama SONUÇ VERMEZ (kayıt var mı sorgusu kapalı).
  const ro = await istek('/admin/v1/users?q=5340000093', { rol: 'readonly' });
  assert.equal(ro.durum, 200);
  assert.equal(ro.json.total, 0);
  const roEposta = await istek(`/admin/v1/users?q=${encodeURIComponent('k5340000093@ornek.com')}`, { rol: 'readonly' });
  assert.equal(roEposta.json.total, 0);
  const roAd = await istek(`/admin/v1/users?q=${encodeURIComponent('Kişi 93')}`, { rol: 'readonly' });
  assert.ok(roAd.json.total >= 1, 'adla arama sürer');
  assert.ok(roAd.json.items.every((u) => u.phone.includes('*')), 'readonly maskeli görür');
  const mod = await istek('/admin/v1/users?q=5340000093', { rol: 'moderator' });
  assert.equal(mod.json.total, 1);
  assert.equal(mod.json.items[0].phone, '5340000093');
});

test('SMS/E-posta kayıtları: iletişim bilgisi yalnız yetkili role açık, operations maskeli görür', async () => {
  const u = await kisi('5340000041', 'CUSTOMER');
  await db.prepare(`INSERT INTO outbound_messages (id, user_id, channel, target, template, body, status, attempts, created_at) VALUES (?, ?, 'SMS', '+905340000041', 'HESAP_ASKIYA_ALINDI', 'x', 'SENT', 1, ?)`).run(randomUUID(), u.id, simdi());
  await db.prepare(`INSERT INTO outbound_messages (id, user_id, channel, target, template, body, status, attempts, created_at) VALUES (?, ?, 'EMAIL', 'k5340000041@ornek.com', 'HESAP_ASKIYA_ALINDI', 'x', 'SENT', 1, ?)`).run(randomUUID(), u.id, simdi());
  const tam = (await istek('/admin/v1/notifications/outbound', { rol: 'moderator' })).json.filter((m) => m.userId === u.id).map((m) => m.target).sort();
  assert.deepEqual(tam, ['+905340000041', 'k5340000041@ornek.com']);
  const maskeli = (await istek('/admin/v1/notifications/outbound', { rol: 'operations' })).json.filter((m) => m.userId === u.id).map((m) => m.target).sort();
  assert.deepEqual(maskeli, ['+90534*****41', 'k***@ornek.com']);
});

// ═════ 4 · GELEN TALEPLER ═════
test('Gelen Talepler: kullanıcı talebi → admin listesi → yanıt (e-posta kaydı) → kullanıcı görür', async () => {
  const u = await kisi('5340000051', 'CUSTOMER');
  const baska = await kisi('5340000052', 'CUSTOMER');
  // Doğrulama
  assert.equal((await istek('/api/v1/support/tickets', { yontem: 'POST', token: u.token, govde: { subject: 'x', message: 'kısa' } })).durum, 400);
  assert.equal((await istek('/api/v1/support/tickets', { yontem: 'POST', govde: { subject: 'Konu', message: 'oturumsuz gönderim denemesi' } })).durum, 401);
  const t = await istek('/api/v1/support/tickets', { yontem: 'POST', token: u.token, govde: { subject: 'İlanım görünmüyor', message: 'Dün verdiğim ilan listede görünmüyor, yardımcı olur musunuz?', platform: 'android', appVersion: '1.0.0' } });
  assert.equal(t.durum, 200, JSON.stringify(t.json));
  assert.equal(t.json.status, 'OPEN');
  assert.match(t.json.ticketNo, /^\d+$/);
  // Sahiplik: başkası göremez, listesinde yok.
  assert.equal((await istek(`/api/v1/support/tickets/${t.json.id}`, { token: baska.token })).durum, 404);
  assert.deepEqual((await istek('/api/v1/support/tickets', { token: baska.token })).json, []);
  // Hesap dondurma/silme talepleriyle KARIŞMAZ.
  assert.ok(!(await istek('/admin/v1/account-requests')).json.some((a) => a.id === t.json.id));
  // Admin listesi: gerçek kayıt; readonly e-postayı maskeli görür, yanıtlayamaz.
  const liste = (await istek('/admin/v1/support/tickets?status=OPEN')).json;
  const satir = liste.find((x) => x.id === t.json.id);
  assert.equal(satir.userEmail, 'k5340000051@ornek.com');
  assert.equal((await istek('/admin/v1/support/tickets', { rol: 'readonly' })).json.find((x) => x.id === t.json.id).userEmail, 'k***@ornek.com');
  assert.equal((await istek(`/admin/v1/support/tickets/${t.json.id}/reply`, { yontem: 'POST', rol: 'readonly', govde: { body: 'yanıt' } })).durum, 403);
  assert.equal((await istek(`/admin/v1/support/tickets/${t.json.id}/reply`, { yontem: 'POST', rol: 'operations', govde: { body: 'yanıt' } })).durum, 403);
  assert.equal((await istek('/admin/v1/support/tickets?status=GECERSIZ')).durum, 400);
  // Detay denetim kaydına yazılır.
  const d = await istek(`/admin/v1/support/tickets/${t.json.id}`, { rol: 'moderator' });
  assert.equal(d.json.message, 'Dün verdiğim ilan listede görünmüyor, yardımcı olur musunuz?');
  assert.ok(await db.prepare(`SELECT 1 FROM audit_log WHERE action = 'support.ticket.view' AND target_id = ?`).get(t.json.id));
  // Yanıt: e-posta doğrulanmamış → kayıt FAILED ("doğrulanmış kanal yok"), yanıt yine kaydedilir.
  const y = await istek(`/admin/v1/support/tickets/${t.json.id}/reply`, { yontem: 'POST', rol: 'moderator', govde: { body: 'İlanınız yayında, uygulamayı yenileyin.' } });
  assert.equal(y.durum, 200, JSON.stringify(y.json));
  assert.equal(y.json.status, 'ANSWERED');
  assert.equal(y.json.email.status, 'FAILED');
  const kayit = await db.prepare('SELECT * FROM outbound_messages WHERE id = ?').get(y.json.email.id);
  assert.equal(kayit.template, 'DESTEK_YANITI'); assert.equal(kayit.channel, 'EMAIL'); assert.equal(kayit.provider_response, 'doğrulanmış kanal yok');
  // E-posta doğrulanmışsa yanıt e-postayla gider (geliştirme sağlayıcısı 'log').
  await db.prepare('UPDATE users SET email_verified = TRUE WHERE id = ?').run(u.id);
  const y2 = await istek(`/admin/v1/support/tickets/${t.json.id}/reply`, { yontem: 'POST', rol: 'super_admin', govde: { body: 'Ek bilgi: sorun giderildi.', close: true } });
  assert.equal(y2.json.email.status, 'SENT');
  assert.equal(y2.json.status, 'CLOSED');
  const e2 = await db.prepare('SELECT target, body FROM outbound_messages WHERE id = ?').get(y2.json.email.id);
  assert.equal(e2.target, 'k5340000051@ornek.com');
  assert.match(e2.body, /Ek bilgi: sorun giderildi\./);
  // Kapalı talebe yanıt verilmez.
  assert.equal((await istek(`/admin/v1/support/tickets/${t.json.id}/reply`, { yontem: 'POST', govde: { body: 'tekrar' } })).durum, 409);
  // Kullanıcı yanıtları uygulamada görür (yanıtlayan admin kimliği sızmaz).
  const g = await istek(`/api/v1/support/tickets/${t.json.id}`, { token: u.token });
  assert.equal(g.json.status, 'CLOSED');
  assert.deepEqual(g.json.replies.map((r) => r.body), ['İlanınız yayında, uygulamayı yenileyin.', 'Ek bilgi: sorun giderildi.']);
  assert.ok(!JSON.stringify(g.json).includes('@hc.test'));
  assert.ok(await db.prepare(`SELECT 1 FROM audit_log WHERE action = 'support.ticket.reply' AND target_id = ?`).get(t.json.id));
});

test('Gelen Talepler: kullanıcı başına hız sınırı; kapatma', async () => {
  const u = await kisi('5340000061', 'CUSTOMER');
  let son;
  for (let i = 0; i < 6; i++) son = await istek('/api/v1/support/tickets', { yontem: 'POST', token: u.token, govde: { subject: `Konu ${i}`, message: 'Bu bir destek talebi metnidir.' } });
  assert.equal(son.durum, 429);
  const ilk = (await istek('/api/v1/support/tickets', { token: u.token })).json.at(-1);
  assert.equal((await istek(`/admin/v1/support/tickets/${ilk.id}/close`, { yontem: 'POST', rol: 'moderator', govde: {} })).json.status, 'CLOSED');
  assert.equal((await istek(`/admin/v1/support/tickets/${ilk.id}/close`, { yontem: 'POST', rol: 'moderator', govde: {} })).durum, 409);
});

// ═════ HESAP SİLME / OTURUM ═════
test('hesap silme firebase_uid\'yi temizler: aynı Firebase kimliğiyle yeni hesap çakışmaz', async () => {
  const u = await kisi('5340000071', 'CUSTOMER');
  await db.prepare('UPDATE users SET firebase_uid = ? WHERE id = ?').run('fb-uid-silinecek', u.id);
  await istek('/api/v1/profiles/me/deletion-request', { yontem: 'POST', token: u.token, govde: { password: 'sifre1234' } });
  await db.prepare(`UPDATE account_requests SET scheduled_for = ? WHERE user_id = ?`).run('2000-01-01T00:00:00.000Z', u.id);
  await silmeTalepleriniIsle(db);
  const s = await db.prepare('SELECT firebase_uid, deleted_at, email FROM users WHERE id = ?').get(u.id);
  assert.equal(s.firebase_uid, null); assert.ok(s.deleted_at); assert.equal(s.email, null);
  // Aynı Firebase kimliği yeni hesaba bağlanabilir (tekil dizin çakışması yok).
  await db.prepare(`INSERT INTO users (id, phone, email, name, password_hash, roles, active_role, status, created_at, updated_at, firebase_uid)
    VALUES (?, '5340000071', NULL, 'Yeni', 'x', 'CUSTOMER', 'CUSTOMER', 'ACTIVE', ?, ?, 'fb-uid-silinecek')`).run(randomUUID(), simdi(), simdi());
  assert.equal((await istek('/api/v1/users/me', { token: u.token })).durum, 401);
});

function sio(token) {
  const ws = new WebSocket(`${taban.replace('http', 'ws')}/socket.io/?EIO=4&transport=websocket`);
  const gelen = [];
  let kapandi = false;
  ws.onclose = () => { kapandi = true; };
  ws.onmessage = (e) => {
    const p = String(e.data);
    if (p === '2') return ws.send('3');
    if (p.startsWith('0')) return ws.send(`40/ws,${JSON.stringify({ token })}`);
    gelen.push(p);
  };
  const bekle = async (k, ms = 3000) => {
    const son = Date.now() + ms;
    while (Date.now() < son) { if (k()) return true; await new Promise((ok) => setTimeout(ok, 30)); }
    return false;
  };
  return { ws, gelen, bekle, kapandiMi: () => kapandi };
}

test('çıkış ve tek oturum sonlandırma YALNIZ o oturumun soketini kapatır', async () => {
  const u = await kisi('5340000081', 'CUSTOMER');
  const g2 = await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: '5340000081', password: 'sifre1234' } });
  const g3 = await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: '5340000081', password: 'sifre1234' } });
  const s1 = sio(u.token); const s2 = sio(g2.json.accessToken); const s3 = sio(g3.json.accessToken);
  for (const s of [s1, s2, s3]) assert.ok(await s.bekle(() => s.gelen.some((p) => p.startsWith('40/ws'))));
  // 1) Oturum-1 çıkış yapar → yalnız s1 kapanır.
  assert.equal((await istek('/api/v1/auth/logout', { yontem: 'POST', token: u.token })).durum, 204);
  assert.ok(await s1.bekle(() => s1.kapandiMi()), 'çıkış yapan oturumun soketi kapanmalı');
  // 2) Oturum-2, oturum-3'ü sonlandırır → yalnız s3 kapanır.
  const oturumlar = (await istek('/api/v1/auth/sessions', { token: g2.json.accessToken })).json;
  const ucuncu = oturumlar.find((o) => !o.current);
  assert.equal((await istek(`/api/v1/auth/sessions/${ucuncu.jti}/revoke`, { yontem: 'POST', token: g2.json.accessToken })).durum, 204);
  assert.ok(await s3.bekle(() => s3.kapandiMi()), 'sonlandırılan oturumun soketi kapanmalı');
  await new Promise((ok) => setTimeout(ok, 150));
  assert.equal(s2.kapandiMi(), false, 'diğer oturumun soketi açık kalmalı');
  s2.ws.close();
});

// ═════ 7 · SSRF ═════
test('SSRF: özel/ayrılmış adresler ve iç ağ adları reddedilir', async () => {
  for (const ip of ['127.0.0.1', '10.1.2.3', '172.16.0.1', '172.31.255.255', '192.168.1.1', '169.254.169.254', '100.64.0.1', '0.0.0.0', '224.0.0.1',
    '::1', '::', 'fe80::1', 'fd00::1', '::ffff:127.0.0.1', '::ffff:7f00:1', '64:ff9b::a00:1']) {
    assert.equal(ozelAdresMi(ip), true, ip);
  }
  for (const ip of ['8.8.8.8', '1.1.1.1', '172.32.0.1', '2606:4700:4700::1111']) assert.equal(ozelAdresMi(ip), false, ip);
  for (const u of ['https://localhost/x', 'https://LOCALHOST./x', 'https://api.localhost/', 'https://db.internal/', 'https://metadata.google.internal/',
    'https://127.0.0.1/', 'https://[::1]/', 'https://169.254.169.254/latest/meta-data', 'https://10.0.0.5:8443/', 'http://ornek.com/', 'https://kullanici:sifre@ornek.com/']) {
    assert.ok(disAdresSorunu(u), u);
  }
  assert.equal(disAdresSorunu('https://sms-kopru.ornek.com/gonder'), null);
  // DNS kancası: ada özel adres çözülürse bağlantı kurulmaz.
  const hata = await new Promise((ok) => guvenliLookup('localhost', {}, (e) => ok(e)));
  assert.equal(hata?.code, 'HC_SSRF_ENGELLENDI');
  await assert.rejects(guvenliIstek('https://127.0.0.1:9/', { method: 'HEAD' }), /reddedildi/);
});

test('SSRF: admin iç ağ adresiyle entegrasyon oluşturamaz/güncelleyemez; bağlantı testi iç ağa gitmez', async () => {
  for (const url of ['https://127.0.0.1/sms', 'https://169.254.169.254/', 'https://localhost:8443/x']) {
    const r = await istek('/admin/v1/integrations', { yontem: 'POST', govde: { type: 'SMS', provider: 'webhook', config: { url } } });
    assert.equal(r.durum, 400, url);
  }
  assert.equal((await istek('/admin/v1/integrations', { yontem: 'POST', govde: { type: 'STORAGE', provider: 's3', config: { endpoint: 'https://10.0.0.9', bucket: 'kova', region: 'auto' } } })).durum, 400);
  const e = await istek('/admin/v1/integrations', { yontem: 'POST', govde: { type: 'SMS', provider: 'webhook', config: { url: 'https://sms-kopru.ornek.com/gonder' } } });
  assert.equal(e.durum, 200);
  assert.equal((await istek(`/admin/v1/integrations/${e.json.id}`, { yontem: 'PATCH', govde: { config: { url: 'https://127.0.0.1:6379/' } } })).durum, 400);
  // Eski (bu sürümden önce kaydedilmiş) bir iç adres veritabanında olsa bile test isteği atılmaz.
  await db.prepare('UPDATE integrations SET config_json = ?, secret_enc = ? WHERE id = ?').run(JSON.stringify({ url: 'https://127.0.0.1:9/' }), sirSifrele('{"token":"x"}'), e.json.id);
  const t = await istek(`/admin/v1/integrations/${e.json.id}/test`, { yontem: 'POST', govde: {} });
  assert.equal(t.json.ok, false);
  assert.match(t.json.message, /reddedildi/);
});

test('Gelen Talepler: Idempotency-Key ile yeniden deneme İKİNCİ kayıt açmaz; kullanıcı başkasının talebini kapatamaz/yanıtlayamaz', async () => {
  const u = await kisi('5340000091', 'CUSTOMER');
  const baska = await kisi('5340000092', 'CUSTOMER');
  const gonder = (anahtar, token = u.token) => fetch(`${taban}/api/v1/support/tickets`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, 'Idempotency-Key': anahtar },
    body: JSON.stringify({ subject: 'Bildirim gelmiyor', message: 'Telefonuma bildirim düşmüyor, kontrol eder misiniz?', platform: 'web', appVersion: '1.0.0' }),
  }).then(async (r) => ({ durum: r.status, json: await r.json() }));
  const a = await gonder('anahtar-1');
  const b = await gonder('anahtar-1');
  assert.equal(a.durum, 200); assert.equal(b.durum, 200);
  assert.equal(a.json.id, b.json.id, 'aynı anahtar aynı talebi döndürür');
  assert.equal((await db.prepare('SELECT COUNT(*) n FROM support_tickets WHERE user_id = ?').get(u.id)).n, 1);
  // Başka kullanıcının AYNI anahtarı onun için yeni kayıttır (anahtar kullanıcıya özel).
  const c = await gonder('anahtar-1', baska.token);
  assert.notEqual(c.json.id, a.json.id);
  // Kullanıcı tarafında kapatma/yanıt ucu YOK; admin uçları kullanıcı token'ını tanımaz.
  assert.notEqual((await istek(`/api/v1/support/tickets/${a.json.id}/close`, { yontem: 'POST', token: baska.token })).durum, 200);
  const r = await fetch(`${taban}/admin/v1/support/tickets/${a.json.id}/close`, { method: 'POST', headers: { Authorization: `Bearer ${baska.token}`, 'X-HC-Admin': '1', 'Content-Type': 'application/json' }, body: '{}' });
  assert.equal(r.status, 401);
  const r2 = await fetch(`${taban}/admin/v1/support/tickets/${a.json.id}/reply`, { method: 'POST', headers: { Authorization: `Bearer ${u.token}`, 'X-HC-Admin': '1', 'Content-Type': 'application/json' }, body: JSON.stringify({ body: 'kendi yanıtım' }) });
  assert.equal(r2.status, 401);
  assert.equal((await db.prepare('SELECT status FROM support_tickets WHERE id = ?').get(a.json.id)).status, 'OPEN');
  // Admin listesinde gerçek kayıt olarak görünür; dondurma/silme listesine girmez.
  assert.ok((await istek('/admin/v1/support/tickets?status=OPEN')).json.some((t) => t.id === a.json.id));
  assert.ok(!(await istek('/admin/v1/account-requests')).json.some((x) => x.id === a.json.id));
});

test('OTP: IP başına saatlik sınır (20) aşılınca 429', async () => {
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'otp_ip:%'`).run();
  const durumlar = [];
  for (let i = 0; i < 21; i++) {
    const tel = `53600000${String(i).padStart(2, '0')}`;
    durumlar.push((await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } })).durum);
  }
  assert.deepEqual(durumlar.slice(0, 20).filter((d) => d !== 204), []);
  assert.equal(durumlar[20], 429);
});
