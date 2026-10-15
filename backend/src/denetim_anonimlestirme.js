// ═══════════════════════════════════════════════════════════════
// HESAP SİLMEDE YÖNETİCİ KAYITLARININ ANONİMLEŞTİRİLMESİ (15 Eki)
//
// Denetim kaydı (audit_log) ve hesap durum geçmişi (user_status_history)
// hesap verebilirlik için SİLİNEMEZ. Ancak içlerinde silinen kişinin adı,
// telefonu, e-postası ya da yazdığı metin (ör. kaldırılan yorumun metni,
// gerekçeye yazılmış numara) kalabiliyordu.
//
// Hesap silinince bu kayıtlarda kişisel DEĞERLER maskelenir; şunlar KORUNUR:
// işlem türü, zaman damgası, işlemi yapan yönetici, yöneticinin IP'si,
// hedef türü ve kimliği, durum geçişleri, sayısal/durum alanları ve
// gerekçenin kişisel değer içermeyen kısmı. Veritabanı tetikleyicisi
// (migrations/018) güncellemeye YALNIZ bu tek seferlik maskelemede izin
// verir; korunan alanlar değişirse ya da kayıt silinmek istenirse reddeder.
//
// Sınır: serbest metinde dolaylı tanımlayıcılar (adres tarifi, takma ad)
// kalıp eşleşmesiyle yakalanamayabilir; bilinen ad/telefon/e-posta ve genel
// telefon/e-posta kalıpları maskelenir.
// ═══════════════════════════════════════════════════════════════

export const MASKE = '[kaldırıldı]';

// JSON alanlarında DEĞERİ her zaman kaldırılan anahtarlar (kişinin yazdığı ya
// da kişiyi tanımlayan içerik).
const KISISEL_ANAHTARLAR = new Set(['text', 'body', 'message', 'subject', 'name', 'phone', 'email', 'description', 'location', 'note', 'metin', 'aciklama']);

const kacis = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const GENEL_EPOSTA = /[\p{L}\p{N}._%+-]+@[\p{L}\p{N}-]+(?:\.[\p{L}\p{N}-]+)+/gu;
// Türkiye cep telefonu: +90 / 0 önekli ya da öneksiz, boşluk/nokta/tire ayraçlı.
const GENEL_TELEFON = /(?:\+?\s*90|0)?[\s.-]*5\d{2}(?:[\s.()-]*\d){7}/g;

function adKaliplari(ad) {
  const parcalar = String(ad ?? '').split(/\s+/).filter((p) => p.length >= 3);
  const tam = String(ad ?? '').trim();
  const adaylar = new Set();
  for (const p of tam.length >= 3 ? [tam, ...parcalar] : parcalar) {
    for (const v of [p, p.toLocaleLowerCase('tr'), p.toLocaleUpperCase('tr')]) adaylar.add(v);
  }
  return [...adaylar].sort((a, b) => b.length - a.length)
    .map((v) => new RegExp(`(?<![\\p{L}\\p{N}])${kacis(v)}(?![\\p{L}\\p{N}])`, 'giu'));
}

function telefonKalibi(tel) {
  const d = String(tel ?? '').replace(/\D/g, '').slice(-10);
  if (d.length !== 10) return null;
  return new RegExp(`(?:\\+?\\s*90|0)?[\\s.()-]*${d.split('').join('[\\s.()-]*')}`, 'g');
}

/** Kişiye özgü maskeleyici: bilinen değerler + genel telefon/e-posta kalıpları. */
export function maskeleyici({ ad, telefon, eposta }) {
  const kaliplar = [
    ...(eposta ? [new RegExp(kacis(String(eposta)), 'giu')] : []),
    ...(telefonKalibi(telefon) ? [telefonKalibi(telefon)] : []),
    ...adKaliplari(ad),
    GENEL_EPOSTA, GENEL_TELEFON,
  ];
  return (metin) => {
    if (metin == null) return metin;
    let m = String(metin);
    for (const k of kaliplar) m = m.replace(k, MASKE);
    return m;
  };
}

