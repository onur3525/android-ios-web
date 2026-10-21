// FCM sunucu gönderimi — sahte gönderici ve sahte HTTP ile (gerçek Firebase YOK).
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID, generateKeyPairSync } from 'node:crypto';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { simdi } = await import('../src/db.js');
const { uygulamaIciBildir } = await import('../src/routes/ilan.js');
const { pushGonderiminiIsle, fcmTestGondericisi, fcmGonder, mesajGovdesi } = await import('../src/fcm.js');

let db;
const giden = [];
let davranis = () => 'ok';
before(async () => { db = await testDb(); });
after(async () => { fcmTestGondericisi(null); await db?.close(); });

async function kullanici(tel) {
  const id = randomUUID();
  await db.prepare(`INSERT INTO users (id, phone, email, name, password_hash, phone_verified, email_verified, roles, active_role, status, terms_accepted, failed_logins, created_at, updated_at)
    VALUES (?, ?, NULL, 'T', 'x', TRUE, FALSE, 'CUSTOMER', 'CUSTOMER', 'ACTIVE', TRUE, 0, ?, ?)`).run(id, tel, simdi(), simdi());
  return id;
}
const jeton = (u, t, pl = 'android') => db.prepare(`INSERT INTO push_tokens (token, user_id, platform, created_at, last_seen) VALUES (?, ?, ?, ?, ?)`).run(t, u, pl, simdi(), simdi());
const durum = async (u) => (await db.prepare('SELECT push_status, push_attempts FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 1').get(u));

test('yalnız bildirim sahibinin bütün cihazlarına, Flutter biçiminde gönderilir', async () => {
  fcmTestGondericisi({ gonder: async (t, m) => { giden.push({ t, m }); return davranis(t); } });
  const a = await kullanici('5551110001'); const b = await kullanici('5551110002');
  await jeton(a, 'a-jeton-1-xxxxxxxxxxxxxxxxxxxx', 'android'); await jeton(a, 'a-jeton-2-xxxxxxxxxxxxxxxxxxxx', 'ios');
  await jeton(b, 'b-jeton-1-xxxxxxxxxxxxxxxxxxxx', 'web');
  const ilanId = randomUUID();
  await uygulamaIciBildir(db, a, 'NEW_OFFER', 'Yeni teklif', 'İlanınıza teklif geldi', ilanId, 'ilan');
  await new Promise((ok) => setTimeout(ok, 50));
  giden.length = 0;
  await db.prepare(`UPDATE notifications SET push_status = NULL, push_claimed_at = NULL WHERE user_id = ?`).run(a); // anında tetikleme sonucunu sıfırla, işi doğrudan sına
  await pushGonderiminiIsle(db);
  assert.deepEqual(giden.map((g) => g.t).sort(), ['a-jeton-1-xxxxxxxxxxxxxxxxxxxx', 'a-jeton-2-xxxxxxxxxxxxxxxxxxxx']);
  const mesajı = (t) => giden.find((g) => g.t === t).m;
  // iOS: sistem bildirimi yükü (değişmedi).
  const m = mesajı('a-jeton-2-xxxxxxxxxxxxxxxxxxxx');
  assert.equal(m.notification.title, 'Yeni teklif');
  assert.equal(m.data.type, 'NEW_OFFER'); assert.equal(m.data.hedef, 'ilan'); assert.equal(m.data.id, ilanId);
  // 21 Eki — Android: YALNIZ VERİ; bildirimi uygulama her markada aynı
  // biçimde (renkli logo) çizer. Bildirim yükü olsaydı FCM kendisi çizerdi.
  const a1 = mesajı('a-jeton-1-xxxxxxxxxxxxxxxxxxxx');
  assert.equal(a1.notification, undefined, 'Android mesajında bildirim yükü yok');
  assert.deepEqual(
    [a1.data.hcYerel, a1.data.baslik, a1.data.govde, a1.data.type, a1.data.hedef, a1.data.id],
    ['1', 'Yeni teklif', 'İlanınıza teklif geldi', 'NEW_OFFER', 'ilan', ilanId],
  );
  assert.equal(a1.android.priority, 'HIGH', 'uygulama kapalıyken de hemen teslim');
  assert.ok(Object.values(a1.data).every((v) => typeof v === 'string'), 'FCM veri alanları metin olmalı');
  assert.equal((await durum(a)).push_status, 'SENT');
  // Tekrar işlemek ikinci gönderim yapmaz (idempotent)
  giden.length = 0; await pushGonderiminiIsle(db); assert.equal(giden.length, 0);
});

