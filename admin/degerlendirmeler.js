// ═══════════════════════════════════════════════════════════════
// DEĞERLENDİRMELER — İlanlar/Teklifler/Teklif Talepleri ile aynı dil (.dv)
//
// MEVCUT UÇLAR (backend değişmedi; demo/sahte veri YOK):
//   GET  /admin/v1/reviews?status=&providerId=&authorId=
//     → en yeni 200 değerlendirme (DİZİ). Arama, puan süzgeci, sayfalama
//       ve toplam YOKTUR. Durum: PUBLISHED | ADMIN_DELETED.
//     Alanlar: id, listingId (''=yok), offerId (''=yok), talepId (null=yok),
//              providerId, authorId, stars (veritabanı kısıtı: 1–5), text,
//              status, createdAt, publishedAt, removedReason, removedAt
//   POST /admin/v1/reviews/:id/remove  → kaldırma (gerekçe + yeniden doğrulama)
//   Ad eşleme: GET /admin/v1/users?limit=200 (+ eksikler için /users/:id),
//   yalnız ad görme yetkili rollerde (diğer ekranlarla aynı kural).
//   Ayrı bir değerlendirme detay ekranı YOKTUR; satır tıklanmaz.
// ═══════════════════════════════════════════════════════════════
import { api, bildir, gerekceIle, h } from './cekirdek.js';

const SINIR = 200; // backend'in sabit üst sınırı
const DURUMLAR = [['', 'Tümü'], ['PUBLISHED', 'Yayında'], ['ADMIN_DELETED', 'Yönetim kaldırdı']];
const DURUM_ADI = Object.fromEntries(DURUMLAR.filter(([v]) => v));
const AD_GOREBILIR = ['super_admin', 'moderator']; // backend users.contact.read
const KALDIRABILIR = ['super_admin', 'moderator']; // backend reviews.remove
const TALEP_GOREBILIR = ['super_admin', 'moderator']; // backend messages.read (talep detayı)

