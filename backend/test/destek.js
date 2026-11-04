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

/**
 * ── PROFİL TAMAMLAMA DÜZENEĞİ (4 Kas) ──
 * Kayıt artık telefon doğrulaması ve adres istemiyor; ilan açma, teklif
 * isteme/verme ve iş listesi tamamlanmış profil ister (sunucu kapısı).
 * Bu düzenek, AKIŞI SINAMAYAN testlerde kaydedilen kişinin profilini
 * doğrudan veritabanında tamamlar (telefon doğrulandı + adres; hizmet
 * verende eşleşmeyen nötr kategori/ilçe — bildirim ve sıralama davranışı
 * değişmesin). Tamamlama akışının kendisi `profil_tamamlama.test.js`te
 * uç üzerinden sınanır. Mevcut adres/hizmet kaydı varsa dokunulmaz.
 */
export async function profilTamamlaDb(db, erisimTokeni) {
  const yuk = JSON.parse(Buffer.from(String(erisimTokeni).split('.')[1], 'base64url').toString('utf8'));
  const u = await db.prepare('SELECT id, roles FROM users WHERE id = ?').get(yuk.sub);
  if (!u) return;
  await db.prepare('UPDATE users SET phone_verified = TRUE WHERE id = ?').run(u.id);
  const z = new Date().toISOString();
  if (!(await db.prepare('SELECT 1 FROM addresses WHERE user_id = ?').get(u.id))) {
    await db.prepare('INSERT INTO addresses (user_id, city, district, neighborhood, updated_at) VALUES (?, ?, ?, ?, ?)')
      .run(u.id, 'İzmir', 'Konak', 'Alsancak', z);
  }
  if (u.roles.includes('PROVIDER') && !(await db.prepare('SELECT 1 FROM provider_profiles WHERE user_id = ?').get(u.id))) {
    await db.prepare('INSERT INTO provider_profiles (user_id, categories_json, districts_json, updated_at) VALUES (?, ?, ?, ?)')
      .run(u.id, '["__test_notr__"]', '["__test_notr__"]', z);
  }
}
