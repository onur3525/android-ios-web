// flutter test --machine çıktısındaki başarısız testleri GitHub uyarısı
// (annotation) olarak yazar. Günlük indirilemediğinde de hangi testin
// neden kaldığı Checks API'den okunabilsin diye. Testin sonucunu
// DEĞİŞTİRMEZ; yalnız raporlar.
import { readFileSync } from 'node:fs';

const testler = new Map();
const suitler = new Map();
const hatalar = new Map();
for (const satir of readFileSync(process.argv[2], 'utf8').split('\n')) {
  let o;
  try { o = JSON.parse(satir); } catch { continue; }
  if (o.type === 'suite') suitler.set(o.suite.id, o.suite.path ?? '');
  if (o.type === 'testStart') testler.set(o.test.id, { ad: o.test.name, suit: o.test.suiteID });
  if (o.type === 'error') hatalar.set(o.testID, `${hatalar.get(o.testID) ?? ''}${o.error}\n`);
  if (o.type === 'testDone' && o.result !== 'success' && !o.hidden) {
    const t = testler.get(o.testID);
    if (!hatalar.has(o.testID)) hatalar.set(o.testID, o.result);
    if (t) t.kaldi = true;
  }
}
const kod = (s) => s.replace(/%/g, '%25').replace(/\r/g, '%0D').replace(/\n/g, '%0A');
// Özellik değerlerinde (file, title) ':' ve ',' de kaçırılır.
const ozellik = (s) => kod(s).replace(/:/g, '%3A').replace(/,/g, '%2C');
let n = 0;
for (const [id, t] of testler) {
  if (!t.kaldi) continue;
  if (++n > 30) break;
  const yol = (suitler.get(t.suit) ?? '').replace(/^.*?(test\/)/, '$1');
  const mesaj = String(hatalar.get(id) ?? '').slice(0, 900);
  console.log(`::error file=${ozellik(yol)},title=${ozellik(t.ad.slice(0, 200))}::${kod(mesaj)}`);
}
// Yüklenemeyen test dosyaları (derleme hatası) testStart üretmeden hata verir.
for (const [id, m] of hatalar) {
  if (!testler.has(id) && n++ < 30) console.log(`::error title=Test yüklenemedi::${kod(String(m).slice(0, 900))}`);
}
console.log(`Başarısız test sayısı: ${[...testler.values()].filter((t) => t.kaldi).length}`);
