// ═══════════════════════════════════════════════════════════════
// ÖZET EKRANI — yalnız MEVCUT admin API'leri (sahte/demo veri YOK)
//
// Kaynaklar: /stats · /stats/period · /users · /listings
// · /account-closures · /integrations/effective. Her bölüm bağımsız yüklenir;
// yetkisi olmayan rol (403) o bölümde "yetki yok" görür, ekran çökmez.
//
// TARİH ARALIĞI (21 Eki): sağ üstteki seçim — Bugün / Bu hafta / Bu ay /
// Tarih aralığı. Dönem kartları bu seçime göre `/stats/period` ucundan
// (doğrudan veritabanı sayımı) çizilir; dönem, eşit uzunluktaki bir önceki
// dönemle karşılaştırılır. Üç grafik kartının her birinin kendi seçimi
// vardır (Son 7 gün varsayılan; Bugün saat saat çizilir).
//
// "Son 7 gün · yeni kullanıcı" kartı yalnız listeler 7 günlük pencereyi
// TAMAMEN kapsıyorsa çizilir (en eski kayıt pencereden eskiyse ya da
// listenin tamamı alındıysa). Kapsam eksikse sayı UYDURULMAZ; "veri
// yetersiz" gösterilir. CSP: satır içi stil yok; grafik SVG öznitelikli.
// ═══════════════════════════════════════════════════════════════
import { api, h, rozet } from './cekirdek.js';
import { ikon, svg } from './svg.js';
import { kanalDurumu } from './kanal_durumu.js';
import { kapatmaPaneli } from './hesap_kapatma.js';

const GUN = 86_400_000;
const RENK = { mavi: '#2563EB', yesil: '#22C55E', mor: '#8B5CF6', turuncu: '#F97316', kirmizi: '#EF4444', gri: '#94A3B8' };
const kisaTarih = (v) => (v ? new Date(v).toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '—');
const sayi = (v) => (Number.isFinite(v) ? v.toLocaleString('tr-TR') : '—');
const gunBasi = (t) => { const d = new Date(t); d.setHours(0, 0, 0, 0); return d.getTime(); };

// ── TARİH ARALIĞI SEÇİMİ ──
// Seçim sayfa oturumu boyunca hatırlanır (başka sayfaya gidip dönünce).
let secim = { tur: 'bugun' };
// Grafik kartlarının her biri kendi seçimini taşır. 23 Eki (kullanıcı kuralı):
// sağ üstteki seçim yapılınca filtreli BÜTÜN kartlar (dönem kartları, Teklif
// Talepleri, Seçilen Toplam Teklif Tutarı ve üç grafik) o döneme geçer;
// kartın kendi seçicisi sonradan yalnız o kartı değiştirir. Başlangıçta da
// hepsi sağ üstteki seçimle (Bugün) açılır.
const grafikSecimi = { users: { tur: 'bugun' }, listings: { tur: 'bugun' }, offers: { tur: 'bugun' } };
function genelSecimUygula(yeni) {
  secim = yeni;
  tutarSecimi = yeni;
  for (const k of Object.keys(grafikSecimi)) grafikSecimi[k] = yeni;
}
const AZAMI_GUN = 366;
const yerelGun = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
const gunEkle = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
const gunFarki = (a, b) => Math.round((yerelGun(b) - yerelGun(a)) / GUN);
const girdiTarihi = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const girdidenTarih = (v) => { const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(v ?? ''); return m ? new Date(+m[1], +m[2] - 1, +m[3]) : null; };
const uzunTarih = (d) => d.toLocaleDateString('tr-TR', { day: 'numeric', month: 'short', year: 'numeric' });
const SECENEKLER = [['bugun', 'Bugün'], ['hafta', 'Bu hafta'], ['ay', 'Bu ay']];
const GRAFIK_SECENEKLERI = [['son7', 'Son 7 gün'], ...SECENEKLER];