test('geçersiz jeton KALICI silinir; geçici hatada jeton korunur ve yeniden denenir', async () => {
  const c = await kullanici('5551110003');
  await jeton(c, 'c-gecersiz-xxxxxxxxxxxxxxxxxxxx'); await jeton(c, 'c-gecici-xxxxxxxxxxxxxxxxxxxxx');
  davranis = (t) => (t.startsWith('c-gecersiz') ? 'gecersiz' : 'gecici');
  await uygulamaIciBildir(db, c, 'NEW_MESSAGE', 'Yeni mesaj', 'x', randomUUID(), 'mesaj');
  await new Promise((ok) => setTimeout(ok, 50));
  await pushGonderiminiIsle(db);
  const kalan = (await db.prepare('SELECT token FROM push_tokens WHERE user_id = ?').all(c)).map((r) => r.token);
  assert.deepEqual(kalan, ['c-gecici-xxxxxxxxxxxxxxxxxxxxx']);
  const d = await durum(c);
  assert.equal(d.push_status, null); assert.ok(d.push_attempts >= 1); // yeniden denenecek
  davranis = () => 'ok';
  // Bekleme aralığı dolmadan HEMEN yeniden denenmez (FCM kesintisinde
  // denemeler saniyeler içinde tükenmesin).
  await pushGonderiminiIsle(db);
  assert.equal((await durum(c)).push_status, null);
  // Aralık dolunca yeniden denenir ve gönderilir.
  await db.prepare(`UPDATE notifications SET push_claimed_at = ? WHERE user_id = ? AND push_status IS NULL`).run('2000-01-01T00:00:00.000Z', c);
  await pushGonderiminiIsle(db);
  assert.equal((await durum(c)).push_status, 'SENT');
});

test('jetonu olmayan kullanıcı NO_TOKEN; gönderici hata fırlatsa da iş ve ana işlem bozulmaz', async () => {
  const d = await kullanici('5551110004');
  await uygulamaIciBildir(db, d, 'ANNOUNCEMENT', 'Duyuru', 'x', randomUUID());
  await new Promise((ok) => setTimeout(ok, 50));
  await pushGonderiminiIsle(db);
  assert.equal((await durum(d)).push_status, 'NO_TOKEN');
  const e = await kullanici('5551110005'); await jeton(e, 'e-jeton-xxxxxxxxxxxxxxxxxxxxxxx');
  fcmTestGondericisi({ gonder: async () => { throw new Error('ağ yok'); } });
  await uygulamaIciBildir(db, e, 'NEW_OFFER', 'Teklif', 'x', randomUUID(), 'talep'); // ana işlem hata vermez
  await new Promise((ok) => setTimeout(ok, 50));
  await pushGonderiminiIsle(db);
  assert.equal((await db.prepare('SELECT COUNT(*) n FROM push_tokens WHERE user_id = ?').get(e)).n, 1, 'geçici hatada jeton silinmez');
  // Hedefsiz bildirim (duyuru) Bildirimler ekranına gider: veri hedef/id taşımaz
  const g = mesajGovdesi({ id: 'n1', type: 'ANNOUNCEMENT', title: 't', body: 'b', ref_id: 'x', push_target: null });
  assert.equal(g.data.hedef, undefined);
});

