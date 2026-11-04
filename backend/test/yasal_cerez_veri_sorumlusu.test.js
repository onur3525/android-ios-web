// ÇEREZ POLİTİKASI VERİ SORUMLUSU = AYDINLATMA METNİ (050, 4 Kas — işletmeci talimatı)
//   · 036 sonrası yayımdaki Çerez Politikası'nda veri sorumlusu bölümü
//     Aydınlatma Metni'ndeki (047) ile birebir aynı olur.
//   · Eski e-posta metinde kalmaz; metnin geri kalanı AYNI.
//   · Eski sürüm arşivlenir; göç tekrar çalışınca çoğalmaz.
//   · Yayımdaki metin başkaysa (panelden değiştirilmiş) dokunulmaz.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');

const acik = [];
after(async () => { for (const d of acik) await d.close(); });

async function uygula(db, dosya) {
  const sql = readFileSync(new URL(`../migrations/${db.surucu}/${dosya}`, import.meta.url), 'utf8');
  for (const p of sql.split(/\n(?=INSERT INTO legal_versions|UPDATE legal_versions|UPDATE legal_documents)/).slice(1)) {
    await db.prepare(p.trim().replace(/;$/, '')).run();
  }
}
async function hazirla() {
  const db = await testDb();
  acik.push(db);
  await tohumla(db);
  for (const f of ['020_gizlilik_politikasi.sql', '021_kullanim_sozlesmesi.sql', '023_aydinlatma_metni.sql', '033_yasal_onay_duzeni.sql', '036_yasal_adres_kaldirma.sql', '040_yasal_son_hal.sql', '047_yasal_yurt_disi_5651.sql']) await uygula(db, f);
  return db;
}
const yayimda = (db, slug) => db.prepare(`SELECT * FROM legal_versions WHERE slug = ? AND status = 'PUBLISHED'`).get(slug);
const sorumluBolumu = (metin) => {
  const m = /## 1\. Veri [Ss]orumlusu\n\n([\s\S]*?)\n\n##/.exec(metin);
  return m ? m[1] : null;
};

test('050: Çerez Politikası veri sorumlusu bölümü Aydınlatma Metni ile aynı; geri kalan metin aynı', async () => {
  const db = await hazirla();
  const once = await yayimda(db, 'cookies');
  await uygula(db, '050_cerez_veri_sorumlusu.sql');
  await uygula(db, '050_cerez_veri_sorumlusu.sql');
  const y = await yayimda(db, 'cookies');
  assert.notEqual(y.id, once.id, 'yeni sürüm yayımda');
  assert.equal(y.version, once.version + 1);
  const kvkk = await yayimda(db, 'kvkk');
  assert.equal(sorumluBolumu(y.body), sorumluBolumu(kvkk.body), 'veri sorumlusu bilgileri birebir aynı');
  assert.equal(sorumluBolumu(y.body), 'Veri sorumlusu: Onur Bütün (Bütün Mühendislik)\nAdres: İzmir/Türkiye\nE-posta: onur@hizmetcep.com');
  assert.equal(y.body.includes('onur_butun@hotmail.com'), false, 'eski e-posta kalmadı');
  assert.ok(y.body.includes('taleplerinizi onur@hizmetcep.com adresine'), 'başvuru adresi güncel');
  assert.equal(createHash('sha256').update(y.body.trim(), 'utf8').digest('hex'), y.sha256);
  for (const satir of once.body.split('\n').filter((x) => !/Veri sorumlusu:|E-posta:|onur_butun/.test(x))) {
    assert.ok(y.body.includes(satir), `değişmeyen satır korunmalı: ${satir.slice(0, 40)}`);
  }
  assert.equal((await db.prepare('SELECT status FROM legal_versions WHERE id = ?').get(once.id)).status, 'ARCHIVED');
  assert.equal((await db.prepare(`SELECT COUNT(*) n FROM legal_versions WHERE slug = 'cookies' AND status = 'PUBLISHED'`).get()).n, 1);
});

test('050: yayımdaki metin başkaysa (panelden değiştirilmiş) belgeye dokunulmaz', async () => {
  const db = await hazirla();
  await db.prepare(`UPDATE legal_versions SET sha256 = 'panelden-degisti' WHERE slug = 'cookies' AND status = 'PUBLISHED'`).run();
  const once = await yayimda(db, 'cookies');
  await uygula(db, '050_cerez_veri_sorumlusu.sql');
  const y = await yayimda(db, 'cookies');
  assert.equal(y.id, once.id);
});
