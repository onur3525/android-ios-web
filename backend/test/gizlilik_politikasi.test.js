// 020 — Gizlilik Politikası metni (15 Eki). Canlı veritabanında 'privacy'
// belgesi zaten vardır; migration yeni sürümü yayınlar, öncekini arşivler.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';

process.env.HC_SESSIZ = '1';
const { simdi, gocDosyalari } = await import('../src/db.js');
const { testDb } = await import('./destek.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');

test('020: mevcut privacy belgesine yeni sürüm yayınlanır, önceki arşivlenir, metin birebir', async () => {
  const db = await testDb();
  await tohumla(db);
  await db.prepare(`INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_at)
    VALUES (?, 'privacy', 1, 'eski gizlilik metni', 'x', '2026-09-01', 'PUBLISHED', ?)`).run(randomUUID(), simdi());
  const goc = gocDosyalari(db.surucu).find((g) => g.id.startsWith('020'));
  assert.ok(goc, '020 migration bulunamadı');
  await db.exec(goc.sql);
  const surumler = await db.prepare(`SELECT version, status, body, sha256 FROM legal_versions WHERE slug = 'privacy' ORDER BY version`).all();
  assert.deepEqual(surumler.map((s) => [s.version, s.status]), [[1, 'ARCHIVED'], [2, 'PUBLISHED']]);
  const yeni = surumler[1];
  assert.match(yeni.body, /^## 1\. Veri sorumlusu/);
  assert.match(yeni.body, /## 12\. Güncellemeler/);
  assert.match(yeni.body, /HizmetCep'in işletmecisi/, 'kesme işareti korunur');
  assert.ok(!/BELGE 2|KVKK AYDINLATMA METNİ|KONTROL LİSTESİ|Önemli not/.test(yeni.body), 'diğer belgeler ya da iç notlar girmiş');
  assert.equal(yeni.sha256, createHash('sha256').update(yeni.body, 'utf8').digest('hex'));
  // Kullanım koşulları etkilenmez.
  assert.equal(Number((await db.prepare(`SELECT COUNT(*) n FROM legal_versions WHERE slug = 'terms' AND body LIKE '%Veri sorumlusu%'`).get()).n), 0);
});

test('020: privacy belgesi yoksa (boş veritabanı) hiçbir şey eklemez; iki sürücünün metni aynı', async () => {
  const db = await testDb();
  assert.equal(Number((await db.prepare(`SELECT COUNT(*) n FROM legal_versions`).get()).n), 0);
  const pg = readFileSync(new URL('../migrations/postgres/020_gizlilik_politikasi.sql', import.meta.url), 'utf8');
  const sq = readFileSync(new URL('../migrations/sqlite/020_gizlilik_politikasi.sql', import.meta.url), 'utf8');
  assert.equal(pg.split('\n').slice(1).join('\n'), sq.split('\n').slice(1).join('\n'));
});