/** Seçimden dönem: başlangıç (yerel gün başı), gün sayısı, etiket. */
function donem(x) {
  const bugun = yerelGun(new Date());
  if (x.tur === 'hafta') { const n = ((bugun.getDay() + 6) % 7) + 1; return { bas: gunEkle(bugun, -(n - 1)), gun: n, etiket: 'Bu hafta' }; }
  if (x.tur === 'ay') return { bas: new Date(bugun.getFullYear(), bugun.getMonth(), 1), gun: bugun.getDate(), etiket: 'Bu ay' };
  if (x.tur === 'aralik') return { bas: x.bas, gun: gunFarki(x.bas, x.bit) + 1, etiket: 'Tarih aralığı' };
  if (x.tur === 'son7') return { bas: gunEkle(bugun, -6), gun: 7, etiket: 'Son 7 gün' };
  // 22 Eki: yıl seçimi (içinde bulunulan yıl bugüne kadar).
  if (x.tur === 'yil') {
    const bas = new Date(x.yil, 0, 1);
    const son = x.yil === bugun.getFullYear() ? bugun : new Date(x.yil, 11, 31);
    return { bas, gun: gunFarki(bas, son) + 1, etiket: String(x.yil) };
  }
  return { bas: bugun, gun: 1, etiket: 'Bugün' };
}

function yenidenCiz() { window.dispatchEvent(new HashChangeEvent('hashchange')); }

/**
 * Tarih seçici — sağ üst (büyük) ve grafik kartları (küçük) aynı bileşeni
 * kullanır. x: seçim, onSec: yeni seçimle çağrılır.
 */
function tarihSecici(x, onSec, { secenekler = SECENEKLER, kucuk = false, aralik = true } = {}) {
  const d = donem(x);
  const son = gunEkle(d.bas, d.gun - 1);
  const aralikMetni = d.gun === 1 ? uzunTarih(d.bas) : `${uzunTarih(d.bas)} - ${uzunTarih(son)}`;
  const metin = kucuk ? (x.tur === 'aralik' ? aralikMetni : d.etiket) : `${d.etiket} · ${aralikMetni}`;
  // Seçenek: [tür, ad, ek alanlar] (yıl: { yil }).
  const seciliMi = (tur, ek) => x.tur === tur && (tur !== 'yil' || x.yil === ek?.yil);
  const bugun = yerelGun(new Date());
  const ilk = h('input', { type: 'date', max: girdiTarihi(bugun), value: girdiTarihi(d.bas), 'aria-label': 'Başlangıç tarihi' });
  const sonGirdi = h('input', { type: 'date', max: girdiTarihi(bugun), value: girdiTarihi(son), 'aria-label': 'Bitiş tarihi' });
  const hataYeri = h('p', { class: 'oz-aralik-hata', role: 'alert' });
  const sar = h('div', { class: `oz-tarih-sar${kucuk ? ' kucuk' : ''}` });
  const dugme = h('button', { type: 'button', class: kucuk ? 'oz-secim oz-secim-dugme' : 'oz-tarih', title: aralikMetni, 'aria-haspopup': 'true', 'aria-expanded': 'false' },
    kucuk ? null : ikon('takvim', 18), h('span', {}, metin), h('span', { class: 'oz-tarih-ok', 'aria-hidden': 'true' }, '▾'));
  const ac = (acik) => { sar.classList.toggle('acik', acik); dugme.setAttribute('aria-expanded', String(acik)); };
  dugme.addEventListener('click', (e) => { e.stopPropagation(); ac(!sar.classList.contains('acik')); });
  const disari = (e) => {
    if (!sar.isConnected) { document.removeEventListener('click', disari); document.removeEventListener('keydown', kacis); return; }
    if (!sar.contains(e.target)) ac(false);
  };
  const kacis = (e) => { if (e.key === 'Escape') ac(false); };
  document.addEventListener('click', disari);
  document.addEventListener('keydown', kacis);
  const sec = (yeni) => { ac(false); onSec(yeni); };
  const uygula = (e) => {
    e.preventDefault();
    const b = girdidenTarih(ilk.value); const t = girdidenTarih(sonGirdi.value);
    let hataMetni = '';
    if (!b || !t) hataMetni = 'Başlangıç ve bitiş tarihini seçin.';
    else if (b > t) hataMetni = 'Başlangıç tarihi bitişten sonra olamaz.';
    else if (t > bugun) hataMetni = 'Bitiş tarihi bugünden sonra olamaz.';
    else if (gunFarki(b, t) + 1 > AZAMI_GUN) hataMetni = `En fazla ${AZAMI_GUN} gün seçilebilir.`;
    hataYeri.textContent = hataMetni;
    if (!hataMetni) sec({ tur: 'aralik', bas: b, bit: t });
  };
  sar.append(dugme, h('div', { class: 'oz-tarih-menu', role: 'menu' },
    secenekler.map(([tur, ad, ek]) => h('button', { type: 'button', role: 'menuitem', class: `oz-tarih-secenek${seciliMi(tur, ek) ? ' secili' : ''}`, onclick: () => sec({ tur, ...(ek ?? {}) }) }, ad)),
    aralik ? h('form', { class: `oz-aralik${x.tur === 'aralik' ? ' secili' : ''}`, onsubmit: uygula },
      h('div', { class: 'oz-aralik-baslik' }, 'Tarih aralığı'),
      h('label', {}, 'Başlangıç', ilk), h('label', {}, 'Bitiş', sonGirdi),
      hataYeri,
      h('button', { type: 'submit', class: 'oz-aralik-uygula' }, 'Uygula')) : null));
  return sar;
}

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


