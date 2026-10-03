// ═══════════════════════════════════════════════════════════════
// ÖZET EKRANI — yalnız MEVCUT admin API'leri (sahte/demo veri YOK)
//
// Kaynaklar: /stats · /users · /listings · /offers · /teklif-talepleri
// · /account-requests · /integrations. Her bölüm bağımsız yüklenir;
// yetkisi olmayan rol (403) o bölümde "yetki yok" görür, ekran çökmez.
//
// GÜNLÜK SAYILAR VE GRAFİKLER yalnız listeler 7 günlük pencereyi
// TAMAMEN kapsıyorsa çizilir (en eski kayıt pencereden eskiyse ya da
// listenin tamamı alındıysa). Kapsam eksikse sayı UYDURULMAZ; "veri
// yetersiz" gösterilir. CSP: satır içi stil yok; grafik SVG öznitelikli.
// ═══════════════════════════════════════════════════════════════
import { api, h, rozet } from './cekirdek.js';

const GUN = 86_400_000;
const RENK = { mavi: '#2563EB', yesil: '#22C55E', mor: '#8B5CF6', turuncu: '#F97316', kirmizi: '#EF4444', gri: '#94A3B8' };
const SVG = 'http://www.w3.org/2000/svg';

function svg(etiket, nit = {}, ...cocuk) {
  const e = document.createElementNS(SVG, etiket);
  for (const [k, v] of Object.entries(nit)) e.setAttribute(k, String(v));
  for (const c of cocuk) if (c) e.append(c);
  return e;
}

/** Basit ikon kümesi (çizgi; currentColor). */
const IKON = {
  kisi: 'M16 19v-1a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v1M10 10a3 3 0 1 0 0-6 3 3 0 0 0 0 6M20 19v-1a3 3 0 0 0-2-2.8M15 4.2a3 3 0 0 1 0 5.6',
  ilan: 'M7 3h10a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1M9 8h6M9 12h6M9 16h4',
  teklif: 'M6 3h9l3 3v15H6zM9 11h6M9 15h6',
  talep: 'M4 5h16v10H8l-4 4zM8 9h8M8 12h5',
  askida: 'M9 6v12M15 6v12',
  ban: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18M6 6l12 12',
  tik: 'M5 12l4 4 10-10',
  silme: 'M5 7h14M10 11v6M14 11v6M7 7l1 13h8l1-13M9 7V4h6v3',
  zil: 'M6 16V11a6 6 0 1 1 12 0v5l2 2H4zM10 20a2 2 0 0 0 4 0',
  sunucu: 'M4 5h16v6H4zM4 13h16v6H4zM8 8h.01M8 16h.01',
  db: 'M12 3c4.4 0 8 1.3 8 3s-3.6 3-8 3-8-1.3-8-3 3.6-3 8-3M4 6v12c0 1.7 3.6 3 8 3s8-1.3 8-3V6M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3',
  sms: 'M4 5h16v11H8l-4 4zM8 10h.01M12 10h.01M16 10h.01',
  posta: 'M3 6h18v12H3zM3 7l9 6 9-6',
  depo: 'M4 7l8-4 8 4-8 4zM4 7v10l8 4 8-4V7M12 11v10',
  takvim: 'M4 5h16v15H4zM4 9h16M8 3v4M16 3v4',
};
function ikon(ad, boyut = 20) {
  return svg('svg', { viewBox: '0 0 24 24', width: boyut, height: boyut, fill: 'none', stroke: 'currentColor', 'stroke-width': 1.8, 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'aria-hidden': 'true' },
    svg('path', { d: IKON[ad] }));
}

const kisaTarih = (v) => (v ? new Date(v).toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '—');
const sayi = (v) => (Number.isFinite(v) ? v.toLocaleString('tr-TR') : '—');
const gunBasi = (t) => { const d = new Date(t); d.setHours(0, 0, 0, 0); return d.getTime(); };