test('FCM HTTP v1 yanıtlarının sınıflandırılması (sahte HTTP)', async () => {
  const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const sh = { project_id: 'p', client_email: 'x@p.iam.gserviceaccount.com', private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }) };
  const asil = globalThis.fetch;
  let gonderYaniti;
  globalThis.fetch = async (url) => {
    if (String(url).includes('oauth2')) return new Response(JSON.stringify({ access_token: 'erisim', expires_in: 3600 }), { status: 200 });
    return gonderYaniti();
  };
  try {
    gonderYaniti = () => new Response('{}', { status: 200 });
    assert.equal(await fcmGonder(sh, 't', {}), 'ok');
    gonderYaniti = () => new Response(JSON.stringify({ error: { status: 'NOT_FOUND', details: [{ errorCode: 'UNREGISTERED' }] } }), { status: 404 });
    assert.equal(await fcmGonder(sh, 't', {}), 'gecersiz');
    // INVALID_ARGUMENT yalnız JETON alanı hatalıysa kalıcı geçersizdir.
    gonderYaniti = () => new Response(JSON.stringify({ error: { status: 'INVALID_ARGUMENT', details: [
      { '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', errorCode: 'INVALID_ARGUMENT' },
      { '@type': 'type.googleapis.com/google.rpc.BadRequest', fieldViolations: [{ field: 'message.token', description: 'Invalid registration token' }] },
    ] } }), { status: 400 });
    assert.equal(await fcmGonder(sh, 't', {}), 'gecersiz');
    // Mesaj GÖVDESİ hatası jetonu SİLDİRMEZ (önceden bütün cihaz kayıtları silinirdi).
    gonderYaniti = () => new Response(JSON.stringify({ error: { status: 'INVALID_ARGUMENT', details: [
      { errorCode: 'INVALID_ARGUMENT' },
      { fieldViolations: [{ field: 'message.notification.title', description: 'x' }] },
    ] } }), { status: 400 });
    assert.equal(await fcmGonder(sh, 't', {}), 'gecici');
    gonderYaniti = () => new Response(JSON.stringify({ error: { status: 'INVALID_ARGUMENT', details: [{ errorCode: 'INVALID_ARGUMENT' }] } }), { status: 400 });
    assert.equal(await fcmGonder(sh, 't', {}), 'gecici');
    gonderYaniti = () => new Response(JSON.stringify({ error: { status: 'PERMISSION_DENIED', details: [{ errorCode: 'SENDER_ID_MISMATCH' }] } }), { status: 403 });
    assert.equal(await fcmGonder(sh, 't', {}), 'gecersiz');
    // 401: erişim anahtarı sorunu, jetonla ilgisiz → geçici
    gonderYaniti = () => new Response(JSON.stringify({ error: { status: 'UNAUTHENTICATED' } }), { status: 401 });
    assert.equal(await fcmGonder(sh, 't', {}), 'gecici');
    gonderYaniti = () => new Response('{}', { status: 503 });
    assert.equal(await fcmGonder(sh, 't', {}), 'gecici');
    gonderYaniti = () => new Response(JSON.stringify({ error: { status: 'RESOURCE_EXHAUSTED', details: [{ errorCode: 'QUOTA_EXCEEDED' }] } }), { status: 429 });
    assert.equal(await fcmGonder(sh, 't', {}), 'gecici');
    gonderYaniti = () => { throw new Error('ağ'); };
    assert.equal(await fcmGonder(sh, 't', {}), 'gecici');
  } finally { globalThis.fetch = asil; }
});

test('askıya alınmış / banlı / silinmiş hesaba push GİTMEZ; jetonlar silinmez', async () => {
  const giden2 = [];
  fcmTestGondericisi({ gonder: async (t) => { giden2.push(t); return 'ok'; } });
  const askida = await kullanici('5551110011'); const banli = await kullanici('5551110012'); const silinmis = await kullanici('5551110013');
  await db.prepare(`UPDATE users SET status = 'SUSPENDED' WHERE id = ?`).run(askida);
  await db.prepare(`UPDATE users SET status = 'BANNED' WHERE id = ?`).run(banli);
  await db.prepare(`UPDATE users SET deleted_at = ? WHERE id = ?`).run(simdi(), silinmis);
  for (const [u, t] of [[askida, 'askida-jeton-xxxxxxxxxxxxxxxxx'], [banli, 'banli-jeton-xxxxxxxxxxxxxxxxxx'], [silinmis, 'silinmis-jeton-xxxxxxxxxxxxxxx']]) {
    await jeton(u, t);
    await uygulamaIciBildir(db, u, 'NEW_MESSAGE', 'Yeni mesaj', 'x', randomUUID(), 'mesaj');
  }
  await new Promise((ok) => setTimeout(ok, 50));
  await pushGonderiminiIsle(db);
  assert.deepEqual(giden2.filter((t) => /^(askida|banli|silinmis)-/.test(t)), [], 'etkin olmayan hesaba gönderim yok');
  for (const u of [askida, banli, silinmis]) assert.equal((await durum(u)).push_status, 'SKIPPED');
  assert.equal((await db.prepare('SELECT COUNT(*) n FROM push_tokens WHERE user_id IN (?, ?)').get(askida, banli)).n, 2, 'askı kalkınca cihaz kaydı geri gelmesi gerekmez');
  // Etkin hesaba normal gönderim sürer.
  const etkin = await kullanici('5551110014'); await jeton(etkin, 'etkin-jeton-xxxxxxxxxxxxxxxxxx');
  await uygulamaIciBildir(db, etkin, 'NEW_MESSAGE', 'Yeni mesaj', 'x', randomUUID(), 'mesaj');
  await new Promise((ok) => setTimeout(ok, 50));
  await pushGonderiminiIsle(db);
  assert.equal((await durum(etkin)).push_status, 'SENT');
});

