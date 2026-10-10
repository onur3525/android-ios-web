// ═══════════════════════════════════════════════════════════════
// TEKLİFLER — İlanlar ekranıyla aynı görsel dil (.oz-* .ku-* .tk-*)
//
// MEVCUT UÇ (backend değişmedi; demo/sahte veri YOK):
//   GET /admin/v1/offers?status=&providerId=&listingId=
//     → en yeni 200 teklif (DİZİ). Arama (q), sayfalama (limit/offset)
//       ve toplam sayı YOKTUR. Alanlar: id, listingId, providerId,
//       amountTl, note, status (ACTIVE|SELECTED|EXPIRED|CLOSED), createdAt.
// Bu yüzden: arama kutusu YOK, sahte sayfalama YOK, "X teklif" toplamı
// YOK; yalnız listelenen kayıt sayısı ve 200 sınırı açıkça belirtilir.
//
// Ad/başlık eşlemesi (yalnız mevcut uçlar, gereken kayıtlar için):
//   İlan başlığı/no : GET /admin/v1/listings?limit=200 (+ eksikler için /listings/:id)
//   Teklif veren adı: GET /admin/v1/users?limit=200 (+ eksikler için /users/:id)
//                     — yalnız iletişim/ad görme yetkili rollerde (İlanlar ile aynı kural)
// Admin API'sinde teklif üzerinde YÖNETİM İŞLEMİ YOKTUR; düğme eklenmez.
// ═══════════════════════════════════════════════════════════════
import { api, h } from './cekirdek.js';

const SINIR = 200; // backend'in sabit üst sınırı
const DURUMLAR = [['', 'Tümü'], ['ACTIVE', 'Aktif'], ['SELECTED', 'Seçildi'], ['EXPIRED', 'Süresi doldu'], ['CLOSED', 'Kapandı']];
const DURUM_ADI = Object.fromEntries(DURUMLAR.filter(([v]) => v));
const AD_GOREBILIR = ['super_admin', 'moderator']; // backend users.contact.read ile aynı
const SOHBET_GOREBILIR = ['super_admin', 'moderator']; // backend messages.read ile aynı