/** Liste 7 günlük pencereyi tamamen kapsıyor mu? (kayıtlar yeniden eskiye) */
function kapsar(liste, toplam, alan = 'createdAt') {
  if (!liste) return false;
  if (toplam !== undefined && liste.length >= toplam) return true;
  const son = liste[liste.length - 1];
  return !!son && Date.parse(son[alan]) < gunBasi(Date.now()) - 7 * GUN;
}

/** Son 8 günün (bugün dahil) günlük sayıları. */
function gunluk(liste, alan = 'createdAt') {
  const bugun = gunBasi(Date.now());
  const sayac = Array(8).fill(0);
  for (const x of liste) {
    const i = Math.floor((bugun - gunBasi(Date.parse(x[alan]))) / GUN);
    if (i >= 0 && i < 8) sayac[7 - i]++;
  }
  return sayac;
}

function gunEtiketleri() {
  const b = gunBasi(Date.now());
  return Array.from({ length: 8 }, (_, i) => new Date(b - (7 - i) * GUN).toLocaleDateString('tr-TR', { day: 'numeric', month: 'short' }));
}

/** Kart başlığı + "Tümünü gör" bağlantısı. */
function bolum(baslik, hedef, ...icerik) {
  return h('section', { class: 'oz-kart' },
    h('div', { class: 'oz-kart-ust' }, h('h3', {}, baslik),
      hedef ? h('a', { class: 'oz-tumu', href: `#/${hedef}` }, 'Tümünü gör ›') : null),
    ...icerik);
}

function yuklenemedi(e) {
  return h('p', { class: 'oz-bos' }, e?.durum === 403 ? 'Bu bölüm için yetkiniz yok.' : 'Veri alınamadı.');
}

/** Bugün kartı: bugünkü sayı + düne göre değişim (yalnız kapsam tamsa). */
function bugunKarti(ad, ikonAd, renk, veri) {
  const [bugun, dun] = veri ?? [null, null];
  let fark = null;
  if (bugun !== null && dun !== null) {
    if (dun === 0) fark = null; // sıfıra göre yüzde anlamsız; yalnız "Düne göre" gösterilir
    else fark = `${bugun >= dun ? '↑' : '↓'} %${Math.abs(Math.round(((bugun - dun) / dun) * 100))}`;
  }
  return h('div', { class: 'oz-bugun' },
    h('span', { class: `oz-yuvarlak ${renk}` }, ikon(ikonAd, 22)),
    h('div', {},
      h('div', { class: 'oz-etiket' }, ad),
      h('div', { class: 'oz-buyuk' }, bugun === null ? '—' : sayi(bugun)),
      bugun === null
        ? h('div', { class: 'oz-alt' }, 'Veri yetersiz')
        : [fark ? h('div', { class: `oz-fark ${bugun >= dun ? 'artis' : 'azalis'}` }, fark) : null,
          h('div', { class: 'oz-alt' }, `Düne göre: ${sayi(dun)}`)]));
}

function miniKart(ad, deger, ikonAd, renk) {
  return h('div', { class: 'oz-mini' },
    h('span', { class: `oz-yuvarlak kucuk ${renk}` }, ikon(ikonAd, 18)),
    h('div', {}, h('div', { class: 'oz-etiket' }, ad), h('div', { class: 'oz-orta' }, sayi(deger))));
}

