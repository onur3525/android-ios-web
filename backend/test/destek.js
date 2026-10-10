// Test veritabanı: her test DOSYASI kendi yalıtılmış veritabanını alır.
//   SQLite  → bellek içi (süreç başına ayrı)
//   PostgreSQL (CI) → AYNI sunucuda dosya başına RASTGELE ŞEMA
// ⚠ `node --test` dosyaları PARALEL koşturur; ortak tek şema kullanılsaydı
// başlangıç verisi, hız sınırı sayaçları ve ilan numaraları dosyalar
// arasında çakışırdı (ilk CI koşusundaki 18 hatanın nedeni buydu).
import { randomUUID } from 'node:crypto';
import { veritabaniAc } from '../src/db.js';

export function testDb() {
  if (process.env.HC_TEST_DB === 'postgres') {
    const sema = `t_${randomUUID().replace(/-/g, '').slice(0, 20)}`;
    return veritabaniAc({ surucu: 'postgres', url: process.env.HC_DATABASE_URL, ssl: false, sema });
  }
  return veritabaniAc({ surucu: 'sqlite', yol: ':memory:' });
}
