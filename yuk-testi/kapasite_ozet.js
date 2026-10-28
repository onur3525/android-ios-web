// Kapasite ölçümü raporu: sonuc.json'dan kademe başına tablo + karar.
// Kullanım: node yuk-testi/kapasite_ozet.js sonuc.json <SURE_SN>
// Çıktı: Markdown tablo (stdout) ve GitHub notları (::notice).
import { readFileSync } from 'node:fs';

const [, , dosya = 'sonuc.json', sureHam = '120'] = process.argv;
const sure = Number(sureHam) || 120;
const m = JSON.parse(readFileSync(dosya, 'utf8')).metrics;
const kademeler = Object.keys(m)
  .map((k) => /^http_reqs\{kademe:(\d+)\}$/.exec(k)?.[1]).filter(Boolean).map(Number).sort((a, b) => a - b);

const satirlar = [];
let rahat = null; let ilkBasarisiz = null;
for (const h of kademeler) {
  const istek = m[`http_reqs{kademe:${h}}`]?.count ?? 0;
  const sure95 = m[`http_req_duration{kademe:${h}}`] ?? {};
  const hata = (m[`http_req_failed{kademe:${h}}`]?.value ?? 0) * 100;
  const dusen = m[`dropped_iterations{kademe:${h}}`]?.count ?? 0;
  const ulasilan = istek / sure;
  const yapildi = istek > 0;
  const ok = yapildi && hata < 1 && (sure95['p(95)'] ?? Infinity) < 500 && ulasilan >= h * 0.98;
  // Koşmamış kademe (ör. ölçüm erken durdu) karara KATILMAZ.
  if (yapildi && ok && ilkBasarisiz === null) rahat = h;
  if (yapildi && !ok && ilkBasarisiz === null) ilkBasarisiz = h;
  satirlar.push({ h, istek, ulasilan, hata, dusen, p50: sure95.med, p95: sure95['p(95)'], p99: sure95['p(99)'], max: sure95.max, ok, yapildi });
}

const f = (x) => (x === undefined ? '-' : Math.round(x));
console.log('| Hedef (istek/sn) | Ulaşılan | Hata | p50 | p95 | p99 | En uzun | Rahat mı |');
console.log('|---|---|---|---|---|---|---|---|');
for (const s of satirlar) {
  console.log(`| ${s.h} | ${s.yapildi ? s.ulasilan.toFixed(0) : 'koşmadı'} | ${s.hata.toFixed(2)}% | ${f(s.p50)} ms | ${f(s.p95)} ms | ${f(s.p99)} ms | ${f(s.max)} ms | ${!s.yapildi ? '—' : s.ok ? 'evet' : 'HAYIR'} |`);
  console.log(`::notice title=kademe ${s.h}::ulasilan=${s.yapildi ? s.ulasilan.toFixed(1) : 0}/sn hata=${s.hata.toFixed(2)}% p50=${f(s.p50)}ms p95=${f(s.p95)}ms p99=${f(s.p99)}ms max=${f(s.max)}ms dusen=${s.dusen} rahat=${s.ok ? 'evet' : 'hayir'}`);
}
const karar = !satirlar.some((s) => s.yapildi)
  ? 'Ölçüm yapılamadı (hiçbir kademe koşmadı).'
  : rahat === null
  ? 'En düşük kademe bile ölçütü karşılamadı.'
  : `Rahat karşılanan en yüksek hız: saniyede ${rahat} istek${ilkBasarisiz ? ` (ilk aşılan kademe: ${ilkBasarisiz})` : ' (bütün kademeler geçti)'}.`;
console.log(`\n**${karar}**  Ölçüt: hata < %1, p95 < 500 ms, hedef hızın ≥ %98'i.`);
console.log(`::notice title=Kapasite::${karar}`);
