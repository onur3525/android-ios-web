// 023 — KVKK Aydınlatma Metni (16 Eki, kullanıcı isteği). Canlı veritabanında
// 'kvkk' belgesi vardır; migration yeni sürümü yayınlar, öncekini arşivler.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';

process.env.HC_SESSIZ = '1';
const { simdi, gocDosyalari } = await import('../src/db.js');
const { testDb } = await import('./destek.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');

test('023: kvkk belgesine yeni sürüm yayınlanır, önceki arşivlenir, metin birebir', async () => {
  const db = await testDb();
  await tohumla(db);
  await db.prepare(`INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_at)
    VALUES (?, 'kvkk', 1, 'eski metin', 'x', '2026-09-01', 'PUBLISHED', ?)`).run(randomUUID(), simdi());
  const goc = gocDosyalari(db.surucu).find((g) => g.id.startsWith('023'));
  assert.ok(goc, '023 migration bulunamadı');
  await db.exec(goc.sql);
  const surumler = await db.prepare(`SELECT version, status, body, sha256, effective_date FROM legal_versions WHERE slug = 'kvkk' ORDER BY version`).all();
  assert.deepEqual(surumler.map((s) => [s.version, s.status]), [[1, 'ARCHIVED'], [2, 'PUBLISHED']]);
  const yeni = surumler[1];
  assert.match(yeni.body, /^Bu metin, 6698 sayılı Kişisel Verilerin Korunması Kanunu/);
  assert.match(yeni.body, /## 1\. Veri Sorumlusu ve İletişim Bilgileri/);
  assert.match(yeni.body, /## 10\. Güncellemeler/);
  assert.match(yeni.body, /HizmetCep’in özellikleri/);
  assert.ok(!/Taslak • 16\.10\.2026|^Tarih:/m.test(yeni.body), 'başlık/tarih/alt satır girmiş');
  assert.equal(yeni.sha256, createHash('sha256').update(yeni.body, 'utf8').digest('hex'));
  assert.equal(String(yeni.effective_date).slice(0, 10), '2026-10-16');
});

test('023: kvkk belgesi yoksa (boş veritabanı) eklemez; iki sürücünün metni aynı', async () => {
  const db = await testDb();
  assert.equal(Number((await db.prepare(`SELECT COUNT(*) n FROM legal_versions`).get()).n), 0);
  const pg = readFileSync(new URL('../migrations/postgres/023_aydinlatma_metni.sql', import.meta.url), 'utf8');
  const sq = readFileSync(new URL('../migrations/sqlite/023_aydinlatma_metni.sql', import.meta.url), 'utf8');
  assert.equal(pg.split('\n').slice(1).join('\n'), sq.split('\n').slice(1).join('\n'));
});