/**
 * Kart başlığı + "Tümünü gör" bağlantısı (sayfa Özet içinde açılır).
 * hedef: 'sayfa' ya da birden çok bağlantı için [['Ad', 'sayfa'], …].
 */
function bolum(baslik, hedef, ...icerik) {
  const baglantilar = Array.isArray(hedef)
    ? h('span', { class: 'oz-tumu-grup' }, hedef.map(([ad, s]) => h('a', { class: 'oz-tumu', href: `#/${s}` }, `${ad} ›`)))
    : hedef ? h('a', { class: 'oz-tumu', href: `#/${hedef}` }, 'Tümünü gör ›') : null;
  return h('section', { class: 'oz-kart' },
    h('div', { class: 'oz-kart-ust' }, h('h3', {}, baslik), baglantilar),
    ...icerik);
}

function yuklenemedi(e) {
  return h('p', { class: 'oz-bos' }, e?.durum === 403 ? 'Bu bölüm için yetkiniz yok.' : 'Veri alınamadı.');
}

/** Bugün kartı: bugünkü sayı + düne göre değişim (yalnız kapsam tamsa). */
function bugunKarti(ad, ikonAd, renk, veri, karsilastirma = 'Düne göre') {
  const [bugun, dun] = veri ?? [null, null];
  let fark = null;
  if (bugun !== null && dun !== null) {
    if (dun === 0) fark = null; // sıfıra göre yüzde anlamsız; yalnız karşılaştırma sayısı gösterilir
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
          h('div', { class: 'oz-alt' }, `${karsilastirma}: ${sayi(dun)}`)]));
}

const tl = (v) => `${Number(v ?? 0).toLocaleString('tr-TR')} TL`;

/**
 * Seçilen teklif tutarı (21 Eki): seçilen dönemde hizmet alanların SEÇTİĞİ
 * tekliflerin toplamı — HizmetCep'in aracılık ettiği iş hacmi. Her seçim
 * bir kez, seçildiği gün sayılır (ilan teklifleri + kabul edilen teklif
 * talepleri). Kaynak: /stats/market.
 */
// 22 Eki: kartın kendi seçimi — Bugün / Bu hafta / Bu ay / yıllar (yeniden eskiye).
let tutarSecimi = { tur: 'bugun' };
function tutarKarti() {
  const BASLIK = 'Seçilen Toplam Teklif Tutarı';
  const kart = h('section', { class: 'oz-kart oz-tutar' });
  let ilkYil = null;
  const ciz = async () => {
    const x = tutarSecimi;
    const d = donem(x);
    const buYil = new Date().getFullYear();
    const yillar = [];
    for (let y = buYil; y >= Math.min(ilkYil ?? buYil, buYil); y -= 1) yillar.push(['yil', String(y), { yil: y }]);
    const ust = h('div', { class: 'oz-kart-ust' }, h('h3', {}, BASLIK),
      tarihSecici(x, (yeni) => { tutarSecimi = yeni; ciz(); }, { secenekler: [...SECENEKLER, ...yillar], kucuk: true, aralik: false }));
    kart.replaceChildren(ust, h('p', { class: 'oz-bos' }, 'Yükleniyor…'));
    let r;
    try {
      r = await api(`/stats/market?from=${encodeURIComponent(d.bas.toISOString())}&days=${d.gun}`);
    } catch (e) {
      if (tutarSecimi === x) kart.replaceChildren(ust, yuklenemedi(e));
      return;
    }
    if (tutarSecimi !== x) return; // bu arada başka seçim yapıldı
    if (r.firstSelectedYear && r.firstSelectedYear !== ilkYil) { ilkYil = r.firstSelectedYear; return ciz(); }
    const s = r.selectedOffers;
    kart.replaceChildren(ust,
      h('div', { class: 'oz-tutar-buyuk' }, tl(s.totalTl)),
      h('p', { class: 'oz-alt' }, `${sayi(s.count)} teklif seçildi · hizmet alanların seçtiği tekliflerin toplamı`),
      h('div', { class: 'oz-mini-izgara iki' },
        miniKart(`İlan teklifleri · ${sayi(s.listingOffers.count)} adet`, null, 'ilan', 'mavi', tl(s.listingOffers.totalTl)),
        miniKart(`Teklif talepleri · ${sayi(s.teklifTalepleri.count)} adet`, null, 'talep', 'turuncu', tl(s.teklifTalepleri.totalTl))));
  };
  ciz();
  return kart;
}

