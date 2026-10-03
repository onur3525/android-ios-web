// ═══════════════════════════════════════════════════════════════
// KULLANICILAR LİSTESİ — Özet ekranıyla aynı görsel dil (.oz-* + .ku-*)
//
// Kaynaklar (MEVCUT uçlar, backend değişmedi):
//   GET /admin/v1/users?q&status&limit&offset → { total, items[] }
//   GET /admin/v1/stats → durum sekmelerinin sayıları
// Sayfalama sunucuda (limit/offset). Rol süzgeci EKLENMEDİ: API rolle
// süzmüyor; istemcide süzmek sayfalı listede yanlış sonuç verirdi.
// İletişim bilgisi API'nin döndürdüğü gibi gösterilir (yetkisiz rollere
// sunucu zaten maskeli verir). Satıra tıklama: mevcut detay ekranı.
// ═══════════════════════════════════════════════════════════════
import { api, h } from './cekirdek.js';

const SAYFA = 25;
const DURUMLAR = [
  ['', 'Tümü'], ['ACTIVE', 'Aktif'], ['SUSPENDED', 'Askıda'], ['BANNED', 'Banlı'],
];
const DURUM_ADI = { ACTIVE: 'Aktif', SUSPENDED: 'Askıda', BANNED: 'Banlı' };
const ROL_ADI = { CUSTOMER: 'Hizmet Alan', PROVIDER: 'Hizmet Veren' };

const kisaTarih = (v) => (v ? new Date(v).toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '—');
const sayi = (v) => (Number.isFinite(v) ? v.toLocaleString('tr-TR') : '—');

function basHarfler(ad) {
  const p = String(ad || '').trim().split(/\s+/).filter(Boolean);
  return ((p[0]?.[0] ?? '') + (p.length > 1 ? p[p.length - 1][0] : '')).toLocaleUpperCase('tr-TR') || '?';
}

function dogrulama(etiket, dogru) {
  return h('span', { class: `ku-dogrulama ${dogru ? 'evet' : 'hayir'}`, title: `${etiket} ${dogru ? 'doğrulanmış' : 'doğrulanmamış'}` },
    dogru ? '✓' : '•', ' ', etiket);
}

