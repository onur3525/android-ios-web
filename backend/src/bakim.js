// ═══════════════════════════════════════════════════════════════
// KAYIT BAKIMI — yalnız süresi geçmiş TEKNİK kayıtlar silinir
//
// Bu tablolar her istek/girişte büyür ve hiç temizlenmiyordu:
//   · rate_limits    — her IP/kullanıcı anahtarı için bir satır
//   · otp_codes      — her kod isteği için bir satır
//   · user_sessions  — her giriş/yenileme için bir satır
//   · admin_sessions — her admin girişi için bir satır
// Milyonlarca kullanıcıda tablo ve dizin şişmesi sorgu süresini uzatır.
//
// SİLİNMEYENLER (davranış korunur):
//   · içinde bulunulan hız penceresi (sayım bozulmaz)
//   · son 24 saatin OTP kayıtları (saatlik kota ve 60 sn kuralı bunları okur)
//   · süresi dolmamış oturumlar — İPTAL EDİLMİŞ olsalar bile: yenileme
//     token'ının tekrar kullanımını (ROTATED) yakalamak için gerekirler
//   · iş verisi (ilan, teklif, mesaj, bildirim, denetim kaydı) — dokunulmaz
// ═══════════════════════════════════════════════════════════════
import { hizKayitlariniTemizle } from './http.js';

const GUN = 24 * 60 * 60 * 1000;
const once = (ms) => new Date(Date.now() - ms).toISOString();

export async function kayitBakimi(db) {
  const hiz = await hizKayitlariniTemizle(db);
  const otp = (await db.prepare('DELETE FROM otp_codes WHERE created_at < ?').run(once(GUN))).changes ?? 0;
  const oturum = (await db.prepare('DELETE FROM user_sessions WHERE expires_at < ?').run(once(30 * GUN))).changes ?? 0;
  const admin = (await db.prepare('DELETE FROM admin_sessions WHERE created_at < ?').run(once(2 * GUN))).changes ?? 0;
  return { hiz, otp, oturum, admin };
}

// ═══════════════════════════════════════════════════════════════
// SAKLAMA SÜRESİ BAKIMI (23 Eki) — Gizlilik Politikası madde 8'de yazan
// süreler UYGULANIR (metin ile davranış aynı olsun):
//   · SMS / e-posta gönderim kayıtları: 2 yıl
//   · üye olmayan kişilerin destek e-postaları: talep kapandıktan
//     (yanıtlandıktan) itibaren 2 yıl — yanıtlarıyla birlikte
// Üyelerin içerikleri hesap silinince silinir (hesap silme akışı); sözleşme
// onayları ve yönetici kayıtları 10 yıl saklanır (ayrı iş, süresi dolmadı).
// ═══════════════════════════════════════════════════════════════
export const IKI_YIL = 730 * GUN;
export async function saklamaSuresiBakimi(db) {
  const sinir = once(IKI_YIL);
  const gonderim = (await db.prepare('DELETE FROM outbound_messages WHERE created_at < ?').run(sinir)).changes ?? 0;
  const eski = `SELECT id FROM support_tickets WHERE user_id IS NULL AND status <> 'OPEN' AND COALESCE(closed_at, updated_at) < ?`;
  let talep = 0;
  await db.tx(async () => {
    await db.prepare(`DELETE FROM support_ticket_replies WHERE ticket_id IN (${eski})`).run(sinir);
    talep = (await db.prepare(`DELETE FROM support_tickets WHERE id IN (${eski})`).run(sinir)).changes ?? 0;
  });
  return { gonderim, talep };
}
