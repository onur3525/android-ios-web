// ═══════════════════════════════════════════════════════════════
// YÜKLENEN DOSYANIN SUNUCUDA DOĞRULANMASI (yöntem B: yükleme sonrası HEAD)
//
// İmzalı PUT adresi içerik türünü bağlar ama BOYUTU bağlamaz (R2/S3'te
// imzalı PUT için content-length-range yok; o yalnız POST politikasında
// var). İstemci "image/jpeg" deyip başka bayt da gönderebilir. Bu yüzden
// dosya bir kayda (ilan, mesaj, talep, profil) BAĞLANMADAN ÖNCE sunucu
// nesneyi depodan okur (HEAD + ilk 16 bayt) ve AYRI AYRI denetler:
//   1. anahtar: `u/<sahip>/<uuid>.<uzantı>`, sahip = kayıt sahibi
//   2. uzantı = beyan edilen tür
//   3. tür sınırı tanımlı mı
//   4. nesne depoda var mı
//   5. gerçek boyut ≤ beyan ≤ tür sınırı
//   6. deponun bildirdiği içerik türü = beyan
//   7. sihirli baytlar = beyan (JPEG/PNG/WEBP/HEIC; SVG KABUL EDİLMEZ)
// Başarısızlıkta kayıt DISCARDED olur ve silme kuyruğuna girer
// (dosya_temizligi işi siler) — öksüz nesne kalmaz.
//
// Depo okuyucusu değiştirilebilir (testlerde sahte). Gerçek S3/R2
// davranışı bu ortamda SINANMADI.
// ═══════════════════════════════════════════════════════════════
import { depolamaAyari, s3ImzaliAdres } from './entegrasyon.js';
import { simdi } from './db.js';
import { ApiHatasi, hata } from './http.js';

export const TUR_SINIRI = { 'listing-photo': 10 * 1024 * 1024, 'profile-photo': 10 * 1024 * 1024 };
export const ICERIK_UZANTI = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/heic': 'heic' };
const ANAHTAR = /^u\/([0-9a-f-]{36})\/([0-9a-f-]{36})\.(jpg|png|webp|heic)$/;

/** İlk baytlardan gerçek görsel türü; tanınmazsa null. */
export function sihirliBaytTuru(b) {
  if (!b || b.length < 12) return null;
  if (b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return 'image/jpeg';
  if (b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47 && b[4] === 0x0d && b[5] === 0x0a && b[6] === 0x1a && b[7] === 0x0a) return 'image/png';
  if (b.toString('latin1', 0, 4) === 'RIFF' && b.toString('latin1', 8, 12) === 'WEBP') return 'image/webp';
  if (b.toString('latin1', 4, 8) === 'ftyp' && ['heic', 'heix', 'hevc', 'hevx', 'mif1', 'msf1'].includes(b.toString('latin1', 8, 12))) return 'image/heic';
  return null;
}

async function gercekOkuyucu(ayar, ref) {
  const h = await fetch(s3ImzaliAdres(ayar, { yontem: 'HEAD', anahtar: ref, sureSn: 120 }), { method: 'HEAD', signal: AbortSignal.timeout(8000), redirect: 'error' });
  if (h.status === 404) return { var: false };
  if (!h.ok) throw new Error(`depo HEAD ${h.status}`);
  const g = await fetch(s3ImzaliAdres(ayar, { yontem: 'GET', anahtar: ref, sureSn: 120 }), {
    headers: { Range: 'bytes=0-15' }, signal: AbortSignal.timeout(8000), redirect: 'error',
  });
  if (!g.ok) throw new Error(`depo GET ${g.status}`);
  const bas = Buffer.from(await g.arrayBuffer()).subarray(0, 16);
  return { var: true, boyut: Number(h.headers.get('content-length')), icerikTuru: (h.headers.get('content-type') ?? '').split(';')[0].trim().toLowerCase(), bas };
}

let okuyucu = gercekOkuyucu;
/** Yalnız testler: sahte depo okuyucusu (null → gerçek). */
export function depoOkuyucusuAta(f) { okuyucu = f ?? gercekOkuyucu; }

/** Saf denetim — sorun metni ya da null. */
export function nesneSorunu(o, bilgi) {
  const m = ANAHTAR.exec(o.ref);
  if (!m || m[1] !== o.owner_id) return 'anahtar sahiple uyuşmuyor';
  if (ICERIK_UZANTI[o.content_type] !== m[3]) return 'uzantı türle uyuşmuyor';
  const sinir = TUR_SINIRI[o.kind];
  if (!sinir) return 'geçersiz tür';
  if (!bilgi.var) return 'dosya yüklenmemiş';
  if (!Number.isFinite(bilgi.boyut) || bilgi.boyut < 1) return 'boyut okunamadı';
  if (bilgi.boyut > o.size_bytes || bilgi.boyut > sinir) return 'dosya beyan edilen boyuttan büyük';
  if (bilgi.icerikTuru && bilgi.icerikTuru !== o.content_type) return 'içerik türü uyuşmuyor';
  if (sihirliBaytTuru(bilgi.bas) !== o.content_type) return 'dosya içeriği beyan edilen türde değil';
  return null;
}

/**
 * Kayda bağlanacak dosyaları İŞLEM DIŞINDA doğrular (ağ çağrısı uzun işlem açmasın).
 * @param {string|null} beklenenTur 'listing-photo' | 'profile-photo' | null
 */
export async function dosyalariDogrula(db, refler, kullaniciId, beklenenTur = null) {
  for (const ref of refler) {
    const o = await db.prepare('SELECT * FROM storage_objects WHERE ref = ?').get(ref);
    if (!o || o.owner_id !== kullaniciId || o.status === 'DISCARDED') throw hata.dogrulama('Geçersiz fotoğraf');
    if (beklenenTur && o.kind !== beklenenTur) throw hata.dogrulama('Geçersiz fotoğraf');
    if (o.verified_at || o.status !== 'PENDING') continue; // doğrulanmış ya da bu sürümden önce bağlanmış
    const ayar = await depolamaAyari(db);
    if (!ayar) throw new ApiHatasi(503, 'EXTERNAL_SERVICE_ERROR', 'Dosya şu anda doğrulanamıyor');
    let bilgi;
    try {
      bilgi = await okuyucu(ayar, ref);
    } catch {
      throw new ApiHatasi(503, 'EXTERNAL_SERVICE_ERROR', 'Dosya şu anda doğrulanamıyor. Lütfen tekrar deneyin.');
    }
    const sorun = nesneSorunu(o, bilgi);
    if (sorun) {
      if (bilgi.var) {
        await db.prepare(`UPDATE storage_objects SET status = 'DISCARDED', delete_requested_at = ? WHERE ref = ? AND status = 'PENDING'`).run(simdi(), ref);
      }
      throw hata.dogrulama(bilgi.var ? 'Fotoğraf doğrulanamadı. Lütfen geçerli bir JPG, PNG, WEBP ya da HEIC yükleyin.' : 'Fotoğraf yüklenmemiş');
    }
    await db.prepare('UPDATE storage_objects SET verified_at = ? WHERE ref = ?').run(simdi(), ref);
  }
}

/** Görüntüleme için 1 saatlik imzalı adres (profil fotoğrafı); yoksa null. */
export async function imzaliGorselAdresi(db, ref, ayar = undefined) {
  if (!ref) return null;
  const a = ayar === undefined ? await depolamaAyari(db) : ayar;
  if (!a) return null;
  return s3ImzaliAdres(a, { yontem: 'GET', anahtar: ref, sureSn: 3600 });
}
