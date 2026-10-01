// ═══════════════════════════════════════════════════════════════
// İLK YÖNETİCİ — yalnız sunucu üzerinde, komut satırından.
//
// Şifre KOMUT SATIRINDA verilmez (kabuk geçmişine düşer); ortam
// değişkeninden okunur. TOTP sırrı YALNIZ bir kez ekrana yazılır;
// doğrulayıcı uygulamaya (Google Authenticator vb.) eklenmelidir.
//
//   HC_DB_PATH=... HC_MASTER_KEY=... HC_ADMIN_PASSWORD=... \
//     node scripts/create_admin.js admin@ornek.com "Ad Soyad"
// ═══════════════════════════════════════════════════════════════
import { randomUUID } from 'node:crypto';
import { veritabaniAc, simdi } from '../src/db.js';
import { base32Uret, sifreKurali, sifreOzetle, sirSifrele } from '../src/auth.js';
import { denetimYaz } from '../src/audit.js';

const [email, ad] = process.argv.slice(2);
const sifre = process.env.HC_ADMIN_PASSWORD || '';
if (!process.env.HC_MASTER_KEY) {
  console.error('HC_MASTER_KEY zorunludur (TOTP sırrı bununla şifrelenir).');
  process.exit(1);
}
if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || !ad) {
  console.error('Kullanım: node scripts/create_admin.js <e-posta> "<ad>"');
  process.exit(1);
}
const kural = sifreKurali(sifre);
if (kural) {
  console.error(`HC_ADMIN_PASSWORD: ${kural}`);
  process.exit(1);
}
const { config } = await import('../src/config.js');
const db = await veritabaniAc(config.veritabani);
if (await db.prepare('SELECT 1 FROM admins WHERE email = ?').get(email.toLowerCase())) {
  console.error('Bu e-posta zaten kayıtlı.');
  process.exit(1);
}
const sir = base32Uret();
const id = randomUUID();
await db.prepare(`INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at)
            VALUES (?, ?, ?, 'super_admin', ?, ?, ?)`)
  .run(id, email.toLowerCase(), ad, sifreOzetle(sifre), sirSifrele(sir), simdi());
await denetimYaz(db, { adminId: null, islem: 'admin.bootstrap', hedefTur: 'admin', hedefId: id, sonra: { email: email.toLowerCase(), role: 'super_admin' } });
console.log('Süper yönetici oluşturuldu.');
console.log(`TOTP sırrı (YALNIZ BİR KEZ gösterilir): ${sir}`);
console.log(`otpauth://totp/HizmetCep%20Admin:${encodeURIComponent(email)}?secret=${sir}&issuer=HizmetCep%20Admin`);
await db.close();
