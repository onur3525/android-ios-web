// HESAP SİLME — KUYRUK İZLEME VE YÖNETİCİ KAYITLARININ ANONİMLEŞTİRİLMESİ
// (15 Eki güvenlik denetimi)
//   · Hesap silinince denetim kaydı ve durum geçmişindeki ad/telefon/e-posta
//     ve kişinin yazdığı metin maskelenir; işlem, zaman, yönetici, IP, hedef
//     korunur. Kayıtlar yine silinemez; maskeleme dışı güncelleme reddedilir.
//   · Firebase ve dosya silme kuyruklarının bekleyen/başarısız/tükenen işleri
//     yalnız yetkili role, kimlikler özetlenmiş olarak görünür; yeniden deneme
//     gerekçe ister ve denetime yazılır.
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
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const { silmeTalepleriniIsle } = await import('../src/routes/sohbet_talep.js');
const { maskeleyici, MASKE } = await import('../src/denetim_anonimlestirme.js');
const { dosyaTemizliginiIsle } = await import('../src/dosya_temizligi.js');

let db, sunucu, taban;
const adminCerez = {};
const adminKimlik = {};

async function istek(yol, { yontem = 'GET', govde, token, rol } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: {
      ...(govde ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(yol.startsWith('/admin/') ? { 'X-HC-Admin': '1', Cookie: adminCerez[rol ?? 'super_admin'] ?? '' } : {}),
    },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null, ham: m };
}
async function adminGiris(rol) {
  const sir = base32Uret();
  const id = randomUUID();
  await db.prepare(`INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)`)
    .run(id, `${rol}@silme.test`, rol, rol, sifreOzetle('GucluSifre12345'), sirSifrele(sir), simdi());
  const a = await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email: `${rol}@silme.test`, password: 'GucluSifre12345' }) });
  const c = a.headers.get('set-cookie').split(';')[0];
  const m = await fetch(`${taban}/admin/v1/auth/mfa`, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: c, 'X-HC-Admin': '1' }, body: JSON.stringify({ code: totpUret(sir) }) });
  assert.equal(m.status, 200);
  adminCerez[rol] = c;
  adminKimlik[rol] = id;
}
async function kisi(tel, ad) {
  await db.prepare('UPDATE otp_codes SET created_at = ? WHERE phone = ?').run('2000-01-01T00:00:00.000Z', tel);
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, ageConfirmed: true, phone: tel, password: 'sifre1234', name: ad, email: `z${tel}@ornek.com`, role: 'CUSTOMER', otpCode: globalThis.__sonOtp } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const me = await istek('/api/v1/users/me', { token: r.json.accessToken });
  return { token: r.json.accessToken, id: me.json.id, tel, email: `z${tel}@ornek.com` };
}
async function hesabiSil(k) {
  const r = await istek('/api/v1/profiles/me/deletion-request', { yontem: 'POST', token: k.token, govde: { password: 'sifre1234' } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  await db.prepare('UPDATE account_requests SET scheduled_for = ? WHERE id = ?').run('2000-01-01T00:00:00.000Z', r.json.id);
  assert.ok(await silmeTalepleriniIsle(db) >= 1);
}

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  for (const rol of ['super_admin', 'moderator', 'content', 'operations', 'readonly']) await adminGiris(rol);
});
after(async () => { sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

test('maskeleyici: bilinen ad/telefon/e-posta her biçimde ve genel kalıplar maskelenir; kişisel olmayan metin kalır', () => {
  const m = maskeleyici({ ad: 'Zeynep Yıldırım', telefon: '5391110001', eposta: 'zeynep@ornek.com' });
  const sonuc = m('Şikâyet: ZEYNEP YILDIRIM (0539 111 00 01, +90 539-111-0001, zeynep@ornek.com) sahte ilan; ikinci numara 05321234567, baska@x.com.tr');
  for (const parca of ['ZEYNEP', 'YILDIRIM', '539', '111', 'zeynep@', '0532', 'baska@']) assert.equal(sonuc.includes(parca), false, `${parca} kaldı: ${sonuc}`);
  assert.ok(sonuc.includes('Şikâyet') && sonuc.includes('sahte ilan'), 'gerekçenin kişisel olmayan kısmı korunur');
  assert.equal(m('Zeynepler derneği'), 'Zeynepler derneği', 'kelime içi eşleşme yapılmaz');
  assert.equal(m(null), null);
});

test('hesap silinince denetim kaydı ve durum geçmişi maskelenir; işlem/zaman/yönetici/IP/hedef korunur; başka kullanıcının kaydına dokunulmaz', async () => {
  const k = await kisi('5391110001', 'Zeynep Yıldırım');
  const baska = await kisi('5391110002', 'Mehmet Kaya');
  const neden = 'Zeynep Yıldırım 0539 111 00 01 numarasından şikâyet edildi';
  assert.equal((await istek(`/admin/v1/users/${k.id}/suspend`, { yontem: 'POST', rol: 'moderator', govde: { reason: neden, notify: false } })).durum, 200);
  assert.equal((await istek(`/admin/v1/users/${k.id}/unsuspend`, { yontem: 'POST', rol: 'moderator', govde: { reason: 'İnceleme tamamlandı, Zeynep bilgilendirildi', notify: false } })).durum, 200);
  // Kişinin metnini taşıyan bir kayıt (ör. kaldırılan yorumun metni) ve başka kullanıcıya ait kayıt.
  await db.prepare(`INSERT INTO audit_log (admin_id, action, target_type, target_id, before_json, after_json, reason, ip, created_at) VALUES (?, 'user.note', 'user', ?, ?, ?, ?, '203.0.113.7', ?)`)
    .run(adminKimlik.moderator, k.id, JSON.stringify({ name: 'Zeynep Yıldırım', phone: '5391110001', status: 'ACTIVE', ic: { text: 'kişisel metin' } }), JSON.stringify({ status: 'ACTIVE', sayi: 3 }), `İletişim: ${k.email}`, simdi());
  await db.prepare(`INSERT INTO audit_log (admin_id, action, target_type, target_id, before_json, reason, ip, created_at) VALUES (?, 'user.note', 'user', ?, ?, 'Mehmet Kaya hakkında', '203.0.113.8', ?)`)
    .run(adminKimlik.moderator, baska.id, JSON.stringify({ name: 'Mehmet Kaya' }), simdi());
  const once = await db.prepare(`SELECT * FROM audit_log WHERE target_type = 'user' AND target_id = ? ORDER BY id`).all(k.id);
  assert.ok(once.length >= 3, `beklenen kayıtlar: ${once.length}`);

  // Askıya alma oturumları kapattı: kullanıcı yeniden girip silme talep eder.
  const g = await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: k.tel, password: 'sifre1234' } });
  assert.equal(g.durum, 200, JSON.stringify(g.json));
  await hesabiSil({ ...k, token: g.json.accessToken });

  const sonra = await db.prepare(`SELECT * FROM audit_log WHERE target_type = 'user' AND target_id = ? ORDER BY id`).all(k.id);
  assert.equal(sonra.length, once.length, 'kayıt silinmedi');
  for (let i = 0; i < once.length; i++) {
    const [a, b] = [once[i], sonra[i]];
    for (const alan of ['id', 'admin_id', 'action', 'target_type', 'target_id', 'ip', 'created_at']) assert.deepEqual(b[alan], a[alan], `${alan} korunmalı`);
    assert.ok(b.anonymized_at, 'anonimleştirme zamanı');
    const hepsi = `${b.reason ?? ''} ${b.before_json ?? ''} ${b.after_json ?? ''}`;
    for (const iz of ['Zeynep', 'Yıldırım', '5391110001', '0539 111', k.email, 'kişisel metin']) assert.equal(hepsi.includes(iz), false, `${iz} kaldı: ${hepsi}`);
  }
  const askiya = sonra.find((s) => s.action === 'user.suspend');
  assert.ok(askiya.reason.includes('şikâyet edildi') && askiya.reason.includes(MASKE), askiya.reason);
  assert.deepEqual(JSON.parse(askiya.before_json), { status: 'ACTIVE' }, 'durum bilgisi korunur');
  const not = sonra.find((s) => s.action === 'user.note');
  assert.deepEqual(JSON.parse(not.before_json), { name: MASKE, phone: MASKE, status: 'ACTIVE', ic: { text: MASKE } });
  assert.deepEqual(JSON.parse(not.after_json), { status: 'ACTIVE', sayi: 3 });

  const gecmis = await db.prepare('SELECT * FROM user_status_history WHERE user_id = ? ORDER BY created_at').all(k.id);
  assert.deepEqual(gecmis.map((g) => [g.old_status, g.new_status]), [['ACTIVE', 'SUSPENDED'], ['SUSPENDED', 'ACTIVE']]);
  assert.ok(gecmis.every((g) => g.anonymized_at && !g.reason.includes('Zeynep') && !g.reason.includes('0539')));
  assert.equal((await db.prepare('SELECT status_reason FROM users WHERE id = ?').get(k.id)).status_reason?.includes('Zeynep') ?? false, false);

  const dokunulmayan = await db.prepare(`SELECT * FROM audit_log WHERE target_id = ?`).get(baska.id);
  assert.equal(dokunulmayan.reason, 'Mehmet Kaya hakkında');
  assert.equal(dokunulmayan.anonymized_at, null);

  // Bütünlük: silme, ikinci maskeleme ve korunan alan değişikliği reddedilir.
  await assert.rejects(db.prepare('DELETE FROM audit_log WHERE id = ?').run(not.id), /silinemez/);
  await assert.rejects(db.prepare('UPDATE audit_log SET reason = ? WHERE id = ?').run('x', not.id), /değiştirilemez/);
  await assert.rejects(db.prepare('UPDATE audit_log SET reason = ?, anonymized_at = ? WHERE id = ?').run('x', simdi(), not.id), /değiştirilemez/, 'ikinci kez maskelenemez');
  const temiz = await db.prepare(`SELECT id FROM audit_log WHERE target_id = ?`).get(baska.id);
  await assert.rejects(db.prepare('UPDATE audit_log SET action = ?, anonymized_at = ? WHERE id = ?').run('baska', simdi(), temiz.id), /değiştirilemez/, 'işlem türü değiştirilemez');
  await assert.rejects(db.prepare('UPDATE audit_log SET ip = ?, anonymized_at = ? WHERE id = ?').run('1.1.1.1', simdi(), temiz.id), /değiştirilemez/, 'yönetici IP değiştirilemez');
  await assert.rejects(db.prepare('UPDATE user_status_history SET new_status = ?, anonymized_at = ? WHERE id = ?').run('BANNED', simdi(), gecmis[0].id), /değiştirilemez/);
  await assert.rejects(db.prepare('DELETE FROM user_status_history WHERE id = ?').run(gecmis[0].id), /silinemez/);
});

