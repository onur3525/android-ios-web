// ═══════════════════════════════════════════════════════════════
// IDEMPOTENCY — ortak kural (ilan, teklif, teklif talebi, mesajlar)
//
//   · Aynı kullanıcı + aynı Idempotency-Key → İLK işlemin sonucu döner,
//     ikinci kayıt OLUŞMAZ (ağ zaman aşımı sonrası yeniden deneme).
//   · Aynı anahtar FARKLI gövdeyle gelirse 409 IDEMPOTENCY_KEY_REUSED.
//   · Eşzamanlı aynı anahtarlı istekler: kısmi TEKİL dizin (kullanıcı,
//     anahtar) ikinciyi reddeder; ikinci istek ilk kaydı döndürür.
// Tablo/sütun adları SABİTTİR (kullanıcı girdisi değildir).
// ═══════════════════════════════════════════════════════════════
import { createHash } from 'node:crypto';
import { ApiHatasi } from './http.js';
import { tekilIhlaliMi } from './db.js';

/** İstekteki anahtar (gövde alanı ya da başlık), yoksa null. */
export function idemAnahtari(ctx, govdeAlani = null) {
  const ham = (govdeAlani && ctx.body?.[govdeAlani]) || ctx.req.headers['idempotency-key'] || '';
  const a = String(ham).trim().slice(0, 100);
  return a || null;
}

function sirali(v) {
  if (Array.isArray(v)) return v.map(sirali);
  if (v && typeof v === 'object') return Object.fromEntries(Object.keys(v).sort().map((k) => [k, sirali(v[k])]));
  return v;
}

/** İşlemi belirleyen alanların özeti (anahtar sırası önemsiz). */
export function govdeOzeti(o) {
  return createHash('sha256').update(JSON.stringify(sirali(o ?? null))).digest('hex');
}

/** Anahtarla önceki kayıt; yoksa null. Farklı gövdeyle kullanılmışsa 409. */
export async function oncekiKayit(db, t, sahipId, anahtar, ozet) {
  if (!anahtar) return null;
  const r = await db.prepare(`SELECT * FROM ${t.tablo} WHERE ${t.sahipSutun} = ? AND idempotency_key = ?`).get(sahipId, anahtar);
  if (r && r.idem_hash && r.idem_hash !== ozet) {
    throw new ApiHatasi(409, 'IDEMPOTENCY_KEY_REUSED', 'Bu istek anahtarı farklı bir içerikle kullanıldı');
  }
  return r ?? null;
}

/** Kaydı oluşturur; eşzamanlı aynı anahtar tekil dizine takılırsa ilk kaydı döndürür. */
export async function idemOlustur(db, t, sahipId, anahtar, ozet, olustur) {
  try {
    return { yeni: true, kayit: await olustur() };
  } catch (e) {
    if (anahtar && tekilIhlaliMi(e)) {
      const r = await oncekiKayit(db, t, sahipId, anahtar, ozet);
      if (r) return { yeni: false, kayit: r };
    }
    throw e;
  }
}