function jsonMaskele(deger, maskele) {
  if (deger == null) return deger;
  if (Array.isArray(deger)) return deger.map((x) => jsonMaskele(x, maskele));
  if (typeof deger === 'object') {
    return Object.fromEntries(Object.entries(deger).map(([k, v]) => [
      k, KISISEL_ANAHTARLAR.has(k) && v != null ? MASKE : jsonMaskele(v, maskele),
    ]));
  }
  return typeof deger === 'string' ? maskele(deger) : deger;
}
const jsonOku = (v) => (v == null ? null : (typeof v === 'string' ? JSON.parse(v) : v));

/**
 * Silinen hesaba bağlı yönetici kayıtlarını anonimleştirir (hesap silme
 * işleminin İÇİNDE, kullanıcı satırı anonimleşmeden ÖNCE çağrılır).
 * Dönen: maskelenen satır sayıları.
 */
export async function yoneticiKayitlariniAnonimlestir(db, { id, ad, telefon, eposta }, z) {
  const maskele = maskeleyici({ ad, telefon, eposta });
  const hedefler = await db.prepare(
    `SELECT id, before_json, after_json, reason FROM audit_log
      WHERE anonymized_at IS NULL AND (
            (target_type = 'user' AND target_id = ?)
         OR (target_type = 'listing' AND target_id IN (SELECT CAST(id AS TEXT) FROM listings WHERE owner_id = ?))
         OR (target_type = 'review' AND target_id IN (SELECT CAST(id AS TEXT) FROM reviews WHERE author_id = ? OR provider_id = ?))
         OR (target_type = 'support_ticket' AND target_id IN (SELECT CAST(id AS TEXT) FROM support_tickets WHERE user_id = ?))
         OR (target_type = 'offer' AND target_id IN (SELECT CAST(o.id AS TEXT) FROM offers o JOIN listings l ON l.id = o.listing_id WHERE o.provider_id = ? OR l.owner_id = ?))
         OR (target_type = 'teklif_talebi' AND target_id IN (SELECT CAST(id AS TEXT) FROM teklif_talepleri WHERE hizmet_alan_id = ? OR saglayici_id = ?)))`,
  ).all(String(id), id, id, id, id, id, id, id, id);
  for (const s of hedefler) {
    const once = jsonMaskele(jsonOku(s.before_json), maskele);
    const sonra = jsonMaskele(jsonOku(s.after_json), maskele);
    await db.prepare('UPDATE audit_log SET before_json = ?, after_json = ?, reason = ?, anonymized_at = ? WHERE id = ?').run(
      once == null ? null : JSON.stringify(once), sonra == null ? null : JSON.stringify(sonra), maskele(s.reason), z, s.id,
    );
  }
  const gecmis = await db.prepare('SELECT id, reason FROM user_status_history WHERE user_id = ? AND anonymized_at IS NULL').all(id);
  for (const g of gecmis) {
    await db.prepare('UPDATE user_status_history SET reason = ?, anonymized_at = ? WHERE id = ?').run(maskele(g.reason), z, g.id);
  }
  // Aynı gerekçeler içerik tablolarında da tutuluyor: hesabın kendi durum
  // gerekçesi ve kişinin ilan/yorumlarının kaldırma gerekçeleri.
  const u = await db.prepare('SELECT status_reason FROM users WHERE id = ?').get(id);
  if (u?.status_reason) await db.prepare('UPDATE users SET status_reason = ? WHERE id = ?').run(maskele(u.status_reason), id);
  for (const l of await db.prepare('SELECT id, removed_reason FROM listings WHERE owner_id = ? AND removed_reason IS NOT NULL').all(id)) {
    await db.prepare('UPDATE listings SET removed_reason = ? WHERE id = ?').run(maskele(l.removed_reason), l.id);
  }
  for (const y of await db.prepare(`SELECT id, removed_reason FROM reviews WHERE (author_id = ? OR provider_id = ?) AND removed_reason IS NOT NULL AND removed_reason <> 'ACCOUNT_DELETED'`).all(id, id)) {
    await db.prepare('UPDATE reviews SET removed_reason = ? WHERE id = ?').run(maskele(y.removed_reason), y.id);
  }
  return { denetim: hedefler.length, durumGecmisi: gecmis.length };
}
