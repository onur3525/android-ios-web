// YASAL METİNLERİN SON HÂLİ (040, 23 Eki — işletmeci talimatı)
//   · Canlıdaki durum taklit edilir: 020/021/023/033 → 036 yayımda.
//   · 040 sonrası Gizlilik, Kullanım Sözleşmesi ve Aydınlatma Metni'nin yeni
//     sürümü yayımda; HAZIRLIK NOTU YOK, boş bölüm yok; Çerez değişmez.
//   · 035 taslakları arşivlenir; eski sürümler silinmez; tekrar çalışınca çoğalmaz.
//   · Yayımdaki metin başkaysa (panelden değiştirilmiş) belgeye dokunulmaz.
//   · Politika'daki 2 yıllık saklama süreleri uygulanır.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { saklamaSuresiBakimi } = await import('../src/bakim.js');

async function uygula(db, dosya) {
  const sql = readFileSync(new URL(`../migrations/${db.surucu}/${dosya}`, import.meta.url), 'utf8');
  for (const p of sql.split(/\n(?=INSERT INTO legal_versions|UPDATE legal_versions|UPDATE legal_documents)/).slice(1)) {
    await db.prepare(p.trim().replace(/;$/, '')).run();
  }
}
const CANLI = ['020_gizlilik_politikasi.sql', '021_kullanim_sozlesmesi.sql', '023_aydinlatma_metni.sql', '033_yasal_onay_duzeni.sql',
  '034_yasal_taslaklar.sql', '035_yasal_taslak_iletisim.sql', '036_yasal_adres_kaldirma.sql'];
// Kullanıcıya gösterilen metinde OLMAMASI gereken hazırlık notları.
const NOTLAR = /YAYIN ENGELİ|YAYIN ÖNCESİ|DOĞRULANACAK|⟦|doğrulanmalı|yayımdan önce|yayıma hazır değil|envanter|hukukçu|test sürüm|kullanılıyorsa|planlanmıyorsa|belirlenmelidir|tamamlanmalıdır|çıkarılmalıdır|gösterilmelidir|karşılaştırılmalıdır/i;

let db;
const yayimda = async (slug) => db.prepare(`SELECT * FROM legal_versions WHERE slug = ? AND status = 'PUBLISHED'`).get(slug);
before(async () => {
  db = await testDb();
  await tohumla(db);
  for (const f of CANLI) await uygula(db, f);
});
after(async () => { await db?.close(); });

test('040: yayımdaki metinlerde hazırlık notu ve boş bölüm kalmaz; iletişim ve gerçek bilgiler yerinde', async () => {
  const once = {};
  for (const s of ['privacy', 'terms', 'kvkk', 'cookies']) once[s] = await yayimda(s);
  assert.ok(NOTLAR.test(once.privacy.body), 'başlangıçta canlı Gizlilik Politikası notlu (taklit doğru)');
  await uygula(db, '040_yasal_son_hal.sql');
  await uygula(db, '040_yasal_son_hal.sql');
  for (const s of ['privacy', 'terms', 'kvkk']) {
    const y = await yayimda(s);
    assert.notEqual(y.id, once[s].id, `${s}: yeni sürüm`);
    assert.equal(y.version, once[s].version + 1);
    assert.equal(NOTLAR.test(y.body), false, `${s}: hazırlık notu yok — ${y.body.match(NOTLAR)?.[0]}`);
    assert.equal(createHash('sha256').update(y.body.trim(), 'utf8').digest('hex'), y.sha256);
    assert.ok(y.body.includes('onur_butun@hotmail.com'));
    assert.equal(/1847|Örnekköy/.test(y.body), false, `${s}: ev adresi yok`);
    assert.equal((await db.prepare('SELECT status FROM legal_versions WHERE id = ?').get(once[s].id)).status, 'ARCHIVED');
    assert.equal(Number((await db.prepare(`SELECT COUNT(*) n FROM legal_versions WHERE slug = ? AND status = 'PUBLISHED'`).get(s)).n), 1);
  }
  const p = (await yayimda('privacy')).body;
  for (const parca of ['Cloudflare', 'Render', 'Resend', 'Google LLC', 'standart sözleşme', '2 yıl', '10 yıl', 'en fazla 7 gün']) {
    assert.ok(p.includes(parca), `privacy: ${parca}`);
  }
  assert.ok(p.includes('c bendi') && p.includes('f bendi') && p.includes('ç bendi'), 'hukuki sebepler amaç bazında');
  assert.ok((await yayimda('kvkk')).body.includes('m.5/2-c'));
  assert.ok((await yayimda('terms')).body.includes('ödeme aracılığı'), 'ödeme aracılığı yapılmadığı açık');
  assert.equal((await yayimda('cookies')).id, once.cookies.id, 'Çerez Politikası değişmez');
  // 035 taslakları arşivde; yayımlanabilir taslak kalmadı.
  assert.equal(Number((await db.prepare(`SELECT COUNT(*) n FROM legal_versions WHERE status = 'DRAFT' AND CAST(id AS TEXT) LIKE '%23102026b01%'`).get()).n), 0);
  assert.equal((await db.prepare(`SELECT requires_acceptance r FROM legal_documents WHERE slug = 'terms'`).get()).r, 1, 'sözleşme yeni sürüm için onaylatılır');
  assert.equal((await db.prepare(`SELECT requires_acceptance r FROM legal_documents WHERE slug = 'kvkk'`).get()).r, 0, 'aydınlatma onaylatılmaz (bilgilendirme)');
  assert.equal((await db.prepare(`SELECT active a FROM legal_documents WHERE slug = 'membership'`).get()).a, 0, 'Üyelik Sözleşmesi pasif (tek sözleşme)');
});

