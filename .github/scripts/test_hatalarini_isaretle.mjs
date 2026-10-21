// Node test çıktısındaki başarısız testleri GitHub iş açıklaması (annotation)
// olarak yazar (21 Eki). Neden: iş günlükleri her yerden indirilemiyor;
// yalnız "exit code 1" görünüyordu ve hangi testin düştüğü bilinmiyordu.
// Yalnız test adı ve hata mesajının ilk satırları yazılır (gizli bilgi yok:
// test veritabanı yalnız test amaçlıdır).
import { readFileSync } from 'node:fs';

const [dosya, etiket = 'test'] = process.argv.slice(2);
let metin = '';
try { metin = readFileSync(dosya, 'utf8'); } catch { process.exit(0); }
const satirlar = metin.split('\n');
let n = 0;
for (let i = 0; i < satirlar.length && n < 20; i++) {
  const m = /^\s*not ok \d+ - (.*)$/.exec(satirlar[i]);
  if (!m) continue;
  // Ardından gelen YAML bloğundan hata satırını bul.
  let hata = '';
  for (let j = i + 1; j < Math.min(i + 40, satirlar.length); j++) {
    const h = /^\s*error:\s*(.*)$/.exec(satirlar[j]);
    if (h) {
      hata = h[1];
      // Çok satırlı hata ("|-") ise sonraki birkaç satırı ekle.
      if (/^[|>]-?$/.test(hata.trim())) {
        hata = satirlar.slice(j + 1, j + 6).map((s) => s.trim()).filter(Boolean).join(' ');
      }
      break;
    }
    if (/^\s*(not )?ok \d+ /.test(satirlar[j])) break;
  }
  const temiz = (s) => s.replace(/%/g, '%25').replace(/\r/g, '').replace(/\n/g, ' ').slice(0, 900);
  console.log(`::error title=${temiz(`${etiket}: ${m[1]}`)}::${temiz(hata || 'ayrıntı yok')}`);
  n++;
}
