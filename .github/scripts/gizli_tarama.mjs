// Depoda izlenen dosyalarda gizli bilgi taraması (15 Eki güvenlik denetimi).
// Eşleşen DEĞER yazılmaz; yalnız dosya, satır ve kural adı. Bulgu varsa çıkış 1.
// Firebase istemci API anahtarları (AIza…) tasarım gereği uygulamaya gömülüdür
// ve burada aranmaz; kısıtlaması Google Cloud Console'dan yapılır.
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const KURALLAR = [
  ['özel anahtar (PEM)', /-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----/],
  ['parolalı veritabanı adresi', /postgres(?:ql)?:\/\/[^\s:'"/]+:(?!hc_test_only@)[^\s@'"]{6,}@/],
  ['Render veritabanı ana makinesi', /dpg-[a-z0-9]{16,}-a(?:\.[a-z-]+)?\.render\.com/],
  ['AWS/R2 erişim anahtarı', /\bAKIA[0-9A-Z]{16}\b/],
  ['servis hesabı JSON', /"private_key_id"\s*:\s*"[0-9a-f]{20,}"/],
  ['GitHub jetonu', /\bgh[pousr]_[A-Za-z0-9]{36,}\b/],
  ['Slack jetonu', /\bxox[abprs]-[A-Za-z0-9-]{10,}\b/],
  ['atanmış JWT/ana anahtar', /\bHC_(?:JWT_SECRET|MASTER_KEY|S3_SECRET_ACCESS_KEY)\s*=\s*['"]?[A-Za-z0-9+/=_-]{20,}/],
];
const ATLA = /(^|\/)(node_modules|build|\.dart_tool)\/|\.(png|jpe?g|webp|heic|gif|ico|ttf|otf|woff2?|zip|jar|so|a)$/i;

const dosyalar = execFileSync('git', ['ls-files'], { encoding: 'utf8' }).split('\n').filter((d) => d && !ATLA.test(d));
let bulgu = 0;
for (const d of dosyalar) {
  let metin;
  try { metin = readFileSync(d, 'utf8'); } catch { continue; }
  if (metin.includes('\u0000')) continue; // ikili dosya
  metin.split('\n').forEach((satir, i) => {
    for (const [ad, re] of KURALLAR) {
      const m = re.exec(satir);
      // Belgelenmiş örnek/yer tutucu değerler (`<parola>`, AWS'nin resmi
      // `…EXAMPLE` anahtarı, testlere özel `…test…` değerleri) bulgu değildir.
      if (m && !/<|EXAMPLE|test/i.test(m[0])) {
        bulgu++;
        console.log(`::error file=${d},line=${i + 1}::Olası gizli bilgi: ${ad}`);
      }
    }
  });
}
console.log(bulgu ? `${bulgu} olası gizli bilgi bulundu.` : 'Gizli bilgi bulunmadı.');
process.exit(bulgu ? 1 : 0);