test('silme kuyrukları: yalnız yetkili rol görür; kimlikler özetli; bekleyen/başarısız/tükenen ayrılır; gecikmiş silme görünür', async () => {
  const k = await kisi('5391110003', 'Kuyruk Sahibi');
  const z = simdi();
  for (const [uid, deneme] of [['fb-gizli-uid-0', 0], ['fb-gizli-uid-3', 3], ['fb-gizli-uid-12', 12]]) {
    await db.prepare('INSERT INTO firebase_silme_kuyrugu (uid, deneme, son_hata, sonraki_deneme, created_at) VALUES (?, ?, ?, ?, ?)')
      .run(uid, deneme, deneme ? 'Firebase kullanıcısı silinemedi (HTTP 503)' : null, '2999-01-01T00:00:00.000Z', z);
  }
  const refler = [];
  for (const deneme of [0, 2, 10]) {
    const ref = `u/${k.id}/${randomUUID()}.jpg`;
    refler.push(ref);
    await db.prepare(`INSERT INTO storage_objects (ref, owner_id, kind, content_type, size_bytes, status, created_at, delete_requested_at, delete_attempts, delete_error)
      VALUES (?, ?, 'profile-photo', 'image/jpeg', 10, 'DISCARDED', ?, ?, ?, ?)`).run(ref, k.id, z, z, deneme, deneme ? 'depo silme isteği başarısız' : null);
  }
  const gecikmis = randomUUID();
  await db.prepare(`INSERT INTO account_requests (id, user_id, type, status, created_at, scheduled_for) VALUES (?, ?, 'DELETION', 'PENDING', ?, ?)`)
    .run(gecikmis, k.id, z, '2000-01-01T00:00:00.000Z');

  for (const rol of ['moderator', 'content', 'readonly']) assert.equal((await istek('/admin/v1/deletion-queues', { rol })).durum, 403, rol);
  const r = await istek('/admin/v1/deletion-queues', { rol: 'operations' });
  assert.equal(r.durum, 200);
  for (const gizli of ['fb-gizli-uid', k.id, 'u/']) assert.equal(r.ham.includes(gizli), false, `${gizli} yanıtta görünmemeli`);
  assert.deepEqual(r.json.firebase.counts, { BEKLIYOR: 1, BASARISIZ: 1, UZUN_SURELI_HATA: 1 });
  assert.deepEqual(r.json.files.counts, { BEKLIYOR: 1, BASARISIZ: 1, DENEME_TUKENDI: 1 });
  assert.equal(r.json.files.configured, false, 'depo yapılandırılmamış olarak raporlanır');
  assert.equal(r.json.accountDeletions.overdue, 1, 'süresi geçmiş ama uygulanmamış silme görünür');
  assert.ok(r.json.firebase.items.find((x) => x.deneme === 3).sonHata.includes('HTTP 503'));

  // Yeniden deneme: gerekçe zorunlu, yetkisiz rol yapamaz, denetime yazılır.
  const tukenen = r.json.files.items.find((x) => x.durum === 'DENEME_TUKENDI');
  assert.equal((await istek('/admin/v1/deletion-queues/retry', { yontem: 'POST', rol: 'operations', govde: { queue: 'files', id: tukenen.id } })).durum, 400);
  assert.equal((await istek('/admin/v1/deletion-queues/retry', { yontem: 'POST', rol: 'moderator', govde: { queue: 'files', id: tukenen.id, reason: 'R2 kesintisi bitti' } })).durum, 403);
  const y = await istek('/admin/v1/deletion-queues/retry', { yontem: 'POST', rol: 'operations', govde: { queue: 'files', id: tukenen.id, reason: 'R2 kesintisi bitti' } });
  assert.equal(y.durum, 200, JSON.stringify(y.json));
  assert.equal(y.json.retried, 1);
  const kayit = await db.prepare('SELECT delete_attempts, delete_next_at, delete_error FROM storage_objects WHERE ref = ?').get(refler[2]);
  assert.equal(kayit.delete_attempts, 0);
  assert.equal(kayit.delete_next_at, null);
  assert.ok(kayit.delete_error, 'hata nedeni başarıya kadar korunur');
  assert.ok(await db.prepare(`SELECT 1 FROM audit_log WHERE action = 'deletion.queue.retry' AND reason = 'R2 kesintisi bitti'`).get());
  // Yeniden denenen dosya işlenir; başarılı silmede hata temizlenir.
  await dosyaTemizliginiIsle(db, { silici: async () => true });
  const silinen = await db.prepare('SELECT deleted_at, delete_error FROM storage_objects WHERE ref = ?').get(refler[2]);
  assert.ok(silinen.deleted_at);
  assert.equal(silinen.delete_error, null);

  const fbY = await istek('/admin/v1/deletion-queues/retry', { yontem: 'POST', rol: 'super_admin', govde: { queue: 'firebase', reason: 'Servis hesabı yenilendi' } });
  assert.equal(fbY.json.retried, 2, 'yalnız başarısız olanlar');
  assert.equal((await db.prepare('SELECT COUNT(*) AS n FROM firebase_silme_kuyrugu WHERE sonraki_deneme <= ?').get(simdi())).n, 2);
  assert.equal((await istek('/admin/v1/deletion-queues/retry', { yontem: 'POST', rol: 'operations', govde: { queue: 'yok', reason: 'deneme gerekçesi' } })).durum, 400);
  await db.prepare('DELETE FROM account_requests WHERE id = ?').run(gecikmis);

  // Firebase işlem kuyruğu (yarım kalan oturum iptali / telefon eşitleme) aynı ekranda.
  await db.prepare(`INSERT INTO firebase_islem_kuyrugu (user_id, islem, deger, deneme, son_hata, sonraki_deneme, created_at) VALUES (?, 'REVOKE', 1, 2, 'Firebase oturumları iptal edilemedi (HTTP 503)', '2999-01-01T00:00:00.000Z', ?)`).run(k.id, simdi());
  const o = await istek('/admin/v1/deletion-queues', { rol: 'super_admin' });
  assert.deepEqual(o.json.firebaseOps.counts, { BASARISIZ: 1 });
  assert.equal(o.json.firebaseOps.items[0].islem, 'REVOKE');
  assert.equal(o.ham.includes(k.id), false, 'kullanıcı kimliği görünmez');
  const yo = await istek('/admin/v1/deletion-queues/retry', { yontem: 'POST', rol: 'operations', govde: { queue: 'firebase_ops', id: o.json.firebaseOps.items[0].id, reason: 'Google kesintisi bitti' } });
  assert.equal(yo.json.retried, 1);
  assert.ok(new Date((await db.prepare('SELECT sonraki_deneme FROM firebase_islem_kuyrugu WHERE user_id = ?').get(k.id)).sonraki_deneme) <= new Date());
});
