// ═══════════════════════════════════════════════════════════════
// YÖNETİCİ İKİ AŞAMALI DOĞRULAMA (TOTP) SIFIRLAMA — yalnız sunucuda.
//
// Ne zaman: yönetim girişinde "Doğrulama anahtarı sunucuda çözülemedi"
// hatası (sunucu ana anahtarı HC_MASTER_KEY, yönetici oluşturulduğundaki
// anahtardan farklı) ya da doğrulayıcı uygulama kaybolduğunda.
//
// Ne yapar: yalnız verilen e-postadaki yöneticinin TOTP sırrını, sunucunun
// ŞU ANKİ ana anahtarıyla şifrelenmiş YENİ bir sırla değiştirir, açık
// oturumlarını kapatır, başarısız giriş sayacını/kilidini sıfırlar ve
// denetim kaydına yazar. Şifreye ve başka hiçbir kayda dokunmaz.
// Yeni sır YALNIZ BİR KEZ ekrana yazılır; doğrulayıcı uygulamaya eklenir.
//
//   node scripts/admin_mfa_sifirla.js admin@ornek.com
// (Render → hizmetcep-backend → Shell; ortam değişkenleri zaten tanımlı.)
// ═══════════════════════════════════════════════════════════════
import { veritabaniAc } from '../src/db.js';
import { base32Uret, sirSifrele } from '../src/auth.js';
import { denetimYaz } from '../src/audit.js';

const [email] = process.argv.slice(2);
if (!process.env.HC_MASTER_KEY) {
  console.error('HC_MASTER_KEY zorunludur (TOTP sırrı bununla şifrelenir).');
  process.exit(1);
}
if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
  console.error('Kullanım: node scripts/admin_mfa_sifirla.js <e-posta>');
  process.exit(1);
}
const { config } = await import('../src/config.js');
const db = await veritabaniAc(config.veritabani);
const a = await db.prepare('SELECT id, email FROM admins WHERE email = ?').get(email.toLowerCase());
if (!a) {
  console.error('Bu e-postayla yönetici bulunamadı.');
  await db.close();
  process.exit(1);
}
const sir = base32Uret();
await db.prepare('UPDATE admins SET totp_secret_enc = ?, failed_count = 0, locked_until = NULL WHERE id = ?').run(sirSifrele(sir), a.id);
await db.prepare('DELETE FROM admin_sessions WHERE admin_id = ?').run(a.id);
await denetimYaz(db, { adminId: null, islem: 'admin.mfa_reset', hedefTur: 'admin', hedefId: a.id });
console.log('İki aşamalı doğrulama sıfırlandı; açık oturumlar kapatıldı.');
console.log(`Yeni TOTP sırrı (YALNIZ BİR KEZ gösterilir): ${sir}`);
console.log(`otpauth://totp/HizmetCep%20Admin:${encodeURIComponent(a.email)}?secret=${sir}&issuer=HizmetCep%20Admin`);
await db.close();
