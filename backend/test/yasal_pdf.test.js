// YASAL BELGE PDF'İ (22 Eki, kullanıcı kararı)
//   Admin PDF + kısa özet yükler; "Güncelle ve yayınla" tek adımda yayınlar.
//   Kullanıcı açılışta özeti ve PDF adresini alır; "Tamam" ile kabul eder.
//   Kabulün ispatı PDF baytlarının SHA-256'sıdır. Taslak PDF herkese açık değil.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createHash, randomUUID } from 'node:crypto';

const depo = new Map();
const s3 = createServer((req, res) => {
  const anahtar = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (req.method === 'PUT') {
    const parca = [];
    req.on('data', (c) => parca.push(c));
    req.on('end', () => { depo.set(anahtar, { tur: req.headers['content-type'], veri: Buffer.concat(parca) }); res.end(); });
  } else if (req.method === 'GET') {
    const o = depo.get(anahtar);
    if (!o) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'Content-Type': o.tur }); res.end(o.veri);
  } else { res.writeHead(204); res.end(); }
});
await new Promise((ok) => s3.listen(0, ok));
process.env.HC_S3_ENDPOINT = `http://127.0.0.1:${s3.address().port}`;
process.env.HC_S3_BUCKET = 'hc';
process.env.HC_S3_PATH_STYLE = 'true';
process.env.HC_S3_ACCESS_KEY_ID = 'TESTANAHTAR123';
process.env.HC_S3_SECRET_ACCESS_KEY = 'testgizlianahtar-yalnizca-test';
process.env.HC_SESSIZ = '1';
process.env.HC_TEST_OTP_KANCASI = '1';

const { testDb } = await import('./destek.js');
const { simdi } = await import('../src/db.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const { degisiklikOnayi, onayKimligi } = await import('./admin_onay.js');

let db, sunucu, taban, cerez;
const PDF = Buffer.concat([Buffer.from('%PDF-1.7\n'), Buffer.alloc(3000, 65), Buffer.from('\n%%EOF')]);
const OZET = 'Bu metin kişisel verilerinizin hangi amaçlarla işlendiğini ve haklarınızı özetler.';

async function istek(yol, { yontem = 'GET', govde, token } = {}) {
  if (yol.startsWith('/admin/')) await degisiklikOnayi(taban, yol, yontem, cerez);
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { 'Content-Type': 'application/json', ...(yol.startsWith('/admin/') ? { 'X-HC-Admin': '1', Cookie: cerez ?? '' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const ham = Buffer.from(await r.arrayBuffer());
  let json = null; try { json = ham.length ? JSON.parse(ham.toString('utf8')) : null; } catch { json = null; }
  return { durum: r.status, json, ham, tur: r.headers.get('content-type') };
}

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  const sir = base32Uret();
  await db.prepare("INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, 'y@hc.test', 'Y', 'content', ?, ?, ?)")
    .run(randomUUID(), sifreOzetle('GucluSifre12345'), sirSifrele(sir), simdi());
  const g = await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email: 'y@hc.test', password: 'GucluSifre12345' }) });
  cerez = g.headers.get('set-cookie').split(';')[0];
  await fetch(`${taban}/admin/v1/auth/mfa`, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: cerez, 'X-HC-Admin': '1' }, body: JSON.stringify({ code: totpUret(sir) }) });
  onayKimligi(cerez, 'GucluSifre12345', sir);
});
after(async () => { sunucu.closeAllConnections?.(); sunucu.close(); s3.close(); await db?.close(); });

test('doğrulama: PDF olmayan dosya, kısa özet ve 10 MB üstü reddedilir', async () => {
  const y = (pdf, summary) => istek('/admin/v1/legal/kvkk/versions', { yontem: 'POST', govde: { pdf: pdf.toString('base64'), summary } });
  assert.equal((await y(Buffer.from('<html>değil</html>'), OZET)).durum, 400);
  assert.equal((await y(PDF, 'kısa')).durum, 400);
  assert.equal((await y(Buffer.concat([PDF, Buffer.alloc(10 * 1024 * 1024)]), OZET)).durum, 400);
});

