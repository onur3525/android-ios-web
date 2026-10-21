// DESTEK E-POSTALARI → GELEN TALEPLER (21 Eki)
//   Resend Receiving webhook'u (Svix imzalı) → destek talebi; aynı talebe
//   e-postayla yanıt → yazışmaya eklenir; admin yanıtı gönderene gider.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createHmac, randomBytes, randomUUID } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { simdi } = await import('../src/db.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const { onbellegiTemizle } = await import('../src/entegrasyon.js');
const { gelenEpostaTestGetirici, svixDogrula, alintiyiKes } = await import('../src/gelen_eposta.js');

let db, sunucu, taban, adminCerez;
const SIR = `whsec_${randomBytes(24).toString('base64')}`;
const postalar = new Map(); // email_id → Resend "alınan e-posta" yanıtı

function imzali(govde, { sir = SIR, ts = Math.floor(Date.now() / 1000) } = {}) {
  const ham = JSON.stringify(govde);
  const id = `msg_${randomUUID()}`;
  const imza = createHmac('sha256', Buffer.from(sir.slice(6), 'base64')).update(`${id}.${ts}.${ham}`).digest('base64');
  return { ham, basliklar: { 'svix-id': id, 'svix-timestamp': String(ts), 'svix-signature': `v1,${imza}`, 'Content-Type': 'application/json' } };
}
async function webhook(govde, secenek) {
  const { ham, basliklar } = imzali(govde, secenek);
  const r = await fetch(`${taban}/webhooks/resend/inbound`, { method: 'POST', headers: basliklar, body: ham });
  return { durum: r.status, json: await r.json() };
}
function eposta({ from = 'Ayşe Yılmaz <ayse@ornek.com>', subject = 'Uygulamaya giremiyorum', text = 'Merhaba, giriş yaparken hata alıyorum.', headers = {} } = {}) {
  const id = randomUUID();
  postalar.set(id, { id, from: from.match(/<(.+)>/)?.[1] ?? from, subject, text, html: null, headers: { from, ...headers } });
  return { type: 'email.received', created_at: simdi(), data: { email_id: id, from: postalar.get(id).from, to: ['destek@hizmetcep.com'], subject } };
}
async function admin(yol, { yontem = 'GET', govde } = {}) {
  const r = await fetch(taban + yol, { method: yontem, headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1', Cookie: adminCerez }, body: govde ? JSON.stringify(govde) : undefined });
  return { durum: r.status, json: await r.json() };
}
const talep = (emailId) => db.prepare('SELECT * FROM support_tickets WHERE inbound_email_id = ?').get(emailId);

before(async () => {
  db = await testDb();
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  gelenEpostaTestGetirici(async (id) => (postalar.has(id) ? { status: 200, json: postalar.get(id) } : { status: 404, json: null }));
  await db.prepare('INSERT INTO support_info (id, description, email, updated_at) VALUES (1, ?, ?, ?)').run('Destek', 'destek@hizmetcep.com', simdi());
  const sir = base32Uret();
  await db.prepare(`INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, 'y@hc.test', 'Yönetici', 'super_admin', ?, ?, ?)`)
    .run(randomUUID(), sifreOzetle('GucluSifre12345'), sirSifrele(sir), simdi());
  const a = await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email: 'y@hc.test', password: 'GucluSifre12345' }) });
  adminCerez = a.headers.get('set-cookie').split(';')[0];
  await fetch(`${taban}/admin/v1/auth/mfa`, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: adminCerez, 'X-HC-Admin': '1' }, body: JSON.stringify({ code: totpUret(sir) }) });
});
after(async () => { gelenEpostaTestGetirici(null); sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

test('yapılandırma yoksa 503 (Resend sonra yeniden dener); kayıt açılmaz', async () => {
  const r = await webhook(eposta());
  assert.equal(r.durum, 503);
  assert.equal(Number((await db.prepare('SELECT COUNT(*) n FROM support_tickets').get()).n), 0);
});

test('entegrasyon: imza anahtarı yalnız Resend için, "whsec_" biçiminde; API anahtarı değişince silinmez', async () => {
  const id = randomUUID();
  await db.prepare(`INSERT INTO integrations (id, type, provider, active, config_json, secret_enc, secret_hint, created_at, updated_at) VALUES (?, 'EMAIL', 'resend', TRUE, ?, ?, '••••test', ?, ?)`)
    .run(id, JSON.stringify({ from: 'HizmetCep <bildirim@hizmetcep.com>' }), sirSifrele(JSON.stringify({ token: 're_test_anahtari' })), simdi(), simdi());
  onbellegiTemizle();
  assert.equal((await admin(`/admin/v1/integrations/${id}/inbound-secret`, { yontem: 'PUT', govde: { webhookSecret: 'yanlis' } })).durum, 400);
  const r = await admin(`/admin/v1/integrations/${id}/inbound-secret`, { yontem: 'PUT', govde: { webhookSecret: SIR } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.equal(r.json.inboundSecretSet, true);
  assert.ok(!JSON.stringify(r.json).includes(SIR), 'düz değer geri dönmez');
  const k = await admin(`/admin/v1/integrations/${id}/secret`, { yontem: 'PUT', govde: { token: 're_yeni_anahtar_123' } });
  assert.equal(k.json.inboundSecretSet, true, 'API anahtarı değişince gelen e-posta anahtarı korunur');
});

test('imza: yanlış anahtar, bozulmuş gövde ve eski zaman damgası reddedilir', async () => {
  assert.equal((await webhook(eposta(), { sir: `whsec_${randomBytes(24).toString('base64')}` })).durum, 401);
  assert.equal((await webhook(eposta(), { ts: Math.floor(Date.now() / 1000) - 3600 })).durum, 401);
  const { basliklar } = imzali(eposta());
  const r = await fetch(`${taban}/webhooks/resend/inbound`, { method: 'POST', headers: basliklar, body: JSON.stringify(eposta()) });
  assert.equal(r.status, 401);
  assert.equal(svixDogrula(SIR, {}, '{}'), false);
});

test('destek e-postası talep açar; webhook tekrarı ikinci kayıt açmaz; kayıtlı kullanıcı eşleşir', async () => {
  const o = eposta();
  assert.equal((await webhook(o)).json.result, 'ticket');
  assert.equal((await webhook(o)).json.result, 'yok-sayildi', 'aynı e-posta ikinci kez kayda girmez');
  const t = await talep(o.data.email_id);
  assert.equal(t.source, 'EMAIL'); assert.equal(t.user_id, null); assert.equal(t.status, 'OPEN');
  assert.equal(t.sender_email, 'ayse@ornek.com'); assert.equal(t.sender_name, 'Ayşe Yılmaz');
  assert.equal(t.subject, 'Uygulamaya giremiyorum'); assert.match(t.message, /hata alıyorum/);

  const uid = randomUUID();
  await db.prepare(`INSERT INTO users (id, phone, email, name, password_hash, phone_verified, email_verified, roles, active_role, status, terms_accepted, failed_logins, created_at, updated_at)
    VALUES (?, '5459990001', 'kayitli@ornek.com', 'Kayıtlı', 'x', TRUE, TRUE, 'CUSTOMER', 'CUSTOMER', 'ACTIVE', TRUE, 0, ?, ?)`).run(uid, simdi(), simdi());
  const k = eposta({ from: 'Kayitli@Ornek.com', subject: 'İlan sorunu' });
  await webhook(k);
  assert.equal((await talep(k.data.email_id)).user_id, uid, 'gönderen kayıtlı kullanıcıysa bağlanır');
});

test('otomatik yanıtlar ve kendi gönderen adresimiz kayda girmez', async () => {
  for (const o of [
    eposta({ from: 'MAILER-DAEMON@ornek.com' }),
    eposta({ headers: { 'auto-submitted': 'auto-replied' } }),
    eposta({ from: 'HizmetCep <bildirim@hizmetcep.com>' }),
  ]) {
    assert.equal((await webhook(o)).json.result, 'yok-sayildi');
    assert.equal(await talep(o.data.email_id), undefined);
  }
});

test('admin yanıtı gönderen adrese, konuda talep numarasıyla gider; kişinin yanıtı AYNI talebe eklenir', async () => {
  const o = eposta({ from: 'Mehmet <mehmet@ornek.com>', subject: 'Fatura sorusu', text: 'Ücret var mı?' });
  await webhook(o);
  const t = await talep(o.data.email_id);
  const liste = await admin('/admin/v1/support/tickets');
  const satir = liste.json.find((x) => x.id === t.id);
  assert.equal(satir.source, 'EMAIL'); assert.equal(satir.senderEmail, 'mehmet@ornek.com'); assert.equal(satir.userId, null);

  // Gönderim gerçek Resend'e gitmesin: yanıt anında entegrasyon pasif (test
  // ortamının sahte e-posta sağlayıcısı kullanılır), sonra yeniden etkin.
  const etkin = async (v) => { await db.prepare(`UPDATE integrations SET active = ${v ? 'TRUE' : 'FALSE'} WHERE provider = 'resend'`).run(); onbellegiTemizle(); };
  await etkin(false);
  const y = await admin(`/admin/v1/support/tickets/${t.id}/reply`, { yontem: 'POST', govde: { body: 'HizmetCep ücretsizdir.' } });
  await etkin(true);
  assert.equal(y.durum, 200, JSON.stringify(y.json));
  const giden = await db.prepare('SELECT target, subject FROM outbound_messages WHERE id = ?').get(y.json.email.id);
  assert.equal(giden.target, 'mehmet@ornek.com', 'yanıt e-postayı gönderene gider');
  assert.equal(giden.subject, `Destek talebiniz yanıtlandı (Talep No: ${t.ticket_no})`);

  // Kişi yanıtladı: alıntılanan eski metin kesilir, talep yeniden yanıt bekler.
  const cevap = eposta({ from: 'mehmet@ornek.com', subject: `Re: Destek talebiniz yanıtlandı (Talep No: ${t.ticket_no})`,
    text: 'Teşekkürler, anladım.\n\nOn Tue, HizmetCep wrote:\n> HizmetCep ücretsizdir.' });
  assert.equal((await webhook(cevap)).json.result, 'reply');
  assert.equal(await talep(cevap.data.email_id), undefined, 'yeni talep açılmaz');
  const d = await admin(`/admin/v1/support/tickets/${t.id}`);
  assert.equal(d.json.status, 'OPEN');
  assert.deepEqual(d.json.replies.map((r) => [r.author, r.body]), [['ADMIN', 'HizmetCep ücretsizdir.'], ['USER', 'Teşekkürler, anladım.']]);

  // Başka biri aynı numarayla yazarsa o talebe EKLENMEZ, yeni talep açılır.
  const yabanci = eposta({ from: 'baska@ornek.com', subject: `Re: (Talep No: ${t.ticket_no})` });
  assert.equal((await webhook(yabanci)).json.result, 'ticket');
});

test('alıntı kesme: yalnız yeni yazılan kalır', () => {
  assert.equal(alintiyiKes('Tamam.\n\n21 Eki 2026 Çar tarihinde HizmetCep <a@b.c> şunu yazdı:\n> eski'), 'Tamam.');
  assert.equal(alintiyiKes('Yeni\n> eski\n> eski'), 'Yeni');
});

test('Gelen Talepler araması: talep no, e-posta, ad, konu/mesaj; durumla birlikte; sayfalı; joker karakter düz aranır', async () => {
  const z = eposta({ from: 'Zeynep Kaya <zeynep.kaya@firma.com>', subject: 'Teklif onayı', text: 'Kombi servisi için teklif gelmedi.' });
  await webhook(z);
  const t = await talep(z.data.email_id);
  const ara = async (q, ek = '') => (await admin(`/admin/v1/support/tickets?q=${encodeURIComponent(q)}${ek}`)).json.map((x) => x.id);
  assert.deepEqual(await ara(t.ticket_no), [t.id], 'talep numarası');
  assert.ok((await ara('zeynep.kaya@')).includes(t.id), 'e-postanın bir kısmı');
  assert.ok((await ara('firma.com')).includes(t.id), 'alan adı');
  assert.ok((await ara('Zeynep')).includes(t.id), 'ad (büyük/küçük harf duyarsız)');
  assert.ok((await ara('kombi')).includes(t.id), 'mesajdaki kelime');
  assert.ok((await ara('teklif onayı')).includes(t.id), 'konu');
  assert.deepEqual(await ara('yokboylebirsey'), []);
  assert.deepEqual(await ara('%'), [], '% bütün kayıtları getirmez');
  assert.deepEqual(await ara('zeynep', '&status=CLOSED'), [], 'durum filtresiyle birlikte');
  assert.ok((await ara('zeynep', '&status=OPEN')).includes(t.id));
  // Sayfalama: ikinci sayfa ilkini tekrarlamaz.
  const hepsi = (await admin('/admin/v1/support/tickets')).json.map((x) => x.id);
  const s1 = (await admin('/admin/v1/support/tickets?limit=2&offset=0')).json.map((x) => x.id);
  const s2 = (await admin('/admin/v1/support/tickets?limit=2&offset=2')).json.map((x) => x.id);
  assert.deepEqual([...s1, ...s2], hepsi.slice(0, 4));
});
