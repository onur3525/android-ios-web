// ═══════════════════════════════════════════════════════════════
// İLANLAR LİSTESİ — Özet/Kullanıcılar/Kullanıcı Detay ile aynı dil
//
// YALNIZ MEVCUT UÇLAR (backend değişmedi; demo/sahte veri YOK):
//   GET  /admin/v1/listings?q&status&limit&offset → { total, items[] }
//        q: başlık (hizmet adı), açıklama ya da tam ilan numarası
//        status: ACTIVE | EXPIRED | USER_DELETED | ADMIN_REMOVED
//   GET  /admin/v1/users/:id            → ilan sahibinin adı (yalnız yetkili rol)
//   POST /admin/v1/listings/:id/remove  → yayından kaldırma (gerekçe + yeniden doğrulama)
// Liste API'si kategori ve teklif sayısı VERMEZ; bu sütunlar yoktur.
// Sayfalama, arama ve süzgeç SUNUCUDA yapılır.
// ═══════════════════════════════════════════════════════════════
import { api, bildir, gerekceIle, h } from './cekirdek.js';

const SAYFA = 25;
const DURUMLAR = [
  ['', 'Tümü'], ['ACTIVE', 'Aktif'], ['EXPIRED', 'Süresi doldu'],
  ['USER_DELETED', 'Sahibi sildi'], ['ADMIN_REMOVED', 'Yönetim kaldırdı'],
];
const DURUM_ADI = Object.fromEntries(DURUMLAR.filter(([v]) => v));
// Backend yetki tablosuyla aynı (auth.js): ilan kaldırma ve iletişim/ad okuma.
const KALDIRABILIR = ['super_admin', 'moderator'];
const SAHIP_GOREBILIR = ['super_admin', 'moderator'];

