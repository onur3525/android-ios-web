// 021 — Kullanım Sözleşmesi metni (16 Eki, kullanıcı isteği). Canlı veritabanında
// 'terms' belgesi zaten vardır; migration yeni sürümü yayınlar, öncekini arşivler
// ve belgenin adını "Kullanım Sözleşmesi" yapar.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';

process.env.HC_SESSIZ = '1';
const { simdi, gocDosyalari } = await import('../src/db.js');
const { testDb } = await import('./destek.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');

test('021: terms belgesine yeni sürüm yayınlanır, önceki arşivlenir, metin yalnız Bölüm A', async () => {
  const db = await testDb();
  await tohumla(db);
  await db.prepare(`INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_at)
    VALUES (?, 'terms', 1, 'eski metin', 'x', '2026-09-01', 'PUBLISHED', ?)`).run(randomUUID(), simdi());
  const goc = gocDosyalari(db.surucu).find((g) => g.id.startsWith('021'));
  assert.ok(goc, '021 migration bulunamadı');
  await db.exec(goc.sql);
  const surumler = await db.prepare(`SELECT version, status, body, sha256, effective_date FROM legal_versions WHERE slug = 'terms' ORDER BY version`).all();
  assert.deepEqual(surumler.map((s) => [s.version, s.status]), [[1, 'ARCHIVED'], [2, 'PUBLISHED']]);
  const yeni = surumler[1];
  assert.match(yeni.body, /^## 1\. Taraflar ve tanımlar/);
  assert.match(yeni.body, /## 4\. Üyelik şartları ve yaş koşulu/);
  assert.match(yeni.body, /## 21\. Son hükümler ve elektronik kabul/);
  assert.match(yeni.body, /“Kullanım Sözleşmesi’ni okudum ve kabul ediyorum”/);
  assert.ok(!/BÖLÜM B|CLAUDE|UYGULAMA ÖNCESİ|Taslak sürüm|ÖNEMLİ:/.test(yeni.body), 'talimat ya da taslak notu girmiş');
  assert.equal(yeni.sha256, createHash('sha256').update(yeni.body, 'utf8').digest('hex'));
  assert.equal(String(yeni.effective_date).slice(0, 10), '2026-10-16');
  assert.equal((await db.prepare(`SELECT title FROM legal_documents WHERE slug = 'terms'`).get()).title, 'Kullanım Sözleşmesi');
  // Gizlilik politikası etkilenmez.
  assert.equal(Number((await db.prepare(`SELECT COUNT(*) n FROM legal_versions WHERE slug = 'privacy' AND body LIKE '%Taraflar ve tanımlar%'`).get()).n), 0);
});

test('021: terms belgesi yoksa (boş veritabanı) sürüm eklemez; iki sürücünün metni aynı', async () => {
  const db = await testDb();
  assert.equal(Number((await db.prepare(`SELECT COUNT(*) n FROM legal_versions`).get()).n), 0);
  const pg = readFileSync(new URL('../migrations/postgres/021_kullanim_sozlesmesi.sql', import.meta.url), 'utf8');
  const sq = readFileSync(new URL('../migrations/sqlite/021_kullanim_sozlesmesi.sql', import.meta.url), 'utf8');
  assert.equal(pg.split('\n').slice(1).join('\n'), sq.split('\n').slice(1).join('\n'));
});