export async function kullanicilarSayfasi() {
  // Durum sayıları (Özet ile aynı kaynak). Yetki yoksa sekmeler sayısız görünür.
  const st = await api('/stats').catch(() => null);
  const say = st && {
    '': st.users, ACTIVE: st.users - st.suspended - st.banned, SUSPENDED: st.suspended, BANNED: st.banned,
  };

  let durum = '';
  let ofset = 0;
  let istekNo = 0;

  const ara = h('input', { class: 'ku-ara', type: 'search', placeholder: 'Ad, telefon ya da e-posta ile ara', 'aria-label': 'Kullanıcı ara' });
  const sekmeler = h('div', { class: 'ku-sekmeler', role: 'tablist' });
  const ozet = h('div', { class: 'ku-sayac' });
  const govde = h('div', {}, h('p', { class: 'oz-bos' }, 'Yükleniyor…'));
  const sayfalama = h('div', { class: 'ku-sayfalama' });

  const sekmeleriCiz = () => sekmeler.replaceChildren(...DURUMLAR.map(([v, ad]) =>
    h('button', {
      class: `ku-sekme${durum === v ? ' secili' : ''}`, role: 'tab', 'aria-selected': durum === v ? 'true' : 'false',
      onclick: () => { durum = v; ofset = 0; sekmeleriCiz(); yukle(); },
    }, ad, say ? h('span', { class: 'ku-sekme-sayi' }, sayi(say[v])) : null)));

  const satir = (u) => h('tr', { class: 'tikla', onclick: () => (location.hash = `#/kullanici/${u.id}`) },
    h('td', {}, h('div', { class: 'ku-kisi' },
      h('span', { class: `ku-avatar ${u.roles.includes('PROVIDER') ? 'mor' : 'mavi'}`, 'aria-hidden': 'true' }, basHarfler(u.name)),
      h('div', { class: 'ku-kisi-metin' }, h('div', { class: 'ku-ad' }, u.name), h('div', { class: 'ku-eposta' }, u.email || '—')))),
    h('td', { class: 'ku-telefon' }, u.phone),
    h('td', {}, u.roles.map((r) => h('span', { class: `oz-rol ${r}` }, ROL_ADI[r] ?? r))),
    h('td', {}, h('div', { class: 'ku-dogrulamalar' }, dogrulama('Telefon', u.phoneVerified), dogrulama('E-posta', u.emailVerified))),
    h('td', {}, h('span', { class: `ku-durum ${u.status}` }, DURUM_ADI[u.status] ?? u.status)),
    h('td', { class: 'ku-tarih' }, kisaTarih(u.createdAt)),
    h('td', { class: 'ku-ok', 'aria-hidden': 'true' }, '›'));

  async function yukle() {
    const no = ++istekNo; // eski isteğin geç gelen yanıtı yenisini ezmesin
    const p = new URLSearchParams({ limit: String(SAYFA), offset: String(ofset) });
    if (ara.value.trim()) p.set('q', ara.value.trim());
    if (durum) p.set('status', durum);
    let r;
    try {
      r = await api(`/users?${p}`);
    } catch (e) {
      if (no !== istekNo) return;
      govde.replaceChildren(h('p', { class: 'hata' }, e.durum === 403 ? 'Bu liste için yetkiniz yok.' : e.message));
      sayfalama.replaceChildren();
      return;
    }
    if (no !== istekNo) return;
    ozet.textContent = `${sayi(r.total)} kullanıcı`;
    if (!r.items.length) {
      govde.replaceChildren(h('div', { class: 'ku-bos' },
        h('div', { class: 'ku-bos-baslik' }, ara.value.trim() || durum ? 'Eşleşen kullanıcı bulunamadı' : 'Henüz kayıtlı kullanıcı yok'),
        ara.value.trim() || durum ? h('div', { class: 'oz-bos' }, 'Aramayı ya da durum süzgecini değiştirmeyi deneyin.') : null));
    } else {
      govde.replaceChildren(h('div', { class: 'oz-tablo-sar' }, h('table', { class: 'oz-tablo ku-tablo' },
        h('thead', {}, h('tr', {}, ['Kullanıcı', 'Telefon', 'Rol', 'Doğrulama', 'Durum', 'Kayıt', ''].map((b) => h('th', {}, b)))),
        h('tbody', {}, r.items.map(satir)))));
    }
    const bas = r.total ? ofset + 1 : 0;
    const son = Math.min(ofset + r.items.length, r.total);
    sayfalama.replaceChildren(
      h('span', { class: 'oz-bos' }, `${sayi(bas)}–${sayi(son)} / ${sayi(r.total)}`),
      h('div', { class: 'ku-sayfa-tuslar' },
        h('button', { class: 'btn ikincil', disabled: ofset === 0, onclick: () => { ofset = Math.max(0, ofset - SAYFA); yukle(); } }, '‹ Önceki'),
        h('button', { class: 'btn ikincil', disabled: son >= r.total, onclick: () => { ofset += SAYFA; yukle(); } }, 'Sonraki ›')));
  }

  let bekleme;
  ara.addEventListener('input', () => {
    clearTimeout(bekleme);
    bekleme = setTimeout(() => { ofset = 0; yukle(); }, 350);
  });
  ara.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { clearTimeout(bekleme); ofset = 0; yukle(); }
  });

  sekmeleriCiz();
  await yukle();

  return h('div', { class: 'oz ku' },
    h('div', { class: 'oz-baslik' },
      h('div', {}, h('h2', {}, 'Kullanıcılar'), h('p', {}, 'Kayıtlı hizmet alan ve hizmet veren hesapları')),
      ozet),
    h('section', { class: 'oz-kart' },
      h('div', { class: 'ku-arac' }, sekmeler, ara),
      govde,
      sayfalama));
}
