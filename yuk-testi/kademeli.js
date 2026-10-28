// ═══════════════════════════════════════════════════════════════
// HİZMETCEP KADEMELİ YÜK TESTİ (28 Eki 2026) — k6
//
// • YALNIZ OKUMA: giriş istemeyen herkese açık GET uçları. Veritabanına
//   hiçbir kayıt yazılmaz, kimse bildirim/e-posta almaz.
// • Kademeler (saniyedeki istek): 50 → 100 → 250 → 500, her kademe
//   1 dk tırmanış + 2 dk sabit yük.
// • GÜVENLİK FRENİ: hata oranı %1'i ya da p95 gecikme 500 ms'yi aşarsa
//   test kendiliğinden durur (sunucu gereksiz yere zorlanmaz).
// • Hedef üst sınır HEDEF_RPS ile düşürülebilir (ör. önce 100).
// ═══════════════════════════════════════════════════════════════
import http from 'k6/http';
import { check } from 'k6';

const TABAN = (__ENV.TABAN_URL || 'https://hizmetcep-backend.onrender.com').replace(/\/+$/, '');
const HEDEF = Math.max(10, Math.min(500, Number(__ENV.HEDEF_RPS || 500)));

const kademeler = [50, 100, 250, 500].filter((k) => k <= HEDEF);
if (kademeler[kademeler.length - 1] !== HEDEF) kademeler.push(HEDEF);
const stages = [];
for (const k of kademeler) {
  stages.push({ target: k, duration: '1m' }); // tırmanış
  stages.push({ target: k, duration: '2m' }); // sabit yük
}
stages.push({ target: 0, duration: '30s' });

export const options = {
  scenarios: {
    kademeli: {
      executor: 'ramping-arrival-rate',
      startRate: 10,
      timeUnit: '1s',
      preAllocatedVUs: 200,
      maxVUs: 1500,
      stages,
    },
  },
  thresholds: {
    http_req_failed: [{ threshold: 'rate<0.01', abortOnFail: true, delayAbortEval: '20s' }],
    http_req_duration: [{ threshold: 'p(95)<500', abortOnFail: true, delayAbortEval: '30s' }],
    'http_req_duration{uc:katalog}': ['p(95)<500'],
    'http_req_duration{uc:bolgeler}': ['p(95)<500'],
    'http_req_duration{uc:yasal}': ['p(95)<500'],
    'http_req_duration{uc:ayar}': ['p(95)<500'],
    'http_req_duration{uc:saglik}': ['p(95)<500'],
  },
  summaryTrendStats: ['avg', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
  userAgent: 'HizmetCep-YukTesti/1.0',
};

// Gerçek kullanımı andıran karışım (uygulama açılışı + gezinme).
const UCLAR = [
  { ad: 'katalog', yol: '/api/v1/categories', oran: 35 },
  { ad: 'ayar', yol: '/api/v1/config/app?platform=android', oran: 25 },
  { ad: 'bolgeler', yol: '/api/v1/regions/tree', oran: 20 },
  { ad: 'yasal', yol: '/api/v1/legal', oran: 15 },
  { ad: 'saglik', yol: '/healthz', oran: 5 },
];
const TOPLAM = UCLAR.reduce((t, u) => t + u.oran, 0);

function sec() {
  let r = Math.random() * TOPLAM;
  for (const u of UCLAR) { if ((r -= u.oran) < 0) return u; }
  return UCLAR[0];
}

export function setup() {
  const r = http.get(`${TABAN}/healthz`, { timeout: '60s' });
  if (r.status !== 200) throw new Error(`Sunucu hazır değil (healthz ${r.status}); test başlatılmadı.`);
}

export default function () {
  const u = sec();
  const r = http.get(`${TABAN}${u.yol}`, { tags: { uc: u.ad }, timeout: '10s' });
  check(r, { '200 döndü': (x) => x.status === 200 }, { uc: u.ad });
}
