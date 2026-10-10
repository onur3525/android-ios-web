// ═══════════════════════════════════════════════════════════════
// TEKLİF TALEPLERİ — İlanlar/Teklifler ile aynı görsel dil (.oz .ku .il .tt)
//
// MEVCUT UÇ (backend değişmedi; demo/sahte veri YOK):
//   GET /admin/v1/teklif-talepleri?durum=&hizmetAlanId=&saglayiciId=
//     → en yeni 200 talep (DİZİ). Arama, sayfalama ve toplam YOKTUR.
//     Durumlar: BEKLEMEDE | TEKLIF_GELDI | SECILDI | REDDEDILDI | SURESI_DOLDU | TAMAMLANDI
//     Alanlar: id, talepNo, hizmetAlanId, saglayiciId, saglayiciAdi, kategori,
//              hizmet, aciklama, fotograflar, iletisimTercihi, isZamani, durum,
//              teklifFiyati, teklifAciklamasi, teklifTarihi, redGerekcesi, createdAt
//   Talep bir İLANA bağlı DEĞİLDİR (doğrudan hizmet verene gider); ilan sütunu yok.
//   Hizmet alan adı: GET /admin/v1/users?limit=200 (+ eksikler için /users/:id),
//   yalnız ad görme yetkili rollerde (İlanlar/Teklifler ile aynı kural).
//   Detay (mesajlar dahil, denetim kaydına yazılır): mevcut #/talep/:id —
//   backend messages.read yetkisi ister; yetkisiz rolde bağlantı gösterilmez.
//   Admin API'sinde talep üzerinde YÖNETİM İŞLEMİ YOKTUR.
// ═══════════════════════════════════════════════════════════════
import { api, h } from './cekirdek.js';

const SINIR = 200; // backend'in sabit üst sınırı
const DURUMLAR = [
  ['', 'Tümü'], ['BEKLEMEDE', 'Beklemede'], ['TEKLIF_GELDI', 'Teklif geldi'], ['SECILDI', 'Seçildi'],
  ['TAMAMLANDI', 'Tamamlandı'], ['REDDEDILDI', 'Reddedildi'], ['SURESI_DOLDU', 'Süresi doldu'],
];
const DURUM_ADI = Object.fromEntries(DURUMLAR.filter(([v]) => v));
const AD_GOREBILIR = ['super_admin', 'moderator']; // backend users.contact.read ile aynı
const DETAY_GOREBILIR = ['super_admin', 'moderator']; // backend messages.read ile aynı
const IS_ZAMANI = { NOW: 'Hemen', THIS_WEEK: 'Bu hafta', FLEXIBLE: 'Esnek' };