const tarihSaat = (v) => (v ? new Date(v).toLocaleString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—');

async function sinirli(isler, adet = 6) {
  const kuyruk = [...isler];
  await Promise.all(Array.from({ length: Math.min(adet, kuyruk.length) }, async () => {
    while (kuyruk.length) await kuyruk.shift()();
  }));
}

/** Puan: veritabanı 1–5 tamsayı kısıtı taşır; aralık dışı/eksikse "—". */
function puan(v) {
  if (!Number.isInteger(v) || v < 1 || v > 5) return h('span', { class: 'oz-bos' }, '—');
  return h('span', { class: 'dv-puan', title: `${v} / 5`, 'aria-label': `${v} / 5 puan` },
    h('span', { class: 'dv-yildiz' }, '★'.repeat(v)), h('span', { class: 'dv-yildiz bos' }, '☆'.repeat(5 - v)),
    h('span', { class: 'dv-sayi' }, String(v)));
}

export async function degerlendirmelerSayfasi(rol) {
  const adGorebilir = AD_GOREBILIR.includes(rol);
  const kaldirabilir = KALDIRABILIR.includes(rol);
  const talepGorebilir = TALEP_GOREBILIR.includes(rol);
  const kisiler = new Map(); // id → ad | null

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

  async function adlariAl(liste) {
    if (!adGorebilir) return;
    const eksik = [...new Set(liste.flatMap((y) => [y.authorId, y.providerId]))].filter((x) => x && !kisiler.has(x));
    if (!eksik.length) return;
    const toplu = await api('/users?limit=200').catch(() => null);
    for (const u of toplu?.items ?? []) kisiler.set(u.id, u.name);
    await sinirli(eksik.filter((x) => !kisiler.has(x)).map((x) => () =>
      api(`/users/${x}`).then((u) => kisiler.set(x, u.name), () => kisiler.set(x, null))));
  }

  const kisiBag = (id) => h('a', { class: 'il-sahip', href: `#/kullanici/${id}` },
    adGorebilir && kisiler.get(id) ? kisiler.get(id) : 'Kullanıcıyı aç ›');

  function ilgili(y) {
    if (y.listingId) return h('a', { class: 'oz-tumu', href: `#/ilan/${y.listingId}` }, 'İlan ›');
    if (y.talepId) {
      return talepGorebilir ? h('a', { class: 'oz-tumu', href: `#/talep/${y.talepId}` }, 'Teklif talebi ›') : h('span', { class: 'oz-bos' }, 'Teklif talebi');
    }
    return h('span', { class: 'oz-bos' }, '—');
  }

  async function kaldir(y) {
    const neden = await gerekceIle('Değerlendirme kaldırılsın mı?', 'Kaldır',
      'Değerlendirme yayından kalkar; işlem gerekçesiyle denetim kaydına yazılır.');
    if (!neden) return;
    try {
      await api(`/reviews/${y.id}/remove`, { yontem: 'POST', govde: { reason: neden } });
      bildir('Değerlendirme kaldırıldı');
      await yukle(); // liste API'den yeniden yüklenir
    } catch (e) {
      bildir(e.durum === 403 && e.kod !== 'REAUTH_REQUIRED' ? 'Bu işlem için yetkiniz yok.' : e.message, true);
    }
  }

  const satir = (y) => h('tr', {},
    h('td', { 'data-baslik': 'Puan' }, puan(y.stars)),
    h('td', { 'data-baslik': 'Yorum' }, y.text ? h('div', { class: 'dv-yorum' }, y.text) : h('span', { class: 'oz-bos' }, 'Yorum yazılmamış')),
    h('td', { 'data-baslik': 'Değerlendiren' }, kisiBag(y.authorId)),
    h('td', { 'data-baslik': 'Hizmet veren' }, kisiBag(y.providerId)),
    h('td', { 'data-baslik': 'İlgili iş' }, ilgili(y)),
    h('td', { 'data-baslik': 'Durum' }, h('span', { class: `ku-durum dv-rozet ${y.status}` }, DURUM_ADI[y.status] ?? y.status),
      y.removedReason ? h('div', { class: 'ku-eposta il-neden', title: y.removedReason }, y.removedReason) : null),
    h('td', { 'data-baslik': 'Tarih', class: 'ku-tarih' }, tarihSaat(y.createdAt),
      y.removedAt ? h('div', { class: 'ku-eposta' }, `Kaldırma: ${tarihSaat(y.removedAt)}`) : null),
    h('td', { 'data-baslik': 'İşlem', class: 'il-islem' },
      kaldirabilir && y.status === 'PUBLISHED'
        ? h('button', { class: 'btn tehlike il-kaldir', onclick: () => kaldir(y) }, 'Kaldır')
        : null));

  async function yukle() {
    const no = ++istekNo;
    govde.replaceChildren(h('div', { class: 'il-yukleniyor', role: 'status' }, 'Değerlendirmeler yükleniyor…'));
    altBilgi.replaceChildren();
    let liste;
    try {
      liste = await api(`/reviews${durum ? `?status=${durum}` : ''}`);
      await adlariAl(liste);
    } catch (e) {
      if (no !== istekNo) return;
      govde.replaceChildren(h('div', { class: 'ku-bos' },
        h('div', { class: 'ku-bos-baslik' }, e.durum === 403 ? 'Yetkiniz yok' : 'Değerlendirmeler yüklenemedi'),
        h('p', { class: 'oz-bos' }, e.durum === 403 ? 'Değerlendirmeleri görüntüleme yetkiniz bulunmuyor.' : (e.message || 'Beklenmeyen bir hata oluştu.')),
        e.durum === 403 ? null : h('button', { class: 'btn ikincil', onclick: () => yukle() }, 'Tekrar dene')));
      return;
    }
    if (no !== istekNo) return;
    if (!liste.length) {
      govde.replaceChildren(h('div', { class: 'ku-bos' },
        h('div', { class: 'ku-bos-baslik' }, durum ? 'Eşleşen değerlendirme bulunamadı' : 'Henüz değerlendirme bulunmuyor'),
        durum ? h('div', { class: 'oz-bos' }, 'Durum süzgecini değiştirmeyi deneyin.') : null));
      return;
    }
    govde.replaceChildren(h('div', { class: 'oz-tablo-sar' }, h('table', { class: 'oz-tablo ku-tablo il-tablo dv-tablo' },
      h('thead', {}, h('tr', {}, ['Puan', 'Yorum', 'Değerlendiren', 'Hizmet veren', 'İlgili iş', 'Durum', 'Tarih', ''].map((b) => h('th', {}, b)))),
      h('tbody', {}, liste.map(satir)))));
    altBilgi.replaceChildren(h('span', { class: 'oz-bos' },
      liste.length >= SINIR
        ? `En yeni ${SINIR} değerlendirme listeleniyor. Daha eskileri ilgili kullanıcının detayından görülebilir.`
        : `${liste.length.toLocaleString('tr-TR')} değerlendirme listeleniyor.`));
  }

  sekmeleriCiz();
  await yukle();

  return h('div', { class: 'oz ku il dv' },
    h('div', { class: 'oz-baslik' },
      h('div', {}, h('h2', {}, 'Değerlendirmeler'), h('p', {}, 'Hizmet alanların tamamlanan işler için verdiği puan ve yorumlar; uygunsuz olanları gerekçeyle kaldırın'))),
    h('section', { class: 'oz-kart' },
      h('div', { class: 'ku-arac' }, sekmeler),
      govde,
      altBilgi));
}
