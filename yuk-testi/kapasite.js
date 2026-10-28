// ═══════════════════════════════════════════════════════════════
// HİZMETCEP KAPASİTE ÖLÇÜMÜ (28 Eki 2026) — k6
//
// Amaç: sunucunun saniyede KAÇ isteği "rahat" karşıladığını bulmak.
// Kademeli testten farkı: her hız AYRI ölçülür (sonuçlar karışmaz).
//
// • YALNIZ OKUMA: kademeli.js ile AYNI uçlar ve AYNI oranlar.
// • Her kademe sabit hızda SURE (varsayılan 2 dk) koşar; aralarda ARA
//   (varsayılan 20 sn) boşluk vardır (önceki kademenin kuyruğu boşalsın).
// • "Rahat karşılıyor" ölçütü (her kademe için): hata < %1, p95 < 500 ms
//   ve hedef hızın en az %98'ine ulaşıldı (k6 isteği bekletmek zorunda
//   kalmadı). Rapor kapasite_ozet.js ile çıkarılır.
// • GÜVENLİK FRENİ: hata oranı %5'i aşarsa ölçüm durur.
// ═══════════════════════════════════════════════════════════════
import http from 'k6/http';
import { check } from 'k6';

const TABAN = (__ENV.TABAN_URL || 'https://hizmetcep-backend.onrender.com').replace(/\/+$/, '');
const SEVIYELER = String(__ENV.SEVIYELER || '250,300,350,400,450,500')
  .split(',').map((s) => Number(s.trim())).filter((n) => n >= 10 && n <= 1000);
const SURE_SN = Math.max(10, Number(__ENV.SURE_SN || 120));
const ARA_SN = Math.max(0, Number(__ENV.ARA_SN || 20));

const scenarios = {};
const thresholds = {
  http_req_failed: [{ threshold: 'rate<0.05', abortOnFail: true, delayAbortEval: '30s' }],
};
SEVIYELER.forEach((hiz, i) => {
  scenarios[`k${hiz}`] = {
    executor: 'constant-arrival-rate',
    rate: hiz,
    timeUnit: '1s',
    duration: `${SURE_SN}s`,
    startTime: `${i * (SURE_SN + ARA_SN)}s`,
    preAllocatedVUs: Math.min(1500, hiz * 2),
    maxVUs: 2000,
    tags: { kademe: String(hiz) },
  };
  // Eşikler yalnız kademe başına alt ölçüleri ÖZETE almak içindir (durdurmaz).
  thresholds[`http_req_duration{kademe:${hiz}}`] = ['p(95)>=0'];
  thresholds[`http_req_failed{kademe:${hiz}}`] = ['rate>=0'];
  thresholds[`http_reqs{kademe:${hiz}}`] = ['count>=0'];
  thresholds[`dropped_iterations{kademe:${hiz}}`] = ['count>=0'];
});

export const options = {
  scenarios,
  thresholds,
  summaryTrendStats: ['avg', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
  userAgent: 'HizmetCep-KapasiteOlcumu/1.0',
};

const UCLAR = [
  { ad: 'katalog', yol: '/api/v1/categories', oran: 35 },
  { ad: 'ayar', yol: '/api/v1/config/app?platform=android', oran: 25 },
  { ad: 'bolgeler', yol: '/api/v1/regions/tree', oran: 20 },
  { ad: 'yasal', yol: '/api/v1/legal', oran: 15 },
  { ad: 'saglik', yol: '/healthz', oran: 5 },
];
const TOPLAM = UCLAR.reduce((t, u) => t + u.oran, 0);

export function setup() {
  const r = http.get(`${TABAN}/healthz`, { timeout: '60s' });
  if (r.status !== 200) throw new Error(`Sunucu hazır değil (healthz ${r.status}); ölçüm başlatılmadı.`);
  return { seviyeler: SEVIYELER, sureSn: SURE_SN };
}

export default function () {
  let r = Math.random() * TOPLAM; let u = UCLAR[0];
  for (const x of UCLAR) { if ((r -= x.oran) < 0) { u = x; break; } }
  const y = http.get(`${TABAN}${u.yol}`, { tags: { uc: u.ad }, timeout: '10s' });
  check(y, { '200 döndü': (x) => x.status === 200 });
}