const tarihSaat = (v) => (v ? new Date(v).toLocaleString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—');
const sayi = (v) => (Number.isFinite(v) ? v.toLocaleString('tr-TR') : '—');

export async function ilanlarSayfasi(rol) {
  const kaldirabilir = KALDIRABILIR.includes(rol);
  const sahipGorebilir = SAHIP_GOREBILIR.includes(rol);
  const sahipOnbellek = new Map(); // id → ad | null (sayfa boyunca)

  let durum = '';
  let ofset = 0;
  let istekNo = 0;
  let say = null;

  const ara = h('input', { class: 'ku-ara', type: 'search', placeholder: 'Hizmet adı, açıklama ya da ilan no ile ara', 'aria-label': 'İlan ara' });
  const sekmeler = h('div', { class: 'ku-sekmeler', role: 'tablist' });
  const toplamKutu = h('div', { class: 'ku-sayac', hidden: true });
  const govde = h('div', {});
  const sayfalama = h('div', { class: 'ku-sayfalama' });

  /** Durum sayıları: her durum için API'nin kendi `total` değeri (limit=1). */
  async function sayilariAl() {
    const sonuc = await Promise.all(DURUMLAR.map(([v]) =>
      api(`/listings?limit=1${v ? `&status=${v}` : ''}`).then((r) => [v, r.total], () => [v, null])));
    say = Object.fromEntries(sonuc);
    if (Number.isFinite(say[''])) {
      toplamKutu.hidden = false;
      toplamKutu.textContent = `${sayi(say[''])} ilan`;
    }
    sekmeleriCiz();
  }

  function sekmeleriCiz() {
    sekmeler.replaceChildren(...DURUMLAR.map(([v, ad]) => h('button', {
      class: `ku-sekme${durum === v ? ' secili' : ''}`, role: 'tab', 'aria-selected': durum === v ? 'true' : 'false',
      onclick: () => { durum = v; ofset = 0; sekmeleriCiz(); yukle(); },
    }, ad, say && Number.isFinite(say[v]) ? h('span', { class: 'ku-sekme-sayi' }, sayi(say[v])) : null)));
  }

  /** Sayfadaki ilan sahiplerinin adları (tekil kimlikler, paralel). */
  async function sahipleriAl(items) {
    if (!sahipGorebilir) return;
    const eksik = [...new Set(items.map((l) => l.ownerId))].filter((id) => !sahipOnbellek.has(id));
    await Promise.all(eksik.map((id) => api(`/users/${id}`).then((u) => sahipOnbellek.set(id, u.name), () => sahipOnbellek.set(id, null))));
  }

  async function kaldir(l) {
    const neden = await gerekceIle(`İlan ${l.ilanNo} yayından kaldırılsın mı?`, 'Yayından kaldır',
      'İlan yayından kalkar, açık teklifler kapanır; ilan sahibine ilan adı ve gerekçeyle SMS/e-posta gider.');
    if (!neden) return;
    try {
      const r = await api(`/listings/${l.id}/remove`, { yontem: 'POST', govde: { reason: neden } });
      bildir(`İlan kaldırıldı. Bildirim: ${r.notifications.map((n) => (n.status === 'SENT' ? 'gönderildi' : 'gönderilemedi')).join(', ') || 'gönderilmedi'}`);
      await sayilariAl();
      await yukle(); // liste API'den yeniden yüklenir
    } catch (e) {
      bildir(e.durum === 403 && e.kod !== 'REAUTH_REQUIRED' ? 'Bu işlem için yetkiniz yok.' : e.message, true);
    }
  }

  const satir = (l) => {
    const sahipAdi = sahipOnbellek.get(l.ownerId);
    return h('tr', { class: 'tikla', onclick: () => (location.hash = `#/ilan/${l.id}`) },
      h('td', { 'data-baslik': 'İlan' }, h('div', { class: 'il-ilan' },
        h('div', { class: 'ku-ad' }, l.title),
        h('div', { class: 'ku-eposta' }, `No: ${l.ilanNo}`),
        l.selectedOfferId ? h('span', { class: 'ku-dogrulama evet il-secildi' }, '✓ Teklif seçildi') : null)),
      h('td', { 'data-baslik': 'İlan sahibi' }, h('a', {
        class: 'il-sahip', href: `#/kullanici/${l.ownerId}`, onclick: (e) => e.stopPropagation(),
      }, sahipAdi || 'Kullanıcıyı aç ›')),
      h('td', { 'data-baslik': 'Konum' }, l.location || '—'),
      h('td', { 'data-baslik': 'Durum' }, h('span', { class: `ku-durum kd-rozet ${l.status}` }, DURUM_ADI[l.status] ?? l.status),
        l.removedReason ? h('div', { class: 'ku-eposta il-neden', title: l.removedReason }, l.removedReason) : null),
      h('td', { 'data-baslik': 'Oluşturulma', class: 'ku-tarih' }, tarihSaat(l.createdAt)),
      h('td', { 'data-baslik': 'Bitiş', class: 'ku-tarih' }, tarihSaat(l.expiresAt)),
      h('td', { 'data-baslik': 'İşlem', class: 'il-islem' },
        kaldirabilir && l.status !== 'ADMIN_REMOVED'
          ? h('button', { class: 'btn tehlike il-kaldir', onclick: (e) => { e.stopPropagation(); kaldir(l); } }, 'Yayından kaldır')
          : h('span', { class: 'oz-tumu' }, 'Detay ›')));
  };

  async function yukle() {
    const no = ++istekNo; // eski isteğin geç yanıtı yenisini ezmesin
    govde.replaceChildren(h('div', { class: 'il-yukleniyor', role: 'status' }, 'İlanlar yükleniyor…'));
    const p = new URLSearchParams({ limit: String(SAYFA), offset: String(ofset) });
    const q = ara.value.trim();
    if (q) p.set('q', q);
    if (durum) p.set('status', durum);
    let r;
    try {
      r = await api(`/listings?${p}`);
      await sahipleriAl(r.items);
    } catch (e) {
      if (no !== istekNo) return;
      sayfalama.replaceChildren();
      govde.replaceChildren(h('div', { class: 'ku-bos' },
        h('div', { class: 'ku-bos-baslik' }, e.durum === 403 ? 'Yetkiniz yok' : 'İlanlar yüklenemedi'),
        h('p', { class: 'oz-bos' }, e.durum === 403 ? 'İlanları görüntüleme yetkiniz bulunmuyor.' : (e.message || 'Beklenmeyen bir hata oluştu.')),
        e.durum === 403 ? null : h('button', { class: 'btn ikincil', onclick: () => yukle() }, 'Tekrar dene')));
      return;
    }
    if (no !== istekNo) return;
    if (!r.items.length) {
      const suzgecli = q || durum;
      govde.replaceChildren(h('div', { class: 'ku-bos' },
        h('div', { class: 'ku-bos-baslik' }, suzgecli ? 'Eşleşen ilan bulunamadı' : 'Henüz ilan bulunmuyor'),
        suzgecli ? h('div', { class: 'oz-bos' }, 'Aramayı ya da durum süzgecini değiştirmeyi deneyin.') : null));
    } else {
      govde.replaceChildren(h('div', { class: 'oz-tablo-sar' }, h('table', { class: 'oz-tablo ku-tablo il-tablo' },
        h('thead', {}, h('tr', {}, ['İlan', 'İlan sahibi', 'Konum', 'Durum', 'Oluşturulma', 'Bitiş', 'İşlem'].map((b) => h('th', {}, b)))),
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
  await Promise.all([sayilariAl(), yukle()]);

  return h('div', { class: 'oz ku il' },
    h('div', { class: 'oz-baslik' },
      h('div', {}, h('h2', {}, 'İlanlar'), h('p', {}, 'Hizmet alanların yayınladığı ilanlar; durumlarına göre izleyin ve gerektiğinde yayından kaldırın')),
      toplamKutu),
    h('section', { class: 'oz-kart' },
      h('div', { class: 'ku-arac' }, sekmeler, ara),
      govde,
      sayfalama));
}
