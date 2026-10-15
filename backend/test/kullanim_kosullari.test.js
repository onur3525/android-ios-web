// 015 — Kullanım Koşulları test sürümü metni (15 Eki). Canlı veritabanında
// 'terms' belgesi zaten vardır; migration yeni sürümü yayınlar, öncekini arşivler.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';

process.env.HC_SESSIZ = '1';
const { simdi, gocDosyalari } = await import('../src/db.js');
const { testDb } = await import('./destek.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');

test('015: mevcut terms belgesine yeni sürüm yayınlanır, önceki arşivlenir, metin birebir', async () => {
  const db = await testDb();
  await tohumla(db);
  // Canlıdaki gibi önceden yayında bir sürüm olsun.
  await db.prepare(`INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_at)
    VALUES (?, 'terms', 1, 'eski kullanım koşulları metni', 'x', '2026-09-01', 'PUBLISHED', ?)`).run(randomUUID(), simdi());
  const goc = gocDosyalari(db.surucu).find((g) => g.id.startsWith('015'));
  assert.ok(goc, '015 migration bulunamadı');
  await db.exec(goc.sql);
  const surumler = await db.prepare(`SELECT version, status, body, sha256 FROM legal_versions WHERE slug = 'terms' ORDER BY version`).all();
  assert.deepEqual(surumler.map((s) => [s.version, s.status]), [[1, 'ARCHIVED'], [2, 'PUBLISHED']]);
  const yeni = surumler[1];
  assert.match(yeni.body, /^Bu koşullar, test sürümü kullanıcılarına/);
  assert.match(yeni.body, /## 17\. İletişim/);
  assert.ok(!/ÖNEMLİ NOT|DOĞRULAMA LİSTESİ|BELGE 2/.test(yeni.body), 'iç notlar ya da diğer belgeler girmiş');
  assert.equal(yeni.sha256, createHash('sha256').update(yeni.body, 'utf8').digest('hex'));
});

test('015: terms belgesi yoksa (boş veritabanı) hiçbir şey eklemez', async () => {
  const db = await testDb();
  const n = (await db.prepare(`SELECT COUNT(*) n FROM legal_versions`).get()).n;
  assert.equal(Number(n), 0);
  const pg = readFileSync(new URL('../migrations/postgres/015_kullanim_kosullari.sql', import.meta.url), 'utf8');
  const sq = readFileSync(new URL('../migrations/sqlite/015_kullanim_kosullari.sql', import.meta.url), 'utf8');
  assert.equal(pg.split('\n').slice(1).join('\n'), sq.split('\n').slice(1).join('\n'), 'iki sürücünün metni aynı olmalı');
});