const tarihSaat = (v) => (v ? new Date(v).toLocaleString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—');
const tl = (v) => (Number.isFinite(v) ? `${v.toLocaleString('tr-TR')} TL` : null);

async function sinirli(isler, adet = 6) {
  const kuyruk = [...isler];
  await Promise.all(Array.from({ length: Math.min(adet, kuyruk.length) }, async () => {
    while (kuyruk.length) await kuyruk.shift()();
  }));
}

export async function teklifTalepleriSayfasi(rol) {
  const adGorebilir = AD_GOREBILIR.includes(rol);
  const detayGorebilir = DETAY_GOREBILIR.includes(rol);
  const kisiler = new Map(); // hizmetAlanId → ad | null

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

  async function adlariAl(talepler) {
    if (!adGorebilir) return;
    const eksik = [...new Set(talepler.map((t) => t.hizmetAlanId))].filter((x) => !kisiler.has(x));
    if (!eksik.length) return;
    const toplu = await api('/users?limit=200').catch(() => null);
    for (const u of toplu?.items ?? []) kisiler.set(u.id, u.name);
    await sinirli(eksik.filter((x) => !kisiler.has(x)).map((x) => () =>
      api(`/users/${x}`).then((u) => kisiler.set(x, u.name), () => kisiler.set(x, null))));
  }

  const kisiBag = (id, ad) => h('a', { class: 'il-sahip', href: `#/kullanici/${id}`, onclick: (e) => e.stopPropagation() },
    adGorebilir && ad ? ad : 'Kullanıcıyı aç ›');

  const satir = (t) => {
    const teklif = tl(t.teklifFiyati);
    return h('tr', {
      class: detayGorebilir ? 'tikla' : '',
      onclick: detayGorebilir ? () => (location.hash = `#/talep/${t.id}`) : null,
    },
    h('td', { 'data-baslik': 'Talep' }, h('div', { class: 'tt-talep' },
      h('div', { class: 'ku-ad' }, t.hizmet),
      h('div', { class: 'ku-eposta' }, `${t.kategori} · No: ${t.talepNo}`),
      t.isZamani ? h('span', { class: 'ku-dogrulama hayir tt-zaman' }, IS_ZAMANI[t.isZamani] ?? t.isZamani) : null)),
    h('td', { 'data-baslik': 'Hizmet alan' }, kisiBag(t.hizmetAlanId, kisiler.get(t.hizmetAlanId))),
    h('td', { 'data-baslik': 'Hizmet veren' }, kisiBag(t.saglayiciId, t.saglayiciAdi)),
    h('td', { 'data-baslik': 'Teklif' }, teklif
      ? h('div', {}, h('div', { class: 'tk-tutar' }, teklif), t.teklifTarihi ? h('div', { class: 'ku-eposta' }, tarihSaat(t.teklifTarihi)) : null)
      : h('span', { class: 'oz-bos' }, 'Teklif verilmedi')),
    h('td', { 'data-baslik': 'Durum' }, h('span', { class: `ku-durum tt-rozet ${t.durum}` }, DURUM_ADI[t.durum] ?? t.durum),
      t.redGerekcesi ? h('div', { class: 'ku-eposta il-neden', title: t.redGerekcesi }, t.redGerekcesi) : null),
    h('td', { 'data-baslik': 'Oluşturulma', class: 'ku-tarih' }, tarihSaat(t.createdAt)),
    h('td', { 'data-baslik': 'Detay', class: 'tk-baglanti' },
      detayGorebilir ? h('a', { class: 'oz-tumu', href: `#/talep/${t.id}`, onclick: (e) => e.stopPropagation() }, 'Detay ve mesajlar ›') : null));
  };

  async function yukle() {
    const no = ++istekNo;
    govde.replaceChildren(h('div', { class: 'il-yukleniyor', role: 'status' }, 'Teklif talepleri yükleniyor…'));
    altBilgi.replaceChildren();
    let liste;
    try {
      liste = await api(`/teklif-talepleri${durum ? `?durum=${durum}` : ''}`);
      await adlariAl(liste);
    } catch (e) {
      if (no !== istekNo) return;
      govde.replaceChildren(h('div', { class: 'ku-bos' },
        h('div', { class: 'ku-bos-baslik' }, e.durum === 403 ? 'Yetkiniz yok' : 'Teklif talepleri yüklenemedi'),
        h('p', { class: 'oz-bos' }, e.durum === 403 ? 'Teklif taleplerini görüntüleme yetkiniz bulunmuyor.' : (e.message || 'Beklenmeyen bir hata oluştu.')),
        e.durum === 403 ? null : h('button', { class: 'btn ikincil', onclick: () => yukle() }, 'Tekrar dene')));
      return;
    }
    if (no !== istekNo) return;
    if (!liste.length) {
      govde.replaceChildren(h('div', { class: 'ku-bos' },
        h('div', { class: 'ku-bos-baslik' }, durum ? 'Eşleşen teklif talebi bulunamadı' : 'Henüz teklif talebi bulunmuyor'),
        durum ? h('div', { class: 'oz-bos' }, 'Durum süzgecini değiştirmeyi deneyin.') : null));
      return;
    }
    govde.replaceChildren(h('div', { class: 'oz-tablo-sar' }, h('table', { class: 'oz-tablo ku-tablo il-tablo tt-tablo' },
      h('thead', {}, h('tr', {}, ['Talep', 'Hizmet alan', 'Hizmet veren', 'Teklif', 'Durum', 'Oluşturulma', ''].map((b) => h('th', {}, b)))),
      h('tbody', {}, liste.map(satir)))));
    altBilgi.replaceChildren(h('span', { class: 'oz-bos' },
      liste.length >= SINIR
        ? `En yeni ${SINIR} teklif talebi listeleniyor. Daha eskileri ilgili kullanıcının detayından görülebilir.`
        : `${liste.length.toLocaleString('tr-TR')} teklif talebi listeleniyor.`));
  }

  sekmeleriCiz();
  await yukle();

  return h('div', { class: 'oz ku il tt' },
    h('div', { class: 'oz-baslik' },
      h('div', {}, h('h2', {}, 'Teklif Talepleri'), h('p', {}, 'Hizmet alanların doğrudan hizmet verenlere gönderdiği teklif talepleri; durumlarını izleyin, taraflara ve ayrıntılara geçin'))),
    h('section', { class: 'oz-kart' },
      h('div', { class: 'ku-arac' }, sekmeler),
      govde,
      altBilgi));
}