const tarihSaat = (v) => (v ? new Date(v).toLocaleString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—');
const tl = (v) => (Number.isFinite(v) ? `${v.toLocaleString('tr-TR')} TL` : '—');

/** Eşzamanlılığı sınırlı paralel çalıştırma (gereksiz yük yaratmamak için). */
async function sinirli(isler, adet = 6) {
  const kuyruk = [...isler];
  await Promise.all(Array.from({ length: Math.min(adet, kuyruk.length) }, async () => {
    while (kuyruk.length) await kuyruk.shift()();
  }));
}

export async function tekliflerSayfasi(rol) {
  const adGorebilir = AD_GOREBILIR.includes(rol);
  const sohbetGorebilir = SOHBET_GOREBILIR.includes(rol);
  const ilanlar = new Map(); // listingId → { title, ilanNo } | null
  const kisiler = new Map(); // providerId → ad | null

  let durum = '';
  let istekNo = 0;

  const sekmeler = h('div', { class: 'ku-sekmeler', role: 'tablist' });
  const govde = h('div', {});
  const altBilgi = h('div', { class: 'ku-sayfalama' });

  function sekmeleriCiz() {
    sekmeler.replaceChildren(...DURUMLAR.map(([v, ad]) => h('button', {
      class: `ku-sekme${durum === v ? ' secili' : ''}`, role: 'tab', 'aria-selected': durum === v ? 'true' : 'false',
      onclick: () => { durum = v; sekmeleriCiz(); yukle(); },
    }, ad)));
  }

  /** Sayfadaki teklifler için gerçek ilan başlıkları ve (yetkiliyse) teklif veren adları. */
  async function eslesmeleriAl(teklifler) {
    const ilanEksik = [...new Set(teklifler.map((o) => o.listingId))].filter((x) => !ilanlar.has(x));
    if (ilanEksik.length) {
      // Önce tek istekte en yeni ilanlar; kalanlar tek tek.
      const toplu = await api('/listings?limit=200').catch(() => null);
      for (const l of toplu?.items ?? []) ilanlar.set(l.id, { title: l.title, ilanNo: l.ilanNo });
      await sinirli(ilanEksik.filter((x) => !ilanlar.has(x)).map((x) => () =>
        api(`/listings/${x}`).then((l) => ilanlar.set(x, { title: l.title, ilanNo: l.ilanNo }), () => ilanlar.set(x, null))));
    }
    if (!adGorebilir) return;
    const kisiEksik = [...new Set(teklifler.map((o) => o.providerId))].filter((x) => !kisiler.has(x));
    if (kisiEksik.length) {
      const toplu = await api('/users?limit=200').catch(() => null);
      for (const u of toplu?.items ?? []) kisiler.set(u.id, u.name);
      await sinirli(kisiEksik.filter((x) => !kisiler.has(x)).map((x) => () =>
        api(`/users/${x}`).then((u) => kisiler.set(x, u.name), () => kisiler.set(x, null))));
    }
  }

  const satir = (o) => {
    const ilan = ilanlar.get(o.listingId);
    const ad = kisiler.get(o.providerId);
    return h('tr', { class: 'tikla', onclick: () => (location.hash = `#/ilan/${o.listingId}`) },
      h('td', { 'data-baslik': 'İlan' }, h('div', { class: 'tk-ilan' },
        h('div', { class: 'ku-ad' }, ilan?.title ?? 'İlanı aç ›'),
        ilan?.ilanNo ? h('div', { class: 'ku-eposta' }, `İlan no: ${ilan.ilanNo}`) : null)),
      h('td', { 'data-baslik': 'Teklif veren' }, h('a', {
        class: 'il-sahip', href: `#/kullanici/${o.providerId}`, onclick: (e) => e.stopPropagation(),
      }, ad || 'Kullanıcıyı aç ›')),
      h('td', { 'data-baslik': 'Tutar', class: 'tk-tutar' }, tl(o.amountTl)),
      h('td', { 'data-baslik': 'Not' }, o.note ? h('div', { class: 'tk-not', title: o.note }, o.note) : h('span', { class: 'oz-bos' }, 'Not yok')),
      h('td', { 'data-baslik': 'Durum' }, h('span', { class: `ku-durum tk-rozet ${o.status}` }, DURUM_ADI[o.status] ?? o.status)),
      h('td', { 'data-baslik': 'Tarih', class: 'ku-tarih' }, tarihSaat(o.createdAt)),
      h('td', { 'data-baslik': 'Bağlantılar', class: 'tk-baglanti' },
        h('a', { class: 'oz-tumu', href: `#/ilan/${o.listingId}`, onclick: (e) => e.stopPropagation() }, 'İlan ›'),
        sohbetGorebilir ? h('a', { class: 'oz-tumu', href: `#/sohbet/${o.id}`, onclick: (e) => e.stopPropagation() }, 'Sohbet ›') : null));
  };

  async function yukle() {
    const no = ++istekNo;
    govde.replaceChildren(h('div', { class: 'il-yukleniyor', role: 'status' }, 'Teklifler yükleniyor…'));
    altBilgi.replaceChildren();
    let liste;
    try {
      liste = await api(`/offers${durum ? `?status=${durum}` : ''}`);
      await eslesmeleriAl(liste);
    } catch (e) {
      if (no !== istekNo) return;
      govde.replaceChildren(h('div', { class: 'ku-bos' },
        h('div', { class: 'ku-bos-baslik' }, e.durum === 403 ? 'Yetkiniz yok' : 'Teklifler yüklenemedi'),
        h('p', { class: 'oz-bos' }, e.durum === 403 ? 'Teklifleri görüntüleme yetkiniz bulunmuyor.' : (e.message || 'Beklenmeyen bir hata oluştu.')),
        e.durum === 403 ? null : h('button', { class: 'btn ikincil', onclick: () => yukle() }, 'Tekrar dene')));
      return;
    }
    if (no !== istekNo) return;
    if (!liste.length) {
      govde.replaceChildren(h('div', { class: 'ku-bos' },
        h('div', { class: 'ku-bos-baslik' }, durum ? 'Eşleşen teklif bulunamadı' : 'Henüz teklif bulunmuyor'),
        durum ? h('div', { class: 'oz-bos' }, 'Durum süzgecini değiştirmeyi deneyin.') : null));
      return;
    }
    govde.replaceChildren(h('div', { class: 'oz-tablo-sar' }, h('table', { class: 'oz-tablo ku-tablo il-tablo tk-tablo' },
      h('thead', {}, h('tr', {}, ['İlan', 'Teklif veren', 'Tutar', 'Not', 'Durum', 'Tarih', ''].map((b) => h('th', {}, b)))),
      h('tbody', {}, liste.map(satir)))));
    altBilgi.replaceChildren(h('span', { class: 'oz-bos' },
      liste.length >= SINIR
        ? `En yeni ${SINIR} teklif listeleniyor. Daha eskileri ilgili ilanın ya da kullanıcının detayından görülebilir.`
        : `${liste.length.toLocaleString('tr-TR')} teklif listeleniyor.`));
  }

  sekmeleriCiz();
  await yukle();

  return h('div', { class: 'oz ku il tk' },
    h('div', { class: 'oz-baslik' },
      h('div', {}, h('h2', {}, 'Teklifler'), h('p', {}, 'Hizmet verenlerin ilanlara verdiği teklifler; durumlarına göre izleyin, ilgili ilana ve kullanıcıya geçin'))),
    h('section', { class: 'oz-kart' },
      h('div', { class: 'ku-arac' }, sekmeler),
      govde,
      altBilgi));
}