test('taslak PDF herkese açık değil; admin önizleyebilir', async () => {
  const r = await istek('/admin/v1/legal/kvkk/versions', { yontem: 'POST', govde: { pdf: PDF.toString('base64'), summary: OZET } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.equal(r.json.status, 'DRAFT');
  assert.equal(r.json.hasPdf, true);
  assert.equal(r.json.sha256, createHash('sha256').update(PDF).digest('hex'), 'ispat PDF baytlarının özeti');
  assert.equal((await istek(`/api/v1/legal/kvkk/pdf/${r.json.version}`)).durum, 404, 'taslak açık değil');
  const a = await istek(r.json.pdfUrl);
  assert.equal(a.durum, 200);
  assert.equal(a.tur, 'application/pdf');
  assert.ok(a.ham.equals(PDF));
  const anonim = await fetch(taban + r.json.pdfUrl);
  assert.equal(anonim.status, 401, 'admin önizlemesi oturumsuz açılmaz');
});

test('güncelle ve yayınla: tek adımda yayın; kullanıcı özeti ve PDF\'i görür; Tamam ile kabul', async () => {
  const r = await istek('/admin/v1/legal/kvkk/versions', { yontem: 'POST', govde: { pdf: PDF.toString('base64'), summary: OZET, publish: true } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.equal(r.json.status, 'PUBLISHED');
  const pub = (await istek('/api/v1/legal/kvkk')).json;
  assert.equal(pub.summary, OZET);
  assert.equal(pub.pdfUrl, `/api/v1/legal/kvkk/pdf/${r.json.version}`);
  const p = await istek(pub.pdfUrl);
  assert.equal(p.durum, 200); assert.equal(p.tur, 'application/pdf'); assert.ok(p.ham.equals(PDF));
  // Kullanıcı
  await db.prepare(`DELETE FROM rate_limits`).run();
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: '5330000991', purpose: 'REGISTER' } });
  const k = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, ageConfirmed: true, phone: '5330000991', password: 'sifre1234', name: 'Yasal Kişi', email: 'yasal@ornek.com', role: 'CUSTOMER', otpCode: globalThis.__sonOtp } });
  assert.equal(k.durum, 200, JSON.stringify(k.json));
  const bekleyen = (await istek('/api/v1/legal/pending-acceptances', { token: k.json.accessToken })).json;
  const b = bekleyen.find((x) => x.slug === 'kvkk');
  assert.ok(b, 'yeni sürüm kabul bekliyor');
  assert.equal(b.summary, OZET);
  assert.equal(b.pdfUrl, pub.pdfUrl);
  const kabul = await istek('/api/v1/legal/kvkk/accept', { yontem: 'POST', token: k.json.accessToken, govde: { version: b.version, sha256: b.sha256, platform: 'android' } });
  assert.equal(kabul.durum, 200);
  assert.ok(!(await istek('/api/v1/legal/pending-acceptances', { token: k.json.accessToken })).json.some((x) => x.slug === 'kvkk'));
  const kayit = await db.prepare("SELECT sha256 FROM legal_acceptances WHERE slug = 'kvkk'").get();
  assert.equal(kayit.sha256, createHash('sha256').update(PDF).digest('hex'));
});

test('eski (arşiv) sürümün PDF\'i açık kalır: kullanıcı kabul ettiğini görebilir', async () => {
  const yeni = Buffer.concat([PDF, Buffer.from('ikinci')]);
  const r = await istek('/admin/v1/legal/kvkk/versions', { yontem: 'POST', govde: { pdf: yeni.toString('base64'), summary: `${OZET} (güncel)`, publish: true } });
  assert.equal(r.durum, 200);
  const surumler = (await istek('/admin/v1/legal/kvkk/versions')).json;
  const arsiv = surumler.find((v) => v.status === 'ARCHIVED' && v.hasPdf);
  assert.ok(arsiv);
  assert.equal((await istek(`/api/v1/legal/kvkk/pdf/${arsiv.version}`)).durum, 200);
});
