// ═══════════════════════════════════════════════════════════════
// GENEL DURUM — TEK KAYNAK (23 Eki)
//
// Sistem Durumu ekranı (/admin/v1/system/status) ve yönetici uyarıları
// (yonetici_uyarilari.js) genel durumu AYNI girdilerle, AYNI kurallarla
// (sistem_izleme.js › genelDurum) hesaplar. Panelde "Sorun var" görünen
// her durum e-posta uyarısında da aynı metinle yer alır.
// ═══════════════════════════════════════════════════════════════
import { kanalKaynaklari } from './entegrasyon.js';
import { silmeKuyruguSorunlari } from './routes/silme_kuyruklari.js';
import { apiOlcumleri, genelDurum, kaynakKullanimi, olcumleriYaz, yedekDurumu } from './sistem_izleme.js';

const GUN_MS = 86_400_000;

export async function genelDurumGirdileri(db, { yedekYenile = false } = {}) {
  // Bu örneğin biriken ölçümleri önce yazılır (gösterilen sayı güncel olsun).
  await olcumleriYaz(db).catch((e) => console.error('olcum_yazma', e?.message));
  const kaynak = await kaynakKullanimi(db);
  const apiOlcum = await apiOlcumleri(db);
  const yedek = await yedekDurumu(db, { yenile: yedekYenile });
  const silme = await silmeKuyruguSorunlari(db);
  const silmeTukenen = silme.filesExhausted + silme.firebaseLongFailure + silme.firebaseOpsLongFailure;
  // Kanalların gerçek kaynağı ve son 24 saatin başarısız gönderimleri.
  const kanallar = await kanalKaynaklari(db);
  const basarisiz24 = { SMS: 0, EMAIL: 0 };
  for (const x of await db.prepare(`SELECT channel, COUNT(*) n FROM outbound_messages WHERE status = 'FAILED' AND created_at > ? GROUP BY channel`)
    .all(new Date(Date.now() - GUN_MS).toISOString())) {
    if (x.channel in basarisiz24) basarisiz24[x.channel] = Number(x.n);
  }
  const tumEntegrasyon = (await db.prepare('SELECT type, active, last_test_ok FROM integrations WHERE deleted_at IS NULL').all())
    .map((x) => ({ type: x.type, active: x.active === 1 || x.active === true, lastTestOk: x.last_test_ok === null ? null : x.last_test_ok === 1 || x.last_test_ok === true }));
  const overall = genelDurum({ veritabaniOk: true, api: apiOlcum, kaynak, yedek, entegrasyonlar: tumEntegrasyon, silmeTukenen, kanallar, basarisiz24 });
  return { kaynak, apiOlcum, yedek, silme, silmeTukenen, kanallar, basarisiz24, overall };
}
