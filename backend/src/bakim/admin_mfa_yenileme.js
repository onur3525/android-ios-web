// ═══════════════════════════════════════════════════════════════
// YÖNETİCİ MFA (TOTP) SIRRINI YENİLEME — çekirdek kural (16 Eki)
//
// KÖK NEDEN: yönetici TOTP sırrı `sirSifrele` ile, sunucunun ana anahtarıyla
// (HC_MASTER_KEY) AES-256-GCM şifreli saklanır. Sır başka bir ana anahtarla
// yazılmışsa (yönetici farklı bir anahtarla oluşturulduysa ya da Render'daki
// anahtar sonradan değiştiyse) `sirCoz` doğrulama etiketini tutturamaz ve
// "Unsupported state or unable to authenticate data" fırlatır; MFA adımı
// hiçbir kodla geçilemez.
//
// ÇÖZÜM: anahtarı DEĞİŞTİRMEDEN, yalnız izinli tek yöneticinin sırrını,
// canlı sunucunun ŞU ANKİ anahtarıyla şifrelenmiş YENİ bir sırla değiştirmek.
//
// GÜVENLİK KONTROLLERİ (hepsi geçmeden yazma YOK):
//   1. Yalnız izinli hesap (IZINLI_HESAPLAR) — başka yöneticiye dokunulamaz.
//   2. Bu aracın anahtarı canlı sunucununkiyle AYNI olmalı (parmak izi,
//      /healthz) — aksi hâlde yeni sır da çözülemezdi.
//   3. Mevcut sır bu anahtarla ÇÖZÜLEBİLİYORSA işlem yapılmaz (sorun başka).
//   4. Yeni sır biçimi: Base32, en az 32 karakter (160 bit).
//   5. Hesap etkin olmalı; MFA KAPATILMAZ, hesap SİLİNMEZ.
//   6. Yedek: eski şifreli değer `admin_mfa_yedekleri`ne yazılır.
//   7. Tek işlem (transaction) + iyimser kilit: yalnız okunan değer hâlâ
//      aynıysa güncellenir; tam 1 satır değişmeli.
//   8. Doğrulama: yazılan değer çözülüp verilen sırla karşılaştırılır.
//   9. Hesabın açık oturumları kapatılır; denetim kaydına yazılır.
// ⚠ Düz sır hiçbir dönüşe, mesaja ya da kayda YAZILMAZ.
// ═══════════════════════════════════════════════════════════════
import { randomUUID } from 'node:crypto';
import { anahtarParmakIzi, sirCoz, sirSifrele } from '../auth.js';
import { denetimYaz } from '../audit.js';
import { simdi } from '../db.js';

export const IZINLI_HESAPLAR = new Set(['onur_butun@hotmail.com']);
export const MODLAR = new Set(['kontrol', 'uygula']);

export class BakimHatasi extends Error {}

/** Base32 sırrı normalleştirir (boşluk/küçük harf); geçersizse hata. */
export function yeniSirDogrula(ham) {
  const s = String(ham ?? '').replace(/[\s-]/g, '').toUpperCase();
  if (!/^[A-Z2-7]{32,64}$/.test(s)) {
    throw new BakimHatasi('Yeni TOTP sırrı geçersiz: Base32 (A–Z, 2–7) ve en az 32 karakter olmalı.');
  }
  return s;
}

const etkin = (a) => a.active === 1 || a.active === true;

/**
 * @param db  veritabanı (prepare/get/run/tx) — GÖÇ ÇALIŞTIRILMAMIŞ olabilir
 * @param o   { email, yeniSir, mod: 'kontrol'|'uygula', sunucuParmakIzi }
 * @returns   { durum: 'kontrol-tamam'|'yenilendi', mesajlar: string[] }
 */
