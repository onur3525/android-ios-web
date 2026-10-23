// YASAL METİN TASLAKLARI (034, 23 Eki — KVKK takip denetimi B1/E6)
//   · Temizlenmiş metinler TASLAK eklenir; yayımdaki sürümlere dokunulmaz.
//   · Editör notu ve eski başvuru adresi (hotmail) yoktur; adres tek.
//   · ⟦DOĞRULANACAK: …⟧ alanı doldurulmamış metin yayımlanamaz.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createHash, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { simdi } = await import('../src/db.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const { degisiklikOnayi, onayKimligi } = await import('./admin_onay.js');

let db, sunucu, taban, cerez;

async function istek(yol, { yontem = 'GET', govde } = {}) {
  await degisiklikOnayi(taban, yol, yontem, cerez);
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1', Cookie: cerez ?? '' },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
/** 034 göçünü (tohumlamadan SONRA, canlıdaki sırayla) uygular. */
async function gocuUygula() {
  const sql = readFileSync(new URL(`../migrations/${db.surucu}/034_yasal_taslaklar.sql`, import.meta.url), 'utf8');
  for (const p of sql.split(/\n(?=INSERT INTO legal_versions)/).slice(1)) await db.prepare(p.trim().replace(/;$/, '')).run();
}
const KIMLIKLER = ['b001', 'b002', 'b003', 'b004'].map((x) => `7b0e6f2a-3c1d-4e5f-9a8b-23102026${x}`);
const KOSUL = `id IN (${KIMLIKLER.map((k) => `'${k}'`).join(', ')})`;
const yayimdakiler = async () => (await db.prepare(`SELECT slug, id, version FROM legal_versions WHERE status = 'PUBLISHED' ORDER BY slug`).all());

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  const sir = base32Uret();
  await db.prepare("INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, 't@hc.test', 'T', 'content', ?, ?, ?)")
    .run(randomUUID(), sifreOzetle('GucluSifre12345'), sirSifrele(sir), simdi());
  const g = await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email: 't@hc.test', password: 'GucluSifre12345' }) });
  cerez = g.headers.get('set-cookie').split(';')[0];
  await fetch(`${taban}/admin/v1/auth/mfa`, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: cerez, 'X-HC-Admin': '1' }, body: JSON.stringify({ code: totpUret(sir) }) });
  onayKimligi(cerez, 'GucluSifre12345', sir);
});
after(async () => { sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

test('034: dört belge TASLAK eklenir; yayımdaki sürümler değişmez; tekrar uygulanınca çoğalmaz', async () => {
  const once = await yayimdakiler();
  await gocuUygula();
  await gocuUygula();
  assert.deepEqual(await yayimdakiler(), once, 'yayımdaki sürüm ve kimlikler aynı');
  const taslak = await db.prepare(`SELECT slug, body, sha256 FROM legal_versions WHERE ${KOSUL} ORDER BY slug`).all();
  assert.deepEqual(taslak.map((x) => x.slug), ['cookies', 'kvkk', 'privacy', 'terms']);
  for (const t of taslak) {
    assert.equal(createHash('sha256').update(t.body.trim(), 'utf8').digest('hex'), t.sha256, `${t.slug}: özet gövdeyle aynı`);
    assert.equal(/hotmail|YAYIN ENGEL|YAYIN ÖNCES|yayımdan önce/i.test(t.body), false, `${t.slug}: editör notu ve eski adres yok`);
    assert.ok(t.body.includes('destek@hizmetcep.com'), `${t.slug}: başvuru adresi tek`);
  }
  assert.equal((await db.prepare(`SELECT COUNT(*) n FROM legal_versions WHERE status = 'DRAFT' AND ${KOSUL}`).get()).n, 4);
});

test('yayın kapısı: DOĞRULANACAK alanı olan taslak yayımlanamaz; temiz taslak yayımlanır', async () => {
  const surum = async (slug) => (await db.prepare(`SELECT version FROM legal_versions WHERE ${KOSUL} AND slug = ?`).get(slug)).version;
  const p = await istek(`/admin/v1/legal/privacy/versions/${await surum('privacy')}/publish`, { yontem: 'POST', govde: { reason: 'Hukukçu onayı' } });
  assert.equal(p.durum, 400);
  assert.match(p.json.error.message, /DOĞRULANACAK/);
  assert.equal((await db.prepare(`SELECT status FROM legal_versions WHERE slug = 'privacy' AND version = ?`).get(await surum('privacy'))).status, 'DRAFT');
  // Yeni sürümü doğrudan yayımlama da aynı kapıdan geçer.
  const y = await istek('/admin/v1/legal/kvkk/versions', { yontem: 'POST', govde: { body: 'Metin ⟦DOĞRULANACAK: hukuki sebep⟧ eksik bir aydınlatma metni.', publish: true } });
  assert.equal(y.durum, 400);
  // Yer tutucusu olmayan taslak (Çerez Politikası) yayımlanabilir.
  const c = await istek(`/admin/v1/legal/cookies/versions/${await surum('cookies')}/publish`, { yontem: 'POST', govde: { reason: 'Adres tekleştirildi' } });
  assert.equal(c.durum, 200, JSON.stringify(c.json));
});