/** Çizgi grafik (SVG). seriler: [{ad, renk, degerler[8]}] */
function grafik(seriler) {
  const G = 320, Y = 150, sol = 28, alt = 22, ust = 8;
  const enCok = Math.max(1, ...seriler.flatMap((s) => s.degerler));
  const adim = Math.max(1, Math.ceil(enCok / 4));
  const tavan = adim * 4;
  const x = (i) => sol + 6 + (i * (G - sol - 26)) / 7;
  const y = (v) => ust + (Y - ust - alt) * (1 - v / tavan);
  const k = svg('svg', { viewBox: `0 0 ${G} ${Y}`, class: 'oz-grafik', role: 'img', 'aria-label': 'Son 7 gün grafiği' });
  for (let i = 0; i <= 4; i++) {
    const v = i * adim;
    k.append(svg('line', { x1: sol, x2: G - 4, y1: y(v), y2: y(v), stroke: '#EEF1F6', 'stroke-width': 1 }));
    const t = svg('text', { x: sol - 6, y: y(v) + 3, 'text-anchor': 'end', 'font-size': 9, fill: '#94A3B8' });
    t.textContent = String(v);
    k.append(t);
  }
  gunEtiketleri().forEach((e, i) => {
    const t = svg('text', { x: x(i), y: Y - 6, 'text-anchor': 'middle', 'font-size': 9, fill: '#94A3B8' });
    t.textContent = e;
    k.append(t);
  });
  for (const s of seriler) {
    const nokta = s.degerler.map((v, i) => `${x(i)},${y(v)}`).join(' ');
    if (seriler.length === 1) {
      k.append(svg('polygon', { points: `${x(0)},${y(0)} ${nokta} ${x(7)},${y(0)}`, fill: s.renk, 'fill-opacity': 0.08 }));
    }
    k.append(svg('polyline', { points: nokta, fill: 'none', stroke: s.renk, 'stroke-width': 2 }));
    s.degerler.forEach((v, i) => k.append(svg('circle', { cx: x(i), cy: y(v), r: 3, fill: s.renk })));
  }
  return k;
}

function grafikKarti(baslik, seriler, kapsamTam) {
  return h('section', { class: 'oz-kart' },
    h('div', { class: 'oz-kart-ust' }, h('h3', {}, baslik), h('span', { class: 'oz-secim' }, 'Son 7 gün')),
    seriler.length > 1 ? h('div', { class: 'oz-lejant' }, seriler.map((s) => h('span', {}, h('i', { class: `oz-nokta ${s.sinif}` }), s.ad))) : null,
    kapsamTam ? grafik(seriler) : h('p', { class: 'oz-bos' }, 'Grafik için yeterli kayıt alınamadı.'));
}

function tablo(kolonlar, satirlar, tikla, ekSinif = '') {
  if (!satirlar?.length) return h('p', { class: 'oz-bos' }, 'Kayıt yok.');
  return h('div', { class: 'oz-tablo-sar' }, h('table', { class: `oz-tablo ${ekSinif}`.trim() },
    h('thead', {}, h('tr', {}, kolonlar.map((k) => h('th', {}, k[0])))),
    h('tbody', {}, satirlar.map((s, i) => h('tr', { class: tikla ? 'tikla' : '', onclick: tikla ? () => tikla(s) : null },
      kolonlar.map((k) => h('td', {}, k[1](s, i))))))));
}

const ROL_ADI = { CUSTOMER: 'Hizmet Alan', PROVIDER: 'Hizmet Veren' };
const ENTEGRASYON = { SMS: 'SMS', EMAIL: 'E-posta', STORAGE: 'Depolama' };

