// ═══════════════════════════════════════════════════════════════
// YÖNETİCİ DETAY — İŞLEM VE OTURUM İZİ (28 Eki, kullanıcı isteği)
//
// Süper admin, Yöneticiler listesinde bir isme tıklayınca o yöneticinin
// bütün izini görür:
//   · Oturumlar: açılış, kapanış (saat + neden), son işlem, IP, cihaz.
//   · İşlemler: yaptığı her şey (en yeniden eskiye), tür ve tarih
//     süzgeci, "Daha fazla" ile geçmişe sayfalama. Metinler denetim_dili.js.
// UÇLAR (yalnız süper admin — audit.read):
//   GET /admin/v1/admins/:id/detail · /sessions?before= · /activity?before=&type=&from=&to=
// Düzenle / Sil burada da var; Yöneticiler listesiyle AYNI işlevler.
// ═══════════════════════════════════════════════════════════════
import { api, bildir, form, gerekceIle, guvenli, h } from './cekirdek.js';
import {
  ISLEM_TURLERI, KAPANIS_NEDENI, ROL_ADLARI, degisiklikAyrintisi, islemOzeti, listedeGorunur,
} from './denetim_dili.js';

const ROL = Object.fromEntries(ROL_ADLARI);
const tarihSaat = (v) => (v ? new Date(v).toLocaleString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—');

function basHarfler(ad) {
  const p = String(ad || '').trim().split(/\s+/).filter(Boolean);
  return ((p[0]?.[0] ?? '') + (p.length > 1 ? p[p.length - 1][0] : '')).toLocaleUpperCase('tr-TR') || '?';
}

/** "Mozilla/5.0 (Windows NT 10.0…) Chrome/130" → "Chrome · Windows". */
export function cihazOzeti(ua) {
  const s = String(ua || '');
  if (!s) return '—';
  const tarayici = /Edg\//.test(s) ? 'Edge' : /OPR\//.test(s) ? 'Opera' : /Firefox\//.test(s) ? 'Firefox'
    : /Chrome\//.test(s) ? 'Chrome' : /Safari\//.test(s) ? 'Safari' : null;
  const sistem = /Android/.test(s) ? 'Android' : /iPhone|iPad|iPod/.test(s) ? 'iOS' : /Windows/.test(s) ? 'Windows'
    : /Mac OS X|Macintosh/.test(s) ? 'macOS' : /Linux/.test(s) ? 'Linux' : null;
  return [tarayici, sistem].filter(Boolean).join(' · ') || s.slice(0, 60);
}

function bilgi(etiket, deger) {
  return h('div', { class: 'kd-bilgi' }, h('div', { class: 'oz-etiket' }, etiket), h('div', { class: 'kd-deger' }, deger ?? '—'));
}

function tablo(kolonlar, satirlar) {
  return h('div', { class: 'oz-tablo-sar' }, h('table', { class: 'oz-tablo kd-tablo' },
    h('thead', {}, h('tr', {}, kolonlar.map((k) => h('th', {}, k[0])))),
    h('tbody', {}, satirlar.map((s) => h('tr', {}, kolonlar.map((k) => h('td', { 'data-baslik': k[0] }, k[1](s))))))));
}

// ── Yöneticiler listesiyle ORTAK işlemler (tek kaynak) ──
export async function yoneticiDuzenle(a, sonra) {
  const d = await form(`${a.email}`, [{ ad: 'role', etiket: 'Rol', tur: 'select', deger: a.role, secenekler: ROL_ADLARI }, { ad: 'active', etiket: 'Aktif', tur: 'checkbox', deger: a.active }]);
  if (d && await guvenli(() => api(`/admins/${a.id}`, { yontem: 'PATCH', govde: d }))) { bildir('Güncellendi'); sonra(); }
}

// Süper yönetici diğer yöneticileri silebilir (22 Eki). Kendini silemez.
export async function yoneticiSil(a, sonra) {
  const n = await gerekceIle(`"${a.name}" (${a.email}) silinsin mi?`, 'Sil', 'Hesap kapanır, oturumları sonlanır ve listeden kalkar. Geçmiş işlemleri denetim kaydında kalır. Aynı e-postayla yeniden yönetici eklenebilir.');
  if (n && await guvenli(() => api(`/admins/${a.id}`, { yontem: 'DELETE', govde: { reason: n } }))) { bildir('Yönetici silindi'); sonra(); }
}

export async function yoneticiDetaySayfasi(id, benId, yenile) {
  const a = await api(`/admins/${encodeURIComponent(id)}/detail`);
  const silindi = !!a.deletedAt;
  const kendisi = a.id === benId;
  const tuslar = silindi || kendisi ? [] : [
    h('button', { class: 'btn ikincil', onclick: () => yoneticiDuzenle(a, yenile) }, 'Düzenle'),
    h('button', { class: 'btn tehlike', onclick: () => yoneticiSil(a, () => { location.hash = '#/yoneticiler'; }) }, 'Sil'),
  ];

  const ust = h('section', { class: 'oz-kart kd-ust' },
    h('div', { class: 'kd-kimlik' },
      h('span', { class: 'ku-avatar kd-avatar mavi', 'aria-hidden': 'true' }, basHarfler(silindi ? '?' : a.name)),
      h('div', { class: 'kd-kimlik-metin' },
        h('h2', {}, silindi ? 'Silinmiş yönetici' : a.name),
        h('div', { class: 'kd-rozetler' },
          silindi ? h('span', { class: 'ku-durum BANNED' }, 'Silindi')
            : h('span', { class: `ku-durum ${a.active ? 'ACTIVE' : 'kd-kapali'}` }, a.active ? 'Aktif' : 'Pasif'),
          h('span', { class: 'oz-rol PROVIDER' }, ROL[a.role] ?? a.role),
          kendisi ? h('span', { class: 'ku-dogrulama evet' }, 'Siz') : null),
        h('div', { class: 'kd-id' }, silindi ? `Silinme: ${tarihSaat(a.deletedAt)}` : a.email))),
    tuslar.length ? h('div', { class: 'kd-tuslar' }, tuslar) : null);

  const bilgiler = h('section', { class: 'oz-kart' },
    h('div', { class: 'kd-bilgi-izgara' },
      bilgi('Son giriş', a.lastLoginAt ? `${tarihSaat(a.lastLoginAt)}${a.lastLoginIp ? ` · ${a.lastLoginIp}` : ''}` : 'Henüz giriş yok'),
      bilgi('Şu an açık oturum', String(a.openSessions)),
      bilgi('Doğrulama (MFA)', a.mfa ? 'Kurulu' : 'Yok'),
      bilgi('Hesap oluşturma', tarihSaat(a.createdAt)),
      bilgi('Toplam kayıt', a.auditCount.toLocaleString('tr-TR'))));

  // ── OTURUMLAR ──
  const oturumAlani = h('div', {});
  let oturumImleci = null;
  let oturumlar = [];
  const OTURUM_DURUMU = {
    ACIK: h.bind(null, 'span', { class: 'ku-durum ACTIVE' }, 'Açık'),
    KAPALI: h.bind(null, 'span', { class: 'ku-durum kd-kapali' }, 'Kapalı'),
    BILINMIYOR: h.bind(null, 'span', { class: 'ku-durum kd-kapali', title: '28 Ekim öncesi oturum: kapanış saati o tarihten önce tutulmuyordu' }, 'Kayıt yok'),
  };
  async function oturumYukle(devam) {
    try {
      const r = await api(`/admins/${encodeURIComponent(id)}/sessions?limit=50${devam && oturumImleci ? `&before=${oturumImleci}` : ''}`);
      oturumlar = devam ? [...oturumlar, ...r.sessions] : r.sessions;
      oturumImleci = r.nextBefore;
      oturumCiz();
    } catch (e) { bildir(e.message, true); }
  }
  function oturumCiz() {
    oturumAlani.replaceChildren(...[
      oturumlar.length ? tablo([
        ['Durum', (o) => (OTURUM_DURUMU[o.status] ?? OTURUM_DURUMU.BILINMIYOR)()],
        ['Açılış', (o) => tarihSaat(o.openedAt)],
        ['Kapanış', (o) => (o.status === 'ACIK' ? 'Açık' : o.closedAt
          ? h('div', {}, h('div', {}, tarihSaat(o.closedAt)), h('div', { class: 'ku-eposta' }, KAPANIS_NEDENI[o.closeReason] ?? o.closeReason ?? ''))
          : '—')],
        ['Son işlem', (o) => tarihSaat(o.lastActivityAt)],
        ['IP', (o) => o.ip || '—'],
        ['Cihaz', (o) => h('span', { title: o.device || '' }, cihazOzeti(o.device))],
      ], oturumlar) : h('p', { class: 'oz-bos kd-bos' }, 'Henüz oturum kaydı yok.'),
      oturumImleci ? h('button', { class: 'btn ikincil dn-daha', onclick: () => oturumYukle(true) }, 'Daha fazla') : null,
    ].filter(Boolean));
  }

  // ── İŞLEMLER ──
  const islemAlani = h('div', {});
  const turSec = h('select', { 'aria-label': 'İşlem türü' },
    h('option', { value: '' }, 'Bütün işlemler'), ISLEM_TURLERI.map(([k, ad]) => h('option', { value: k }, ad)));
  const basTarih = h('input', { type: 'date', 'aria-label': 'Başlangıç tarihi' });
  const bitTarih = h('input', { type: 'date', 'aria-label': 'Bitiş tarihi' });
  let islemImleci = null;
  let islemler = [];
  async function islemYukle(devam) {
    const q = new URLSearchParams({ limit: '50' });
    if (devam && islemImleci) q.set('before', String(islemImleci));
    if (turSec.value) q.set('type', turSec.value);
    if (basTarih.value) q.set('from', basTarih.value);
    if (bitTarih.value) q.set('to', bitTarih.value);
    try {
      const r = await api(`/admins/${encodeURIComponent(id)}/activity?${q}`);
      const gorunen = r.items.filter(listedeGorunur);
      islemler = devam ? [...islemler, ...gorunen] : gorunen;
      islemImleci = r.nextBefore;
      islemCiz();
    } catch (e) { bildir(e.message, true); }
  }
  function islemCiz() {
    islemAlani.replaceChildren(...[
      h('div', { class: 'dn-suzgec' },
        turSec,
        h('label', {}, 'Başlangıç ', basTarih),
        h('label', {}, 'Bitiş ', bitTarih),
        h('button', { class: 'btn', onclick: () => islemYukle(false) }, 'Uygula'),
        h('button', { class: 'btn ikincil', onclick: () => { turSec.value = ''; basTarih.value = ''; bitTarih.value = ''; islemYukle(false); } }, 'Temizle')),
      islemler.length ? tablo([
        ['Tarih', (x) => tarihSaat(x.createdAt)],
        ['İşlem', (x) => h('div', {}, h('div', { class: 'dn-ozet' }, islemOzeti(x)), degisiklikAyrintisi(x))],
        ['Gerekçe', (x) => x.reason || '—'],
        ['IP', (x) => x.ip || '—'],
      ], islemler) : h('p', { class: 'oz-bos kd-bos' }, 'Bu süzgece uyan kayıt yok.'),
      islemImleci ? h('button', { class: 'btn ikincil dn-daha', onclick: () => islemYukle(true) }, 'Daha fazla') : null,
    ].filter(Boolean));
  }

  // ── SEKMELER ──
  const sekmeler = [['Oturumlar', oturumAlani, () => oturumYukle(false)], ['İşlemler', islemAlani, () => islemYukle(false)]];
  const alan = h('div', { class: 'kd-sekme-icerik' });
  const yuklendi = new Set();
  const dugmeler = sekmeler.map(([ad], i) => h('button', { class: 'ku-sekme', role: 'tab', onclick: () => sec(i) }, ad));
  function sec(i) {
    dugmeler.forEach((d, j) => { d.classList.toggle('secili', i === j); d.setAttribute('aria-selected', i === j ? 'true' : 'false'); });
    alan.replaceChildren(sekmeler[i][1]);
    if (!yuklendi.has(i)) {
      yuklendi.add(i);
      sekmeler[i][1].replaceChildren(h('p', { class: 'not' }, 'Yükleniyor…'));
      sekmeler[i][2]();
    }
  }
  sec(0);

  return h('div', { class: 'oz ku kd' },
    h('a', { class: 'oz-tumu kd-geri', href: '#/yoneticiler' }, '‹ Yöneticiler'),
    ust,
    bilgiler,
    h('section', { class: 'oz-kart' },
      h('p', { class: 'oz-bos' }, 'Kayıtlar değiştirilemez ve silinemez. Oturum kapanışları 28 Ekim 2026\'dan itibaren tutulur.'),
      h('div', { class: 'ku-sekmeler kd-sekmeler', role: 'tablist' }, dugmeler),
      alan));
}
