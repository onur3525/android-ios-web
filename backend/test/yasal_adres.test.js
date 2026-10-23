// YAYIMDAKİ YASAL METİNLERDEN EV ADRESİ KALDIRILDI (036, 23 Eki — işletmeci talimatı)
//   · Canlıdaki durum taklit edilir: 020/021/023/033 metinleri yayımda.
//   · 036 sonrası dört belgenin yeni sürümü yayımda; posta adresi yok,
//     iletişim e-postası onur_butun@hotmail.com; metnin geri kalanı AYNI.
//   · Eski sürümler silinmez, arşivlenir. Göç tekrar çalışınca çoğalmaz.
//   · Yayımdaki metin başka biriyse (admin değiştirdiyse) o belgeye dokunulmaz.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');

let db;
async function uygula(dosya) {
  const sql = readFileSync(new URL(`../migrations/${db.surucu}/${dosya}`, import.meta.url), 'utf8');
  for (const p of sql.split(/\n(?=INSERT INTO legal_versions|UPDATE legal_versions|UPDATE legal_documents)/).slice(1)) {
    await db.prepare(p.trim().replace(/;$/, '')).run();
  }
}
const yayimda = async (slug) => db.prepare(`SELECT * FROM legal_versions WHERE slug = ? AND status = 'PUBLISHED'`).get(slug);

before(async () => {
  db = await testDb();
  await tohumla(db);
  // Canlı: bu metinler yayımda (göçlerin tohumlamadan SONRA çalıştığı durum).
  for (const f of ['020_gizlilik_politikasi.sql', '021_kullanim_sozlesmesi.sql', '023_aydinlatma_metni.sql', '033_yasal_onay_duzeni.sql']) await uygula(f);
});
after(async () => { await db?.close(); });

test('036: dört belgede ev adresi kalkar; iletişim e-postası kalır; metnin geri kalanı aynı', async () => {
  const once = {};
  for (const s of ['privacy', 'terms', 'kvkk', 'cookies']) {
    once[s] = await yayimda(s);
    assert.ok(/1847/.test(once[s].body), `${s}: başlangıçta adres var (taklit doğru)`);
  }
  await uygula('036_yasal_adres_kaldirma.sql');
  await uygula('036_yasal_adres_kaldirma.sql');
  for (const s of ['privacy', 'terms', 'kvkk', 'cookies']) {
    const y = await yayimda(s);
    assert.notEqual(y.id, once[s].id, `${s}: yeni sürüm yayımda`);
    assert.equal(y.version, once[s].version + 1);
    assert.equal(/1847|Örnekköy|Karşıyaka\/İzmir|Karşıyaka \/ İzmir|yukarıdaki posta adresi/.test(y.body), false, `${s}: adres yok`);
    assert.ok(y.body.includes('E-posta: onur_butun@hotmail.com'), `${s}: iletişim e-postası adresin yerinde`);
    assert.ok(y.body.includes('Onur Bütün'), `${s}: ad duruyor`);
    assert.equal(createHash('sha256').update(y.body.trim(), 'utf8').digest('hex'), y.sha256);
    // Yalnız iletişim satırları değişti: değişen satır sayısı küçük.
    // Yalnız adres çıktı: adres içermeyen satırlar birebir aynı.
    const kalan = once[s].body.split('\n').filter((x) => !/1847/.test(x) && !/posta adresine/.test(x));
    for (const satir of kalan) assert.ok(y.body.includes(satir), `${s}: değişmeyen satır korunmalı`);
    assert.equal((await db.prepare('SELECT status FROM legal_versions WHERE id = ?').get(once[s].id)).status, 'ARCHIVED', `${s}: eski sürüm arşivde`);
    assert.equal((await db.prepare(`SELECT COUNT(*) n FROM legal_versions WHERE slug = ? AND status = 'PUBLISHED'`).get(s)).n, 1);
  }
  assert.equal((await db.prepare(`SELECT requires_acceptance r FROM legal_documents WHERE slug = 'terms'`).get()).r, 1, 'sözleşme yeni sürüm için yeniden onaylatılır');
});

test('036: yayımdaki metin başkaysa (panelden değiştirilmiş) belgeye dokunulmaz', async () => {
  const db2 = await testDb();
  try {
    await tohumla(db2);
    const eskiDb = db; db = db2;
    await uygula('020_gizlilik_politikasi.sql');
    await db2.prepare(`UPDATE legal_versions SET body = 'Panelden değiştirilmiş gizlilik metni, adres içermez.', sha256 = 'x' WHERE slug = 'privacy' AND status = 'PUBLISHED'`).run();
    const once = await yayimda('privacy');
    await uygula('036_yasal_adres_kaldirma.sql');
    assert.equal((await yayimda('privacy')).id, once.id, 'dokunulmadı');
    db = eskiDb;
  } finally { await db2.close(); }
});