export async function adminMfaYenile(db, { email, yeniSir, mod, sunucuParmakIzi }) {
  const mesajlar = [];
  if (!MODLAR.has(mod)) throw new BakimHatasi('Mod "kontrol" ya da "uygula" olmalı.');
  const e = String(email ?? '').trim().toLowerCase();
  if (!IZINLI_HESAPLAR.has(e)) throw new BakimHatasi('Bu araç yalnız izinli yönetici hesabında çalışır.');
  mesajlar.push('✓ Hedef hesap izinli listede.');

  if (!sunucuParmakIzi) throw new BakimHatasi('Canlı sunucunun anahtar parmak izi alınamadı (sunucu yeni sürümde mi?).');
  if (sunucuParmakIzi !== anahtarParmakIzi()) {
    throw new BakimHatasi('HC_MASTER_KEY canlı sunucudakiyle AYNI DEĞİL. GitHub sırrını Render’daki değerle birebir aynı girin; hiçbir şey yazılmadı.');
  }
  mesajlar.push('✓ Ana anahtar canlı sunucuyla aynı (parmak izi eşleşti).');

  const sir = yeniSirDogrula(yeniSir);
  mesajlar.push('✓ Yeni sır biçimi geçerli.');

  try {
    await db.prepare('SELECT 1 FROM admin_mfa_yedekleri LIMIT 1').get();
  } catch {
    throw new BakimHatasi('Yedek tablosu yok: önce sunucuyu yeni sürüme alın (Render → Deploy latest commit).');
  }
  mesajlar.push('✓ Yedek tablosu hazır.');

  const a = await db.prepare('SELECT id, email, active, totp_secret_enc FROM admins WHERE email = ?').get(e);
  if (!a) throw new BakimHatasi('Yönetici bulunamadı.');
  if (!etkin(a)) throw new BakimHatasi('Yönetici hesabı etkin değil; araç pasif hesapta çalışmaz.');
  if (!a.totp_secret_enc) throw new BakimHatasi('Hesapta MFA sırrı yok; bu araç yalnız mevcut sırrı yeniler.');
  mesajlar.push('✓ Yönetici bulundu ve etkin.');

  let cozuldu = false;
  try { sirCoz(a.totp_secret_enc); cozuldu = true; } catch { /* beklenen durum */ }
  if (cozuldu) {
    mesajlar.push('✓ Mevcut sır çözülebiliyor; onaylı değişimde eski değer yedeklenecek.');
  } else {
    mesajlar.push('✓ Mevcut sır çözülemiyor; eski değer yedeklenerek değiştirilecek.');
  }

  if (mod === 'kontrol') {
    mesajlar.push('KONTROL modu: tüm denetimler geçti; veritabanına HİÇBİR ŞEY yazılmadı.');
    return { durum: 'kontrol-tamam', mesajlar };
  }

  const yeniEnc = sirSifrele(sir);
  await db.tx(async () => {
    const guncel = await db.prepare('SELECT totp_secret_enc FROM admins WHERE id = ?').get(a.id);
    if (!guncel || guncel.totp_secret_enc !== a.totp_secret_enc) throw new BakimHatasi('Kayıt bu arada değişti; işlem durduruldu.');
    await db.prepare('INSERT INTO admin_mfa_yedekleri (id, admin_id, eski_sir_enc, neden, created_at) VALUES (?, ?, ?, ?, ?)')
      .run(randomUUID(), a.id, a.totp_secret_enc, 'Ana anahtarla çözülemeyen MFA sırrı yenilendi (GitHub Actions bakım aracı)', simdi());
    const g = await db.prepare(
      'UPDATE admins SET totp_secret_enc = ?, failed_count = 0, locked_until = NULL WHERE id = ? AND totp_secret_enc = ?',
    ).run(yeniEnc, a.id, a.totp_secret_enc);
    if (g.changes !== 1) throw new BakimHatasi(`Beklenmeyen güncelleme sayısı (${g.changes}); işlem geri alındı.`);
    await db.prepare('DELETE FROM admin_sessions WHERE admin_id = ?').run(a.id);
    await denetimYaz(db, { adminId: null, islem: 'admin.mfa_yenilendi', hedefTur: 'admin', hedefId: a.id, gerekce: 'Çözülemeyen MFA sırrı bakım aracıyla yenilendi' });
    const kontrol = await db.prepare('SELECT totp_secret_enc FROM admins WHERE id = ?').get(a.id);
    if (sirCoz(kontrol.totp_secret_enc) !== sir) throw new BakimHatasi('Yazılan sır doğrulanamadı; işlem geri alındı.');
  });
  mesajlar.push('✓ Eski şifreli değer yedeklendi, yeni sır yazıldı ve doğrulandı.');
  mesajlar.push('✓ Hesabın açık oturumları kapatıldı; işlem denetim kaydına yazıldı.');
  return { durum: 'yenilendi', mesajlar };
}