test('040: yayımdaki metin başkaysa (panelden değiştirilmiş) belgeye dokunulmaz', async () => {
  const db2 = await testDb();
  try {
    await tohumla(db2);
    for (const f of CANLI) await uygula(db2, f);
    const z = new Date().toISOString();
    await db2.prepare(`UPDATE legal_versions SET status = 'ARCHIVED' WHERE slug = 'privacy' AND status = 'PUBLISHED'`).run();
    await db2.prepare(`INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_at) VALUES (?, 'privacy', 99, 'panel metni', 'x', '2026-10-23', 'PUBLISHED', ?)`).run(randomUUID(), z);
    await uygula(db2, '040_yasal_son_hal.sql');
    const p = await db2.prepare(`SELECT body FROM legal_versions WHERE slug = 'privacy' AND status = 'PUBLISHED'`).get();
    assert.equal(p.body, 'panel metni');
  } finally { await db2.close(); }
});

test('saklama süresi: 2 yıldan eski gönderim kaydı ve üye olmayanın kapanmış destek e-postası silinir; yenileri ve üyelerinki kalır', async () => {
  const eski = new Date(Date.now() - 731 * 86_400_000).toISOString();
  const yeni = new Date().toISOString();
  const msj = (z) => db.prepare(`INSERT INTO outbound_messages (id, user_id, channel, target, template, subject, body, status, attempts, created_at) VALUES (?, NULL, 'EMAIL', 'a@b.c', 'OTP', NULL, '-', 'SENT', 1, ?)`).run(randomUUID(), z);
  await msj(eski); await msj(yeni);
  const talep = async (no, durum, z, kullanici = null) => {
    const id = randomUUID();
    await db.prepare(`INSERT INTO support_tickets (id, ticket_no, user_id, subject, message, status, created_at, updated_at, closed_at, source, sender_email) VALUES (?, ?, ?, 'k', 'm', ?, ?, ?, ?, 'EMAIL', 'x@y.z')`)
      .run(id, no, kullanici, durum, z, z, durum === 'CLOSED' ? z : null);
    await db.prepare(`INSERT INTO support_ticket_replies (id, ticket_id, admin_id, body, created_at, author) VALUES (?, ?, NULL, 'y', ?, 'USER')`).run(randomUUID(), id, z);
    return id;
  };
  const silinecek = await talep('800001', 'CLOSED', eski);
  const acik = await talep('800002', 'OPEN', eski);
  const yeniKapali = await talep('800003', 'CLOSED', yeni);
  const r = await saklamaSuresiBakimi(db);
  assert.deepEqual(r, { gonderim: 1, talep: 1 });
  assert.equal(await db.prepare('SELECT 1 FROM support_tickets WHERE id = ?').get(silinecek), undefined);
  assert.equal(await db.prepare('SELECT 1 FROM support_ticket_replies WHERE ticket_id = ?').get(silinecek), undefined);
  assert.ok(await db.prepare('SELECT 1 FROM support_tickets WHERE id = ?').get(acik), 'açık talep silinmez');
  assert.ok(await db.prepare('SELECT 1 FROM support_tickets WHERE id = ?').get(yeniKapali), '2 yılı dolmayan silinmez');
  assert.equal(Number((await db.prepare('SELECT COUNT(*) n FROM outbound_messages').get()).n), 1);
});
