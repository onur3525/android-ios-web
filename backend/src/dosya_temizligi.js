// ═══════════════════════════════════════════════════════════════
// KULLANICI DOSYALARININ FİZİKSEL SİLİNMESİ (mevcut özel nesne depolama)
//
// Akış: OLAY → kayıt işaretlenir (DISCARDED + delete_requested_at) →
// arka plan işi (`dosya_temizligi`, mevcut kilitli iş altyapısı) nesneyi
// imzalı DELETE ile depodan siler → deleted_at yazılır.
//
// GÜVENCELER
//   · Anahtar KULLANICIDAN ALINMAZ: yalnız storage_objects kayıtları
//     işlenir; kayıt sahibi (owner_id) ile anahtar öneki (u/<sahip>/)
//     birlikte doğrulanır. Kategori fotoğrafları (katalog/…) bu tabloda
//     yoktur ve bu kalıba uymaz → asla dokunulmaz.
//   · CANLI BAŞVURU KORUMASI: silmeden hemen önce dosya hâlâ bir canlı
//     kayıtta (açık ilan, sohbet mesajı, teklif talebi) kullanılıyorsa
//     silinmez, ATTACHED'a geri alınır. Sahibi silinmiş hesapsa (verisi
//     anonimleştirilmiş) başvurular kişisel veriyi korumaz → silinir.
//   · İDEMPOTENT: deleted_at dolu kayıt yeniden işlenmez; depoda zaten
//     olmayan nesne (404) başarı sayılır.
//   · HATA SESSİZ KALMAZ: başarısız deneme delete_attempts/delete_error'a
//     ve denetim kaydına yazılır; artan aralıkla (1 dk → en fazla 6 sa,
//     delete_next_at) yeniden denenir, en fazla AZAMI_DENEME kez. Tükenen
//     kayıt yönetici panelinde (Silme Kuyrukları) görünür ve oradan yeniden
//     denemeye alınabilir. Ana işlem (ilan/hesap silme) hiçbir zaman bu
//     yüzden başarısız olmaz.
// ═══════════════════════════════════════════════════════════════
import { denetimYaz } from './audit.js';
import { simdi } from './db.js';
import { depolamaAyari, s3ImzaliAdres } from './entegrasyon.js';

const KULLANICI_ANAHTARI = /^u\/([0-9a-f-]{36})\/[0-9a-f-]{36}\.(jpg|png|webp|heic)$/;
export const AZAMI_DENEME = 10;
const AZAMI_ARALIK_DK = 6 * 60;
const TUR_BOYU = 100;

/** Sahibine ait kayıtları silme kuyruğuna alır. Başka kullanıcının dosyası işaretlenemez. */
export async function silinmekUzereIsaretle(db, refler, sahipId) {
  let n = 0;
  for (const ref of new Set(refler)) {
    const m = KULLANICI_ANAHTARI.exec(String(ref));
    if (!m || m[1] !== sahipId) continue; // anahtar öneki sahiple aynı olmalı
    // Aynı dosya sahibinin BAŞKA canlı kaydında (açık ilan, mesaj, teklif
    // talebi) kullanılıyorsa hiç işaretlenmez: DISCARDED işareti o kayıtta
    // dosyayı (iş geri alana kadar) görünmez kılardı.
    if (await canliBasvuruVar(db, ref, sahipId)) continue;
    const r = await db.prepare(
      `UPDATE storage_objects SET status = 'DISCARDED', delete_requested_at = COALESCE(delete_requested_at, ?)
        WHERE ref = ? AND owner_id = ? AND deleted_at IS NULL`,
    ).run(simdi(), ref, sahipId);
    n += r.changes;
  }
  return n;
}

/** Hesabın bütün dosyalarını kuyruğa alır (hesap silme). */
export async function hesapDosyalariniIsaretle(db, sahipId) {
  const r = await db.prepare(
    `UPDATE storage_objects SET status = 'DISCARDED', delete_requested_at = COALESCE(delete_requested_at, ?)
      WHERE owner_id = ? AND deleted_at IS NULL`,
  ).run(simdi(), sahipId);
  return r.changes;
}