function miniKart(ad, deger, ikonAd, renk, metin) {
  return h('div', { class: 'oz-mini' },
    h('span', { class: `oz-yuvarlak kucuk ${renk}` }, ikon(ikonAd, 18)),
    h('div', {}, h('div', { class: 'oz-etiket' }, ad), h('div', { class: 'oz-orta' }, metin ?? sayi(deger))));
}

/** Çizgi grafik (SVG). seriler: [{ad, renk, degerler[]}], etiketler: gün adları. */
function grafik(seriler, etiketler) {
  const N = etiketler.length;
  const G = 320, Y = 150, sol = 28, alt = 22, ust = 8;
  const enCok = Math.max(1, ...seriler.flatMap((s) => s.degerler));
  const adim = Math.max(1, Math.ceil(enCok / 4));
  const tavan = adim * 4;
  const x = (i) => sol + 6 + (N > 1 ? (i * (G - sol - 26)) / (N - 1) : (G - sol - 26) / 2);
  const y = (v) => ust + (Y - ust - alt) * (1 - v / tavan);
  const k = svg('svg', { viewBox: `0 0 ${G} ${Y}`, class: 'oz-grafik', role: 'img', 'aria-label': `${etiketler[0]} - ${etiketler[N - 1]} grafiği` });
  for (let i = 0; i <= 4; i++) {
    const v = i * adim;
    k.append(svg('line', { x1: sol, x2: G - 4, y1: y(v), y2: y(v), stroke: '#EEF1F6', 'stroke-width': 1 }));
    const t = svg('text', { x: sol - 6, y: y(v) + 3, 'text-anchor': 'end', 'font-size': 9, fill: '#94A3B8' });
    t.textContent = String(v);
    k.append(t);
  }
  // Uzun aralıkta etiketler seyreltilir (en çok ~8 etiket; son gün hep yazılır).
  const seyrek = Math.max(1, Math.ceil(N / 8));
  etiketler.forEach((e, i) => {
    if ((N - 1 - i) % seyrek !== 0) return;
    const t = svg('text', { x: x(i), y: Y - 6, 'text-anchor': 'middle', 'font-size': 9, fill: '#94A3B8' });
    t.textContent = e;
    k.append(t);
  });
  for (const s of seriler) {
    const nokta = s.degerler.map((v, i) => `${x(i)},${y(v)}`).join(' ');
    if (seriler.length === 1) {
      k.append(svg('polygon', { points: `${x(0)},${y(0)} ${nokta} ${x(N - 1)},${y(0)}`, fill: s.renk, 'fill-opacity': 0.08 }));
    }
    k.append(svg('polyline', { points: nokta, fill: 'none', stroke: s.renk, 'stroke-width': 2 }));
    s.degerler.forEach((v, i) => k.append(svg('circle', { cx: x(i), cy: y(v), r: N > 31 ? 1.5 : 3, fill: s.renk })));
  }
  return k;
}

/**
 * Grafik kartı — kendi tarih seçimiyle (Son 7 gün / Bugün / Bu hafta /
 * Bu ay / Tarih aralığı). Seçim değişince yalnız bu kart yeniden yüklenir.
 * Bugün (tek gün) saat saat çizilir. anahtar: /stats/period alanı.
 */
