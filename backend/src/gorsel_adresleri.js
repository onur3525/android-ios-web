// ═══════════════════════════════════════════════════════════════
// YANITLARDAKİ DOSYA REFERANSLARINA İMZALI GÖRÜNTÜLEME ADRESİ EKLER
//
// Sorun: ilan (`photoPaths`), teklif talebi (`fotograflar`, mesaj
// `fotografRef`) ve sohbet mesajı (`storageRef`) yanıtları yalnız depo
// REFERANSI taşıyordu (`u/<kullanıcı>/<uuid>.jpg`). İstemci referansı
// çizemiyordu → API modunda fotoğraflar yer tutucu olarak görünüyordu.
//
// Çözüm (mevcut sözleşmeyi BOZMADAN): referans alanları AYNEN kalır;
// yanına aynı sıradaki imzalı GET adresleri eklenir:
//   photoPaths   → photoUrls
//   fotograflar  → fotografAdresleri
//   fotografRef  → fotografUrl
//   storageRef   → storageUrl   (yalnız mesaj nesnelerinde: senderId olan)
//
// ⚠ YETKİ: bu yardımcı yalnız kullanıcının ZATEN görmeye yetkili olduğu
// yanıtlara uygulanır (ilan/talep/sohbet rotalarının kendi denetimleri).
// Ayrıca yalnız `storage_objects`'te kayıtlı, atılmamış (DISCARDED değil)
// ve silme kuyruğunda olmayan referanslar imzalanır; bilinmeyen → null.
// ⚠ Depolama yapılandırılmamışsa adresler null döner (sahte adres yok);
// istemci referansa düşer ve yer tutucu çizer.
// İmza yerel HMAC hesabıdır (ağ çağrısı yok); süre 1 saat.
// ═══════════════════════════════════════════════════════════════
import { depolamaAyari, s3ImzaliAdres } from './entegrasyon.js';

const GECERLI_REF = /^[A-Za-z0-9/_.-]{1,200}$/;
const SURE_SN = 3600;
const AZAMI_DERINLIK = 6;

function topla(deger, hedefler, derinlik = 0) {
  if (derinlik > AZAMI_DERINLIK || deger === null || typeof deger !== 'object') return;
  if (Array.isArray(deger)) {
    for (const x of deger) topla(x, hedefler, derinlik + 1);
    return;
  }
  if (Array.isArray(deger.photoPaths)) hedefler.push([deger, 'photoPaths', 'photoUrls', true]);
  if (Array.isArray(deger.fotograflar)) hedefler.push([deger, 'fotograflar', 'fotografAdresleri', true]);
  if (typeof deger.fotografRef === 'string') hedefler.push([deger, 'fotografRef', 'fotografUrl', false]);
  if (typeof deger.storageRef === 'string' && 'senderId' in deger) hedefler.push([deger, 'storageRef', 'storageUrl', false]);
  for (const v of Object.values(deger)) {
    if (v !== null && typeof v === 'object') topla(v, hedefler, derinlik + 1);
  }
}

/**
 * Yanıtı YERİNDE zenginleştirir ve aynı nesneyi döner.
 * Hata durumunda yanıtı bozmaz (adresler eklenmez).
 */
export async function gorselAdresleriEkle(db, yanit) {
  const hedefler = [];
  topla(yanit, hedefler);
  if (!hedefler.length) return yanit;
  const refler = new Set();
  for (const [o, kaynak, , dizi] of hedefler) {
    for (const r of dizi ? o[kaynak] : [o[kaynak]]) {
      if (typeof r === 'string' && GECERLI_REF.test(r)) refler.add(r);
    }
  }
  let ayar = null;
  const gecerli = new Set();
  try {
    if (refler.size) {
      ayar = await depolamaAyari(db);
      if (ayar) {
        const liste = [...refler];
        for (let i = 0; i < liste.length; i += 200) {
          const parca = liste.slice(i, i + 200);
          const satirlar = await db.prepare(
            `SELECT ref FROM storage_objects WHERE status <> 'DISCARDED' AND delete_requested_at IS NULL AND deleted_at IS NULL AND ref IN (${parca.map(() => '?').join(', ')})`,
          ).all(...parca);
          for (const s of satirlar) gecerli.add(s.ref);
        }
      }
    }
  } catch {
    ayar = null; // depolama/okuma hatası: yanıt yine döner, adres eklenmez
  }
  const imzala = (r) => (ayar && typeof r === 'string' && gecerli.has(r)
    ? s3ImzaliAdres(ayar, { yontem: 'GET', anahtar: r, sureSn: SURE_SN })
    : null);
  for (const [o, kaynak, hedef, dizi] of hedefler) {
    o[hedef] = dizi ? o[kaynak].map(imzala) : imzala(o[kaynak]);
  }
  return yanit;
}