/** Dosya hâlâ canlı bir kayıtta kullanılıyor mu? (silmeden hemen önce) */
async function canliBasvuruVar(db, ref, sahipId) {
  const sahip = await db.prepare('SELECT deleted_at FROM users WHERE id = ?').get(sahipId);
  if (!sahip || sahip.deleted_at) return false; // hesap silindi: başvurular kişisel veriyi korumaz
  const kalip = `%"${ref}"%`;
  return !!(await db.prepare(`SELECT 1 FROM listings WHERE photo_refs_json LIKE ? AND status <> 'USER_DELETED'`).get(kalip)
    || await db.prepare('SELECT 1 FROM messages WHERE storage_ref = ?').get(ref)
    || await db.prepare('SELECT 1 FROM teklif_talepleri WHERE fotograflar_json LIKE ?').get(kalip)
    || await db.prepare('SELECT 1 FROM teklif_mesajlari WHERE fotograf_ref = ?').get(ref)
    || await db.prepare('SELECT 1 FROM users WHERE photo_customer_ref = ? OR photo_provider_ref = ?').get(ref, ref));
}

/** Arka plan işi: kuyruktaki nesneleri depodan siler. */
export async function dosyaTemizliginiIsle(db, { silici } = {}) {
  const ayar = await depolamaAyari(db);
  if (!ayar && !silici) return 0; // depo yapılandırılmamış: kuyruk bekler
  const sil = silici ?? (async (anahtar) => {
    const r = await fetch(s3ImzaliAdres(ayar, { yontem: 'DELETE', anahtar, sureSn: 300 }), { method: 'DELETE', signal: AbortSignal.timeout(10000) });
    return r.ok || r.status === 404;
  });
  const kuyruk = await db.prepare(
    `SELECT ref, owner_id, delete_attempts FROM storage_objects
      WHERE status = 'DISCARDED' AND deleted_at IS NULL AND delete_attempts < ?
        AND (delete_next_at IS NULL OR delete_next_at <= ?)
      ORDER BY created_at LIMIT ${TUR_BOYU}`,
  ).all(AZAMI_DENEME, simdi());
  let silinen = 0;
  for (const o of kuyruk) {
    const m = KULLANICI_ANAHTARI.exec(o.ref);
    if (!m || m[1] !== o.owner_id) continue; // beklenmeyen anahtar: dokunma
    if (await canliBasvuruVar(db, o.ref, o.owner_id)) {
      await db.prepare(`UPDATE storage_objects SET status = 'ATTACHED', delete_requested_at = NULL WHERE ref = ?`).run(o.ref);
      continue;
    }
    let tamam = false; let hataMetni = null;
    try { tamam = await sil(o.ref); } catch (e) { hataMetni = String(e?.message ?? e).slice(0, 300); }
    if (tamam) {
      await db.prepare('UPDATE storage_objects SET deleted_at = ?, delete_error = NULL, delete_next_at = NULL WHERE ref = ?').run(simdi(), o.ref);
      silinen++;
    } else {
      const hataNotu = hataMetni ?? 'depo silme isteği başarısız';
      const aralikDk = Math.min(2 ** o.delete_attempts, AZAMI_ARALIK_DK);
      await db.prepare('UPDATE storage_objects SET delete_attempts = delete_attempts + 1, delete_error = ?, delete_next_at = ? WHERE ref = ?')
        .run(hataNotu, new Date(Date.now() + aralikDk * 60_000).toISOString(), o.ref);
      await denetimYaz(db, { adminId: null, islem: 'storage.delete.failed', hedefTur: 'storage_object', hedefId: o.ref, sonra: { deneme: o.delete_attempts + 1, hata: hataNotu } }).catch(() => {});
    }
  }
  return silinen;
}