function grafikKarti(baslik, anahtar, seri) {
  const kart = h('section', { class: 'oz-kart' });
  const govde = h('div', {});
  const ciz = async () => {
    const x = grafikSecimi[anahtar];
    const d = donem(x);
    kart.replaceChildren(
      h('div', { class: 'oz-kart-ust' }, h('h3', {}, baslik),
        tarihSecici(x, (yeni) => { grafikSecimi[anahtar] = yeni; ciz(); }, { secenekler: GRAFIK_SECENEKLERI, kucuk: true })),
      govde);
    govde.replaceChildren(h('p', { class: 'oz-bos' }, 'Yükleniyor…'));
    const saatlik = d.gun === 1;
    try {
      const r = await api(`/stats/period?from=${encodeURIComponent(d.bas.toISOString())}&days=${d.gun}${saatlik ? '&unit=hour' : ''}`);
      if (grafikSecimi[anahtar] !== x) return; // bu arada başka seçim yapıldı
      const degerler = r[anahtar];
      const etiketler = saatlik
        ? Array.from({ length: 24 }, (_, i) => `${String(i).padStart(2, '0')}:00`)
        : Array.from({ length: d.gun }, (_, i) => gunEkle(d.bas, i).toLocaleDateString('tr-TR', { day: 'numeric', month: 'short' }));
      govde.replaceChildren(Array.isArray(degerler)
        ? grafik([{ ...seri, degerler }], etiketler)
        : h('p', { class: 'oz-bos' }, 'Bu grafik için yetkiniz yok.'));
    } catch (e) {
      if (grafikSecimi[anahtar] === x) govde.replaceChildren(yuklenemedi(e));
    }
  };
  ciz();
  return kart;
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
  // Seçili dönem + karşılaştırma için eşit uzunlukta önceki dönem.
  const d = donem(secim);
  const toplamGun = 2 * d.gun;
  const sorguBas = gunEkle(d.bas, d.gun - toplamGun);
  const [st, ku, il, en, dn, pz] = await Promise.all([
    al('/stats'), al('/users?limit=200'), al('/listings?limit=200'),
    al('/integrations/effective'),
    al(`/stats/period?from=${encodeURIComponent(sorguBas.toISOString())}&days=${toplamGun}`),
    // Seçili dönemin teklif talepleri ve seçilen teklif tutarı (21 Eki).
    al(`/stats/market?from=${encodeURIComponent(d.bas.toISOString())}&days=${d.gun}`),
  ]);
  if (st.e) throw st.e; // özet sayıları alınamıyorsa ekranın anlamı yok

  const s = st.v;
  const kullanicilar = ku.v?.items;
  const ilanlar = il.v?.items;

  // "Son 7 gün · yeni kullanıcı" kartı (değişmedi): liste 7 günü kapsıyorsa.
  const gunler = { kullanici: kapsar(kullanicilar, ku.v?.total) ? gunluk(kullanicilar) : null };
  // Dönem toplamı ve önceki dönem (dizinin son `gun` günü / ondan önceki `gun` gün).
  const topla = (a) => a.reduce((x, y) => x + y, 0);
  const donemSay = (dizi) => (Array.isArray(dizi) ? [topla(dizi.slice(-d.gun)), topla(dizi.slice(-2 * d.gun, -d.gun))] : null);
  const dv = dn.v ?? {};
  const karsilastirma = d.gun > 1 ? 'Önceki döneme göre' : secim.tur === 'bugun' ? 'Düne göre' : 'Önceki güne göre';


  // ── Kullanıcı dağılımı (yalnız liste tamsa) ──
  const tamListe = kullanicilar && ku.v.total <= kullanicilar.length;
  const rolSay = (r) => (tamListe ? kullanicilar.filter((u) => u.roles.includes(r)).length : null);
  const son7 = gunler.kullanici ? gunler.kullanici.slice(1).reduce((a, b) => a + b, 0) : null;

  // ── Sistem durumu (yalnız backend'den bilinenler) ──
  const durumSatiri = (ad, ikonAd, durum, sinif) => h('li', {}, h('span', { class: 'oz-durum-ad' }, ikon(ikonAd, 18), ad),
    h('span', { class: `oz-durum ${sinif}` }, durum));
  const sistem = [
    durumSatiri('Backend API', 'sunucu', 'Yanıt veriyor', 'iyi'), // bu ekranın verisi şu an ondan geldi
    durumSatiri('Veritabanı', 'db', 'Yanıt veriyor', 'iyi'), // sayılar şu an veritabanından okundu
    ...(en.e
      ? []
      // 23 Eki: kanalın GERÇEK kaynağı (panel → sunucu ayarı → yok); kural
      // tek kaynakta (kanal_durumu.js), Sistem Durumu ekranıyla aynı.
      : ['SMS', 'EMAIL', 'STORAGE'].map((t) => {
        const k = en.v.find((i) => i.type === t);
        const ikonAd = { SMS: 'sms', EMAIL: 'posta', STORAGE: 'depo' }[t];
        const d = kanalDurumu(k);
        return durumSatiri(ENTEGRASYON[t], ikonAd, d.metin, d.sinif);
      })),
    durumSatiri('Bildirim gönderimi (24 saat)', 'zil',
      s.failedNotifications ? `${sayi(s.failedNotifications)} başarısız` : 'Sorun yok', s.failedNotifications ? 'kotu' : 'iyi'),
  ];

  return h('div', { class: 'oz' },
    h('div', { class: 'oz-baslik' },
      h('div', {}, h('h2', {}, 'Özet'), h('p', {}, 'Uygulamanın genel durumu ve son istatistikler')),
      tarihSecici(secim, (yeni) => { genelSecimUygula(yeni); yenidenCiz(); })),

    h('section', { class: 'oz-kart oz-bugun-sar' },
      h('h3', {}, d.etiket),
      h('div', { class: 'oz-bugun-izgara' },
        bugunKarti('Yeni kullanıcı', 'kisi', 'mavi', donemSay(dv.users), karsilastirma),
        bugunKarti('Yeni ilan', 'ilan', 'yesil', donemSay(dv.listings), karsilastirma),
        bugunKarti('Yeni teklif', 'teklif', 'mor', donemSay(dv.offers), karsilastirma),
        bugunKarti('Yeni teklif talebi', 'talep', 'turuncu', donemSay(dv.teklifTalepleri), karsilastirma),
        bugunKarti('Gelen talep', 'talep', 'kirmizi', donemSay(dv.supportTickets), karsilastirma))),

    h('div', { class: 'oz-uclu sd-iki' },
      tutarKarti(),
      bolum('Teklif Talepleri', 'talepler', pz.e ? yuklenemedi(pz.e) : (() => {
        const t = pz.v.teklifTalepleri; const b = t.byStatus;
        return h('div', {},
          h('p', { class: 'oz-alt oz-donem-not' }, `${d.etiket} açılan talepler · bugünkü durumları`),
          h('div', { class: 'oz-mini-izgara dort' },
            miniKart('Toplam talep', t.total, 'talep', 'turuncu'),
            miniKart('Teklif bekliyor', b.BEKLEMEDE, 'talep', 'acikmavi'),
            miniKart('Teklif geldi', b.TEKLIF_GELDI, 'teklif', 'mor'),
            miniKart('Seçildi', b.SECILDI, 'tik', 'mavi'),
            miniKart('Tamamlandı', b.TAMAMLANDI, 'tik', 'yesil'),
            miniKart('Reddedildi', b.REDDEDILDI, 'ban', 'kirmizi'),
            miniKart('Süresi doldu', b.SURESI_DOLDU, 'askida', 'turuncu'),
            miniKart('İptal edildi', t.cancelled, 'silme', 'kirmizi')));
      })())),

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
      bolum('İlan ve Teklifler', [['İlanlar', 'ilanlar'], ['Teklifler', 'teklifler']],
        h('div', { class: 'oz-mini-izgara uc' },
          miniKart('Açık ilan', s.activeListings, 'ilan', 'mavi'),
          miniKart('Son 24 saatte teklif', s.offersToday, 'teklif', 'mor'),
          miniKart('Süren teklif talebi', s.openTalepler, 'talep', 'turuncu'))),
      bolum('Sistem Durumu', 'sistem', h('ul', { class: 'oz-durum-liste' }, sistem),
        en.e ? h('p', { class: 'oz-bos' }, 'Entegrasyon durumu için yetkiniz yok.') : null)),

    h('div', { class: 'oz-uclu' },
      grafikKarti('Yeni Kullanıcılar', 'users', { ad: 'Yeni kullanıcı', renk: RENK.mavi, sinif: 'mavi' }),
      grafikKarti('Yeni İlanlar', 'listings', { ad: 'Yeni ilan', renk: RENK.yesil, sinif: 'yesil' }),
      grafikKarti('Teklifler', 'offers', { ad: 'Yeni teklif', renk: RENK.mor, sinif: 'mor' })),

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
      // 21 Eki: Hesabını Silenler ve Donduranlar (tek kaynak: hesap_kapatma.js).
      // Tüm zamanlar: toplam sayılar + kaydırılabilir liste.
      bolum('Hesabını Silenler ve Donduranlar', 'silmekuyruklari', kapatmaPaneli({ kompakt: true }))),

    h('p', { class: 'not' }, 'HizmetCep ücretsizdir: ödeme, komisyon ya da abonelik verisi yoktur.'));
}
