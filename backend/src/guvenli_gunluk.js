// ═══════════════════════════════════════════════════════════════
// GÜVENLİ HATA GÜNLÜĞÜ (KVKK takip denetimi B11, 22 Eki)
//
// Önceden beklenmeyen hatada hata NESNESİNİN TAMAMI yazılıyordu
// (`console.error(e)`). PostgreSQL hatalarının `detail`/`where`/
// `parameters` alanları kayıttaki DEĞERİ (telefon, e-posta) taşıyabilir;
// sağlayıcı yanıt metinleri adres ve jeton içerebilir. Günlükler
// barındırma sağlayıcısında (Render) tutulur.
//
// Artık yalnız şu alanlar yazılır: hata adı, kodu (ör. PostgreSQL
// SQLSTATE), MASKELENMİŞ ve kısaltılmış mesaj, yığının ilk satırları
// (yalnız dosya/satır). İstek kimliği çağıran tarafından eklenir —
// yanıttaki `requestId` ile eşleşir (korelasyon korunur).
// ═══════════════════════════════════════════════════════════════

const KALIPLAR = [
  [/Bearer\s+[A-Za-z0-9._~+/=-]+/gi, 'Bearer [jeton]'],
  [/\beyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]*/g, '[jeton]'],
  [/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, '[e-posta]'],
  // Telefon, OTP ve benzeri sayı dizileri (6+ hane; araya boşluk/tire girebilir).
  [/\+?\d(?:[\s-]?\d){5,}/g, '[sayı]'],
  // PostgreSQL ayrıntısı: Key (alan)=(değer)
  [/\(([^()]*)\)=\(([^()]*)\)/g, '($1)=([değer])'],
];

/** Metindeki kişisel/gizli değerleri maskeler. */
export function maskele(metin) {
  let s = String(metin ?? '');
  for (const [k, yerine] of KALIPLAR) s = s.replace(k, yerine);
  return s;
}

/** Günlüğe yazılabilir, kişisel veri içermeyen hata özeti. */
export function hataOzeti(e) {
  if (e == null || typeof e !== 'object') return { mesaj: maskele(e).slice(0, 300) };
  const ozet = { ad: String(e.name ?? 'Error').slice(0, 60) };
  if (e.code != null) ozet.kod = String(e.code).slice(0, 40);
  ozet.mesaj = maskele(e.message).slice(0, 300);
  if (typeof e.stack === 'string') {
    // İlk satır mesajın kendisidir (maskesiz) — atlanır; yalnız çerçeveler.
    ozet.yigin = e.stack.split('\n').slice(1, 6).map((l) => maskele(l.trim()));
  }
  return ozet;
}