test('bildirim tercihi: kapatılan türde push GİTMEZ (uygulama içi kayıt durur); diğer türler gider', async () => {
  const giden3 = [];
  fcmTestGondericisi({ gonder: async (t) => { giden3.push(t); return 'ok'; } });
  const k = await kullanici('5551110021');
  await jeton(k, 'tercih-jeton-xxxxxxxxxxxxxxxxxx');
  // ⚠ Değerler PARAMETRE olarak verilir (uygulamanın tercih ucu gibi):
  // PostgreSQL'de bu sütunlar BOOLEAN'dır ve SQL metnine yazılan 0/1
  // tamsayısını kabul etmez; parametreler sürücüde '0'/'1'e çevrilir.
  await db.prepare('UPDATE users SET notif_offer = ?, notif_message = ?, notif_announcement = ? WHERE id = ?').run(0, 1, 0, k);
  for (const tur of ['NEW_OFFER', 'OFFER_SELECTED', 'ANNOUNCEMENT', 'NEW_MESSAGE', 'CONTACT_OPENED', 'LISTING_EXPIRED',
    'TALEP_REQUEST', 'TALEP_OFFER', 'TALEP_ACCEPTED', 'TALEP_MESSAGE']) {
    await uygulamaIciBildir(db, k, tur, tur, 'x', randomUUID());
  }
  await new Promise((ok) => setTimeout(ok, 50));
  await pushGonderiminiIsle(db);
  const satirlar = await db.prepare('SELECT type, push_status FROM notifications WHERE user_id = ?').all(k);
  const durumu = Object.fromEntries(satirlar.map((r) => [r.type, r.push_status]));
  assert.deepEqual(durumu, {
    NEW_OFFER: 'SKIPPED', OFFER_SELECTED: 'SKIPPED', ANNOUNCEMENT: 'SKIPPED',
    NEW_MESSAGE: 'SENT', CONTACT_OPENED: 'SENT', LISTING_EXPIRED: 'SENT',
    // Bul akışı kodları aynı anahtarlara bağlı: teklif kapalı, mesaj açık.
    TALEP_REQUEST: 'SKIPPED', TALEP_OFFER: 'SKIPPED', TALEP_ACCEPTED: 'SKIPPED', TALEP_MESSAGE: 'SENT',
  });
  assert.equal(giden3.filter((t) => t.startsWith('tercih-')).length, 4);
});

test('çok işçi: aynı kuyruğu eşzamanlı işleyen işçiler bir bildirimi İKİ KEZ göndermez', async () => {
  const sayac = new Map();
  fcmTestGondericisi({ gonder: async (t, m) => {
    await new Promise((ok) => setTimeout(ok, 5));
    sayac.set(m.data.id, (sayac.get(m.data.id) ?? 0) + 1);
    return 'ok';
  } });
  const k = await kullanici('5551110022');
  await jeton(k, 'coklu-jeton-xxxxxxxxxxxxxxxxxxx');
  const kimlikler = [];
  for (let i = 0; i < 40; i++) {
    const ref = randomUUID(); kimlikler.push(ref);
    await uygulamaIciBildir(db, k, 'NEW_MESSAGE', 'Yeni mesaj', 'x', ref, 'mesaj');
  }
  await Promise.all([pushGonderiminiIsle(db), pushGonderiminiIsle(db), pushGonderiminiIsle(db)]);
  // Kayıt anında tetiklenen işler de aynı kuyruğu tüketiyor: hepsi bitene dek bekle.
  const son = Date.now() + 3000;
  while (Date.now() < son && (await db.prepare(`SELECT COUNT(*) n FROM notifications WHERE user_id = ? AND push_status = 'SENT'`).get(k)).n < 40) {
    await new Promise((ok) => setTimeout(ok, 20));
  }
  for (const id of kimlikler) assert.ok((sayac.get(id) ?? 0) <= 1, `bildirim ${id} birden çok gönderildi`);
  const sent = await db.prepare(`SELECT COUNT(*) n FROM notifications WHERE user_id = ? AND push_status = 'SENT'`).get(k);
  assert.equal(sent.n, 40);
});
