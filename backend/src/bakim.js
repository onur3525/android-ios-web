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