export async function ozetSayfasi() {
  // Bütün kaynaklar paralel; her biri ayrı ayrı başarısız olabilir.
  const al = (yol) => api(yol).then((v) => ({ v }), (e) => ({ e }));
  const [st, ku, il, te, ta, gt, en] = await Promise.all([
    al('/stats'), al('/users?limit=200'), al('/listings?limit=200'), al('/offers'),
    al('/teklif-talepleri'), al('/account-requests'), al('/integrations'),
  ]);
  if (st.e) throw st.e; // özet sayıları alınamıyorsa ekranın anlamı yok

  const s = st.v;
  const kullanicilar = ku.v?.items;
  const ilanlar = il.v?.items;
  const teklifler = te.v;
  const talepler = ta.v;
  const gelen = gt.v;

  const kapsam = {
    kullanici: kapsar(kullanicilar, ku.v?.total),
    ilan: kapsar(ilanlar, il.v?.total),
    teklif: kapsar(teklifler, teklifler && teklifler.length < 200 ? teklifler.length : undefined),
    talep: kapsar(talepler, talepler && talepler.length < 200 ? talepler.length : undefined),
    gelen: kapsar(gelen, gelen && gelen.length < 500 ? gelen.length : undefined),
  };
  const gunler = {
    kullanici: kapsam.kullanici ? gunluk(kullanicilar) : null,
    ilan: kapsam.ilan ? gunluk(ilanlar) : null,
    teklif: kapsam.teklif ? gunluk(teklifler) : null,
    talep: kapsam.talep ? gunluk(talepler) : null,
    gelen: kapsam.gelen ? gunluk(gelen) : null,
  };
  const bd = (g) => (g ? [g[7], g[6]] : null);

  const bas = new Date(gunBasi(Date.now()) - 7 * GUN).toLocaleDateString('tr-TR', { day: 'numeric', month: 'short', year: 'numeric' });
  const son = new Date().toLocaleDateString('tr-TR', { day: 'numeric', month: 'short', year: 'numeric' });

  // ── Kullanıcı dağılımı (yalnız liste tamsa) ──
  const tamListe = kullanicilar && ku.v.total <= kullanicilar.length;
  const rolSay = (r) => (tamListe ? kullanicilar.filter((u) => u.roles.includes(r)).length : null);
  const son7 = gunler.kullanici ? gunler.kullanici.slice(1).reduce((a, b) => a + b, 0) : null;

  // ── Sistem durumu (yalnız backend'den bilinenler) ──
  const durumSatiri = (ad, ikonAd, durum, sinif) => h('li', {}, h('span', { class: 'oz-durum-ad' }, ikon(ikonAd, 18), ad),
    h('span', { class: `oz-durum ${sinif}` }, durum));
  const sistem = [
    durumSatiri('Backend API', 'sunucu', 'Çalışıyor', 'iyi'),
    durumSatiri('Veritabanı', 'db', 'Çalışıyor', 'iyi'),
    ...(en.e
      ? []
      : ['SMS', 'EMAIL', 'STORAGE'].map((t) => {
        const x = en.v.find((i) => i.type === t && i.active);
        const ikonAd = { SMS: 'sms', EMAIL: 'posta', STORAGE: 'depo' }[t];
        if (!x) return durumSatiri(ENTEGRASYON[t], ikonAd, 'Panelde tanımlı değil', 'notr');
        if (x.lastTestOk === false) return durumSatiri(ENTEGRASYON[t], ikonAd, 'Son test başarısız', 'kotu');
        return durumSatiri(ENTEGRASYON[t], ikonAd, x.lastTestOk ? 'Etkin · test başarılı' : 'Etkin', 'iyi');
      })),
    durumSatiri('Bildirim gönderimi (7 gün)', 'zil',
      s.failedNotifications ? `${sayi(s.failedNotifications)} başarısız` : 'Sorun yok', s.failedNotifications ? 'kotu' : 'iyi'),
  ];

  return h('div', { class: 'oz' },
    h('div', { class: 'oz-baslik' },
      h('div', {}, h('h2', {}, 'Özet'), h('p', {}, 'Uygulamanın genel durumu ve son istatistikler')),
      h('div', { class: 'oz-tarih' }, ikon('takvim', 18), `${bas} - ${son}`)),

    h('section', { class: 'oz-kart oz-bugun-sar' },
      h('h3', {}, 'Bugün'),
      h('div', { class: 'oz-bugun-izgara' },
        bugunKarti('Yeni kullanıcı', 'kisi', 'mavi', bd(gunler.kullanici)),
        bugunKarti('Yeni ilan', 'ilan', 'yesil', bd(gunler.ilan)),
        bugunKarti('Yeni teklif', 'teklif', 'mor', bd(gunler.teklif)),
        bugunKarti('Yeni teklif talebi', 'talep', 'turuncu', bd(gunler.talep)),
        bugunKarti('Gelen talep', 'silme', 'kirmizi', bd(gunler.gelen)))),

    h('div', { class: 'oz-uclu' },
      bolum('Kullanıcılar', 'kullanicilar',
        h('div', { class: 'oz-mini-izgara uc' },
          miniKart('Toplam kullanıcı', s.users, 'kisi', 'mavi'),
          miniKart('Hizmet Alan', rolSay('CUSTOMER'), 'kisi', 'acikmavi'),
          miniKart('Hizmet Veren', rolSay('PROVIDER'), 'kisi', 'mor'),
          miniKart('Aktif', s.users - s.suspended - s.banned, 'tik', 'yesil'),
          miniKart('Askıda', s.suspended, 'askida', 'turuncu'),
          miniKart('Banlı', s.banned, 'ban', 'kirmizi')),
        h('div', { class: 'oz-mini-izgara iki' },
          miniKart('Son 7 gün · yeni kullanıcı', son7, 'kisi', 'acikmavi'),
          miniKart('Bekleyen hesap silme', s.pendingDeletions, 'silme', 'kirmizi'))),
      bolum('İlan ve Teklifler', 'ilanlar',
        h('div', { class: 'oz-mini-izgara uc' },
          miniKart('Açık ilan', s.activeListings, 'ilan', 'mavi'),
          miniKart('Son 24 saatte teklif', s.offersToday, 'teklif', 'mor'),
          miniKart('Süren teklif talebi', s.openTalepler, 'talep', 'turuncu'))),
      bolum('Sistem Durumu', 'entegrasyonlar', h('ul', { class: 'oz-durum-liste' }, sistem),
        en.e ? h('p', { class: 'oz-bos' }, 'Entegrasyon durumu için yetkiniz yok.') : null)),

    h('div', { class: 'oz-uclu' },
      grafikKarti('Yeni Kullanıcılar', [{ ad: 'Yeni kullanıcı', renk: RENK.mavi, sinif: 'mavi', degerler: gunler.kullanici ?? [] }], kapsam.kullanici),
      grafikKarti('Yeni İlanlar', [{ ad: 'Yeni ilan', renk: RENK.yesil, sinif: 'yesil', degerler: gunler.ilan ?? [] }], kapsam.ilan),
      grafikKarti('Teklifler', [{ ad: 'Yeni teklif', renk: RENK.mor, sinif: 'mor', degerler: gunler.teklif ?? [] }], kapsam.teklif)),

    h('div', { class: 'oz-uclu' },
      bolum('Son Kayıt Olan Kullanıcılar', 'kullanicilar', ku.e ? yuklenemedi(ku.e) : tablo([
        ['#', (_, i) => i + 1],
        ['Ad Soyad', (u) => u.name],
        ['Telefon', (u) => u.phone],
        ['Rol', (u) => u.roles.map((r) => h('span', { class: `oz-rol ${r}` }, ROL_ADI[r] ?? r))],
        ['Kayıt', (u) => kisaTarih(u.createdAt)],
      ], kullanicilar.slice(0, 5), (u) => (location.hash = `#/kullanici/${u.id}`), 'oz-sigdir')),
      bolum('Son İlanlar', 'ilanlar', il.e ? yuklenemedi(il.e) : tablo([
        ['Başlık', (l) => l.title],
        ['İlçe', (l) => String(l.location ?? '').split(',')[0]],
        ['Durum', (l) => rozet(l.status)],
        ['Tarih', (l) => kisaTarih(l.createdAt)],
      ], ilanlar.slice(0, 5), (l) => (location.hash = `#/ilan/${l.id}`))),
      bolum('Gelen Talepler', 'hesaptalepleri', gt.e ? yuklenemedi(gt.e) : tablo([
        ['Konu', (a) => (a.type === 'FREEZE' ? 'Hesap dondurma' : 'Hesap silme')],
        ['Gönderen', (a) => a.name],
        ['Tarih', (a) => kisaTarih(a.createdAt)],
        ['Durum', (a) => rozet(a.status)],
      ], gelen.slice(0, 5), (a) => (location.hash = `#/kullanici/${a.userId}`)))),

    h('p', { class: 'not' }, 'HizmetCep ücretsizdir: ödeme, komisyon ya da abonelik verisi yoktur.'));
}
