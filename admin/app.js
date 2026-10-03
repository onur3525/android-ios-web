// ═══════════════════════════════════════════════════════════════
// HizmetCep Yönetim — SAYFALAR
// Ücretsiz model: ödeme/komisyon/abonelik/onay/reklam modülü YOKTUR.
// ═══════════════════════════════════════════════════════════════
import {
  ApiHata, alanlarListesi, api, bildir, bilgiPenceresi, form, gerekceIle, guvenli, h,
  oturumDusunce, rozet, tablo, tarih,
} from './cekirdek.js';
import { ozetSayfasi } from './ozet.js';
import { kullanicilarSayfasi } from './kullanicilar.js';
import { kullaniciDetaySayfasi } from './kullanici_detay.js';
import { ilanlarSayfasi } from './ilanlar.js';
import { tekliflerSayfasi } from './teklifler.js';
import { teklifTalepleriSayfasi } from './teklif_talepleri.js';
import { degerlendirmelerSayfasi } from './degerlendirmeler.js';
import { katalogSayfasi } from './katalog.js';

const kok = document.getElementById('kok');
let ben = null;

const MENU = [
  ['ozet', 'Özet', ['super_admin', 'moderator', 'readonly']],
  ['kullanicilar', 'Kullanıcılar', ['super_admin', 'moderator', 'readonly']],
  ['ilanlar', 'İlanlar', ['super_admin', 'moderator', 'readonly']],
  ['teklifler', 'Teklifler', ['super_admin', 'moderator', 'readonly']],
  ['talepler', 'Teklif Talepleri', ['super_admin', 'moderator', 'readonly']],
  ['yorumlar', 'Değerlendirmeler', ['super_admin', 'moderator', 'readonly']],
  ['katalog', 'Kategori ve Hizmetler', ['super_admin', 'content', 'moderator', 'operations', 'readonly']],
  ['bolgeler', 'İl / İlçe / Mahalle', ['super_admin', 'content', 'moderator', 'operations', 'readonly']],
  ['yasal', 'Yasal Belgeler', ['super_admin', 'content', 'readonly']],
  ['destek', 'Destek Bilgisi', ['super_admin', 'content', 'readonly']],
  ['duyurular', 'Duyurular', ['super_admin', 'content']],
  ['ayarlar', 'Uygulama Ayarları', ['super_admin', 'operations', 'readonly']],
  ['gonderimler', 'SMS / E-posta Kayıtları', ['super_admin', 'moderator', 'operations']],
  ['hesaptalepleri', 'Gelen Talepler', ['super_admin', 'moderator', 'readonly']],
  ['geribildirim', 'Uygulama Geri Bildirimleri', ['super_admin', 'moderator', 'readonly']],
  ['entegrasyonlar', 'Entegrasyonlar', ['super_admin', 'operations']],
  ['yoneticiler', 'Yöneticiler', ['super_admin']],
  ['denetim', 'Denetim Kaydı', ['super_admin']],
];
const DURUM_TR = { ACTIVE: 'Aktif', SUSPENDED: 'Askıda', BANNED: 'Banlı' };

// ── Giriş ─────────────────────────────────────────────────────
function girisEkrani() {
  const email = h('input', { type: 'email', class: 'genis', autocomplete: 'username', placeholder: 'E-posta' });
  const sifre = h('input', { type: 'password', class: 'genis', autocomplete: 'current-password', placeholder: 'Şifre' });
  const kod = h('input', { class: 'genis', inputmode: 'numeric', autocomplete: 'one-time-code', placeholder: '6 haneli kod' });
  const hata = h('div', { class: 'hata' });
  const adim2 = h('div', { hidden: true }, h('p', { class: 'not' }, 'Doğrulama uygulamanızdaki kodu girin.'), kod);
  let mfa = false;
  const dugme = h('button', { class: 'btn genis' }, 'Giriş');
  const gonder = async () => {
    hata.textContent = '';
    dugme.disabled = true;
    try {
      if (!mfa) {
        await api('/auth/login', { yontem: 'POST', govde: { email: email.value, password: sifre.value } });
        mfa = true;
        adim2.hidden = false;
        email.disabled = true;
        sifre.disabled = true;
        kod.focus();
      } else {
        ben = await api('/auth/mfa', { yontem: 'POST', govde: { code: kod.value.trim() } });
        location.hash = '#/ozet';
        cizim();
      }
    } catch (e) {
      hata.textContent = e.message;
    } finally {
      dugme.disabled = false;
    }
  };
  dugme.addEventListener('click', gonder);
  for (const g of [email, sifre, kod]) g.addEventListener('keydown', (e) => e.key === 'Enter' && gonder());
  // Giriş ekranında marka adı GÖSTERİLMEZ (kullanıcı kararı): nötr başlık.
  document.title = 'Yönetim Girişi';
  kok.replaceChildren(h('div', { class: 'giris' }, h('h1', {}, 'Yönetim Girişi'), email, h('br'), h('br'), sifre, adim2, hata, h('br'), dugme));
  email.focus();
}

// ── Düzen ve yönlendirme ──────────────────────────────────────
function duzen(sayfa, icerik) {
  const menu = MENU.filter(([, , roller]) => roller.includes(ben.role));
  return h('div', { class: 'duzen' },
    h('nav', { class: 'yan' },
      h('div', { class: 'marka' }, 'HizmetCep', h('small', {}, `${ben.name} · ${ben.role}`)),
      menu.map(([k, ad]) => h('a', { class: sayfa === k ? 'secili' : '', href: `#/${k}` }, ad)),
      h('div', { class: 'cikis' }, h('a', { onclick: cikis }, 'Çıkış'))),
    h('main', { class: 'icerik' }, icerik));
}

async function cikis() {
  await guvenli(() => api('/auth/logout', { yontem: 'POST', govde: {} }));
  ben = null;
  girisEkrani();
}

const SAYFALAR = {};
async function cizim() {
  if (!ben) return girisEkrani();
  document.title = 'HizmetCep Yönetim';
  const [, sayfa = 'ozet', ...param] = location.hash.replace(/^#/, '').split('/');
  const f = SAYFALAR[sayfa] ?? SAYFALAR.ozet;
  const yer = h('div', {}, h('p', { class: 'not' }, 'Yükleniyor…'));
  kok.replaceChildren(duzen(sayfa, yer));
  try {
    yer.replaceChildren(await f(...param.map(decodeURIComponent)));
  } catch (e) {
    yer.replaceChildren(h('p', { class: 'hata' }, e instanceof ApiHata && e.durum === 403 ? 'Bu sayfa için yetkiniz yok.' : e.message));
  }
}
const yenile = () => cizim();
window.addEventListener('hashchange', cizim);
oturumDusunce(() => { ben = null; girisEkrani(); });

// ── Özet ──────────────────────────────────────────────────────
// Tasarım ve veri kaynakları: ozet.js (yalnız mevcut admin API'leri).
SAYFALAR.ozet = () => ozetSayfasi();

// ── Kullanıcılar ──────────────────────────────────────────────
// Tasarım ve veri kaynakları: kullanicilar.js (yalnız mevcut admin API'leri).
SAYFALAR.kullanicilar = () => kullanicilarSayfasi();

// Tasarım ve veri kaynakları: kullanici_detay.js (yalnız mevcut admin API'leri).
SAYFALAR.kullanici = (id) => kullaniciDetaySayfasi(id, yenile);

// ── İlanlar / teklifler / talepler / yorumlar ─────────────────
// Tasarım ve veri kaynakları: ilanlar.js (yalnız mevcut admin API'leri).
SAYFALAR.ilanlar = () => ilanlarSayfasi(ben.role);

SAYFALAR.ilan = async (id) => {
  const l = await api(`/listings/${id}`);
  const kaldir = async () => {
    const neden = await gerekceIle('İlanı kaldır', 'Kaldır', 'İlan yayından kalkar, açık teklifler kapanır; ilan sahibine ilan adı ve gerekçeyle SMS/e-posta gider.');
    if (!neden) return;
    const r = await guvenli(() => api(`/listings/${id}/remove`, { yontem: 'POST', govde: { reason: neden } }));
    if (r) { bildir(`İlan kaldırıldı. Bildirim: ${r.notifications.map((n) => n.status).join(', ')}`); yenile(); }
  };
  return h('div', {},
    h('div', { class: 'ust' }, h('h2', {}, `İlan ${l.ilanNo}`), l.status !== 'ADMIN_REMOVED' ? h('button', { class: 'btn tehlike', onclick: kaldir }, 'İlanı kaldır') : null),
    h('div', { class: 'kart' }, alanlarListesi([
      ['Hizmet', l.title], ['Konum', l.location], ['Açıklama', l.description], ['Durum', rozet(l.status)],
      ['Sahip', h('a', { href: `#/kullanici/${l.owner.id}` }, `${l.owner.name} (${l.owner.status})`)],
      ['Fotoğraf', l.photoPaths.length ? `${l.photoPaths.length} adet` : 'yok'], ['Oluşturma', tarih(l.createdAt)], ['Bitiş', tarih(l.expiresAt)],
      ['Kaldırma gerekçesi', l.removedReason], ['Sahibin silme nedeni', l.deleteReason],
    ])),
    h('h3', {}, 'Teklifler'),
    tablo([{ baslik: 'Hizmet veren', deger: (o) => h('a', { href: `#/kullanici/${o.providerId}` }, o.providerName) },
      { baslik: 'Tutar (TL)', deger: (o) => o.amountTl }, { baslik: 'Not', deger: (o) => o.note }, { baslik: 'Durum', deger: (o) => rozet(o.status) },
      { baslik: 'Sohbet', deger: (o) => h('a', { href: `#/sohbet/${o.id}` }, 'görüntüle') }], l.offers),
    h('p', { class: 'not' }, 'Teklif tutarı hizmet verenin müşteriye sunduğu bedeldir; HizmetCep ücret almaz.'),
    l.review ? h('div', { class: 'kart' }, h('h3', {}, 'Değerlendirme'), alanlarListesi([['Puan', l.review.stars], ['Yorum', l.review.text], ['Durum', rozet(l.review.status)]])) : null);
};

SAYFALAR.sohbet = async (offerId) => {
  const m = await api(`/chats/${offerId}/messages`);
  return h('div', {}, h('h2', {}, 'Sohbet (salt okunur)'), h('p', { class: 'not' }, 'Bu görüntüleme denetim kaydına yazıldı.'),
    m.length ? m.map((x) => h('div', { class: 'mesaj' }, h('div', { class: 'ust' }, h('span', {}, x.senderId), h('span', {}, tarih(x.createdAt))), x.text ?? '[görsel]')) : h('p', { class: 'not' }, 'Mesaj yok.'));
};

// Tasarım ve veri kaynakları: teklifler.js (yalnız mevcut admin API'leri).
SAYFALAR.teklifler = () => tekliflerSayfasi(ben.role);

// Tasarım ve veri kaynakları: teklif_talepleri.js (yalnız mevcut admin API'leri).
SAYFALAR.talepler = () => teklifTalepleriSayfasi(ben.role);

SAYFALAR.talep = async (id) => {
  const t = await api(`/teklif-talepleri/${id}`);
  return h('div', {}, h('h2', {}, `Talep ${t.talepNo}`), h('p', { class: 'not' }, 'Bu görüntüleme denetim kaydına yazıldı.'),
    h('div', { class: 'kart' }, alanlarListesi([
      ['Talep eden', h('a', { href: `#/kullanici/${t.hizmetAlanId}` }, 'profil')], ['Hizmet veren', h('a', { href: `#/kullanici/${t.saglayiciId}` }, t.saglayiciAdi)],
      ['Kategori / hizmet', `${t.kategori} / ${t.hizmet}`], ['Açıklama', t.aciklama], ['İletişim tercihi', t.iletisimTercihi],
      ['Durum', rozet(t.durum)], ['Teklif', t.teklifFiyati ? `${t.teklifFiyati} TL — ${t.teklifAciklamasi ?? ''}` : '—'],
      ['Red gerekçesi', t.redGerekcesi], ['Fotoğraf', `${t.fotograflar.length} adet`], ['Tarih', tarih(t.createdAt)],
    ])),
    h('h3', {}, 'Mesajlar'),
    t.mesajlar.length ? t.mesajlar.map((m) => h('div', { class: 'mesaj' }, h('div', { class: 'ust' }, h('span', {}, m.gonderenId === t.hizmetAlanId ? 'Talep eden' : 'Hizmet veren'), h('span', {}, tarih(m.createdAt))), m.metin ?? '[görsel]')) : h('p', { class: 'not' }, 'Mesaj yok.'));
};

// Tasarım ve veri kaynakları: degerlendirmeler.js (yalnız mevcut admin API'leri).
SAYFALAR.yorumlar = () => degerlendirmelerSayfasi(ben.role);

// ── Katalog ───────────────────────────────────────────────────
// Tasarım ve veri kaynakları: katalog.js (yalnız mevcut admin katalog API'leri).
SAYFALAR.katalog = () => katalogSayfasi(ben.role);

SAYFALAR.kategori = async (id) => {
  const yazabilir = ['super_admin', 'content'].includes(ben.role);
  const kat = (await api('/catalog/categories')).find((k) => k.id === id);
  if (!kat) return h('p', { class: 'hata' }, 'Kategori bulunamadı');
  const hizmetler = await api(`/catalog/categories/${id}/services`);
  const tumKat = await api('/catalog/categories');
  const ikonlar = await api('/catalog/icons');
  const duzenle = async () => {
    const d = await form('Kategoriyi düzenle', [
      { ad: 'name', etiket: 'Ad', deger: kat.name, zorunlu: true }, { ad: 'sort', etiket: 'Sıra', tur: 'number', deger: kat.sort },
      { ad: 'icon', etiket: 'İkon (uygulamada bulunan ikonlar)', tur: 'select', deger: kat.icon ?? '', secenekler: [['', '— genel ikon —'], ...ikonlar.map((i) => [i, i.split('/').pop()])] },
      { ad: 'active', etiket: 'Aktif', tur: 'checkbox', deger: kat.active },
      { ad: 'kartDisi', etiket: 'Ana sayfa ızgarasında gösterme', tur: 'checkbox', deger: kat.kartDisi },
    ]);
    if (!d) return;
    const govde = { name: d.name, sort: d.sort, active: d.active, kartDisi: d.kartDisi, icon: d.icon || null };
    if (await guvenli(() => api(`/catalog/categories/${id}`, { yontem: 'PATCH', govde }))) { bildir('Kaydedildi'); yenile(); }
  };
  const sil = async () => {
    const n = await gerekceIle('Kategoriyi kaldır', 'Kaldır', 'Kategori ve bütün hizmetleri uygulamadan kalkar. Geçmiş ilanlar etkilenmez.');
    if (n && await guvenli(() => api(`/catalog/categories/${id}`, { yontem: 'DELETE', govde: { reason: n } }))) { bildir('Kaldırıldı'); location.hash = '#/katalog'; }
  };
  const hizmetEkle = async () => {
    const d = await form('Hizmet ekle', [{ ad: 'name', etiket: 'Hizmet adı', zorunlu: true }]);
    if (d && await guvenli(() => api(`/catalog/categories/${id}/services`, { yontem: 'POST', govde: { name: d.name } }))) { bildir('Eklendi'); yenile(); }
  };
  const hizmetDuzenle = async (s) => {
    const d = await form('Hizmeti düzenle', [
      { ad: 'name', etiket: 'Ad', deger: s.name, zorunlu: true }, { ad: 'sort', etiket: 'Sıra', tur: 'number', deger: s.sort },
      { ad: 'active', etiket: 'Aktif', tur: 'checkbox', deger: s.active }, { ad: 'lider', etiket: 'Aramada öne çıkar', tur: 'checkbox', deger: s.lider },
      { ad: 'categoryId', etiket: 'Kategori (taşı)', tur: 'select', deger: id, secenekler: tumKat.map((k) => [k.id, k.name]) },
    ]);
    if (!d) return;
    const govde = { name: d.name, sort: d.sort, active: d.active, lider: d.lider, ...(d.categoryId !== id ? { categoryId: d.categoryId } : {}) };
    if (await guvenli(() => api(`/catalog/services/${s.id}`, { yontem: 'PATCH', govde }))) { bildir('Kaydedildi'); yenile(); }
  };
  const hizmetSil = async (s) => {
    const n = await gerekceIle(`"${s.name}" hizmetini kaldır`, 'Kaldır');
    if (n && await guvenli(() => api(`/catalog/services/${s.id}`, { yontem: 'DELETE', govde: { reason: n } }))) { bildir('Kaldırıldı'); yenile(); }
  };
  return h('div', {},
    h('div', { class: 'ust' }, h('h2', {}, kat.name), yazabilir ? h('div', { class: 'arac' },
      h('button', { class: 'btn ikincil', onclick: duzenle }, 'Düzenle'), h('button', { class: 'btn', onclick: hizmetEkle }, 'Hizmet ekle'),
      h('button', { class: 'btn tehlike', onclick: sil }, 'Kategoriyi kaldır')) : null),
    h('div', { class: 'kart' }, alanlarListesi([['Durum', rozet(kat.active ? 'aktif' : 'pasif')], ['Sıra', kat.sort], ['İkon', kat.icon], ['Fotoğraf', kat.photo]])),
    tablo([
      { baslik: 'Sıra', deger: (s) => s.sort }, { baslik: 'Hizmet', deger: (s) => s.name },
      { baslik: 'Durum', deger: (s) => rozet(s.active ? 'aktif' : 'pasif') }, { baslik: 'Öne çıkan', deger: (s) => (s.lider ? 'Evet' : '') },
      { baslik: '', deger: (s) => (yazabilir ? h('span', {}, h('button', { class: 'btn ikincil', onclick: () => hizmetDuzenle(s) }, 'Düzenle'), ' ', h('button', { class: 'btn tehlike', onclick: () => hizmetSil(s) }, 'Kaldır')) : '') },
    ], hizmetler));
};

// ── Bölgeler ──────────────────────────────────────────────────
SAYFALAR.bolgeler = async (tur = 'cities', ustId = '', ustAd = '') => {
  const yazabilir = ['super_admin', 'content'].includes(ben.role);
  const TUR = {
    cities: { baslik: 'İller', alt: 'districts', param: null },
    districts: { baslik: `${ustAd} — İlçeler`, alt: 'neighborhoods', param: 'cityId' },
    neighborhoods: { baslik: `${ustAd} — Mahalleler`, alt: null, param: 'districtId' },
  }[tur];
  const liste = await api(`/regions/${tur}${TUR.param ? `?${TUR.param}=${encodeURIComponent(ustId)}` : ''}`);
  const ekle = async () => {
    const alanlar = [{ ad: 'name', etiket: 'Ad', zorunlu: true }];
    if (tur === 'neighborhoods') alanlar.push({ ad: 'postalCode', etiket: 'Posta kodu (isteğe bağlı)', desen: '^\\d{5}$' });
    const d = await form('Ekle', alanlar);
    if (d && await guvenli(() => api(`/regions/${tur}`, { yontem: 'POST', govde: { ...d, ...(TUR.param ? { [TUR.param]: ustId } : {}) } }))) { bildir('Eklendi'); yenile(); }
  };
  const duzenle = async (x) => {
    const alanlar = [{ ad: 'name', etiket: 'Ad', deger: x.name, zorunlu: true }, { ad: 'active', etiket: 'Aktif (seçilebilir)', tur: 'checkbox', deger: x.active }];
    if (tur === 'neighborhoods') alanlar.push({ ad: 'postalCode', etiket: 'Posta kodu', deger: x.postalCode ?? '', desen: '^\\d{5}$' });
    const d = await form('Düzenle', alanlar);
    if (d && await guvenli(() => api(`/regions/${tur}/${x.id}`, { yontem: 'PATCH', govde: { ...d, ...(tur === 'neighborhoods' ? { postalCode: d.postalCode || null } : {}) } }))) { bildir('Kaydedildi'); yenile(); }
  };
  const sil = async (x) => {
    const n = await gerekceIle(`"${x.name}" kaldırılsın mı?`, 'Kaldır', tur !== 'neighborhoods' ? 'Alt bölgeleri de kaldırılır.' : undefined);
    if (n && await guvenli(() => api(`/regions/${tur}/${x.id}`, { yontem: 'DELETE', govde: { reason: n } }))) { bildir('Kaldırıldı'); yenile(); }
  };
  return h('div', {},
    h('div', { class: 'ust' }, h('h2', {}, TUR.baslik), h('div', { class: 'arac' },
      tur !== 'cities' ? h('a', { class: 'btn ikincil', href: '#/bolgeler' }, 'İllere dön') : null,
      yazabilir ? h('button', { class: 'btn', onclick: ekle }, 'Ekle') : null)),
    h('p', { class: 'not' }, `${liste.length} kayıt. Pasif bölge adres ve hizmet bölgesi seçiminde görünmez.`),
    tablo([
      { baslik: 'Ad', deger: (x) => (TUR.alt ? h('a', { href: `#/bolgeler/${TUR.alt}/${x.id}/${encodeURIComponent(x.name)}` }, x.name) : x.name) },
      ...(tur === 'neighborhoods' ? [{ baslik: 'Posta kodu', deger: (x) => x.postalCode ?? '—' }] : []),
      { baslik: 'Durum', deger: (x) => rozet(x.active ? 'aktif' : 'pasif') },
      { baslik: '', deger: (x) => (yazabilir ? h('span', {}, h('button', { class: 'btn ikincil', onclick: () => duzenle(x) }, 'Düzenle'), ' ', h('button', { class: 'btn tehlike', onclick: () => sil(x) }, 'Kaldır')) : '') },
    ], liste));
};

// ── Yasal belgeler ────────────────────────────────────────────
SAYFALAR.yasal = async () => {
  const yazabilir = ['super_admin', 'content'].includes(ben.role);
  const belgeler = await api('/legal');
  const yeni = async () => {
    const d = await form('Yeni belge', [{ ad: 'slug', etiket: 'Kimlik (küçük harf, ör. acik-riza)', zorunlu: true, desen: '^[a-z][a-z0-9-]{1,40}$' },
      { ad: 'title', etiket: 'Başlık', zorunlu: true }, { ad: 'requiresAcceptance', etiket: 'Kullanıcı kabulü gerektirir', tur: 'checkbox' }]);
    if (d && await guvenli(() => api('/legal', { yontem: 'POST', govde: d }))) { bildir('Belge oluşturuldu'); yenile(); }
  };
  return h('div', {}, h('div', { class: 'ust' }, h('h2', {}, 'Yasal Belgeler'), yazabilir ? h('button', { class: 'btn', onclick: yeni }, 'Yeni belge') : null),
    h('p', { class: 'not' }, 'Yeni sürüm yayınlandığında, kabul gerektiren belgeler kullanıcıya uygulamayı bir sonraki açışında gösterilir. Eski sürümler silinmez, arşivlenir.'),
    tablo([{ baslik: 'Belge', deger: (b) => b.title }, { baslik: 'Kimlik', deger: (b) => b.slug },
      { baslik: 'Yayındaki sürüm', deger: (b) => b.publishedVersion ?? '—' }, { baslik: 'Kabul ister', deger: (b) => (b.requiresAcceptance ? 'Evet' : 'Hayır') },
      { baslik: 'Durum', deger: (b) => rozet(b.active ? 'aktif' : 'pasif') }], belgeler, (b) => (location.hash = `#/belge/${b.slug}`)));
};

SAYFALAR.belge = async (slug) => {
  const yazabilir = ['super_admin', 'content'].includes(ben.role);
  const b = (await api('/legal')).find((x) => x.slug === slug);
  const surumler = await api(`/legal/${slug}/versions`);
  const yeniSurum = async () => {
    const d = await form('Yeni sürüm (taslak)', [{ ad: 'body', etiket: 'Belge metni', tur: 'textarea', zorunlu: true }, { ad: 'effectiveDate', etiket: 'Yürürlük tarihi (YYYY-AA-GG, boş = bugün)', desen: '^\\d{4}-\\d{2}-\\d{2}$' }]);
    if (d && await guvenli(() => api(`/legal/${slug}/versions`, { yontem: 'POST', govde: { body: d.body, ...(d.effectiveDate ? { effectiveDate: d.effectiveDate } : {}) } }))) { bildir('Taslak oluşturuldu'); yenile(); }
  };
  const ayar = async () => {
    const d = await form('Belge ayarları', [{ ad: 'title', etiket: 'Başlık', deger: b.title, zorunlu: true }, { ad: 'requiresAcceptance', etiket: 'Kullanıcı kabulü gerektirir', tur: 'checkbox', deger: b.requiresAcceptance }, { ad: 'active', etiket: 'Aktif', tur: 'checkbox', deger: b.active }]);
    if (d && await guvenli(() => api(`/legal/${slug}`, { yontem: 'PATCH', govde: d }))) { bildir('Kaydedildi'); yenile(); }
  };
  const goster = async (v) => {
    const x = await guvenli(() => api(`/legal/${slug}/versions/${v.version}`));
    if (x) bilgiPenceresi(`${b.title} — sürüm ${x.version}`, h('p', { class: 'not' }, `SHA-256: ${x.sha256}`), h('pre', { class: 'govde' }, x.body));
  };
  const yayinla = async (v) => {
    if (!(await form(`Sürüm ${v.version} yayınlansın mı?`, [], 'Yayınla', { aciklama: 'Yayındaki sürüm arşive alınır; kabul gerektiren belgede kullanıcılar yeni sürümü onaylamadan devam edemez.' }))) return;
    if (await guvenli(() => api(`/legal/${slug}/versions/${v.version}/publish`, { yontem: 'POST', govde: {} }))) { bildir('Yayınlandı'); yenile(); }
  };
  const arsivle = async (v) => {
    const n = await gerekceIle(`Sürüm ${v.version} pasife alınsın mı?`, 'Pasife al');
    if (n && await guvenli(() => api(`/legal/${slug}/versions/${v.version}/archive`, { yontem: 'POST', govde: { reason: n } }))) { bildir('Arşivlendi'); yenile(); }
  };
  return h('div', {}, h('div', { class: 'ust' }, h('h2', {}, b?.title ?? slug), yazabilir ? h('div', { class: 'arac' },
    h('button', { class: 'btn ikincil', onclick: ayar }, 'Ayarlar'), h('button', { class: 'btn', onclick: yeniSurum }, 'Yeni sürüm')) : null),
  tablo([{ baslik: 'Sürüm', deger: (v) => v.version }, { baslik: 'Durum', deger: (v) => rozet(v.status) },
    { baslik: 'Yürürlük', deger: (v) => v.effectiveDate }, { baslik: 'Yayın', deger: (v) => tarih(v.publishedAt) },
    { baslik: '', deger: (v) => h('span', {}, h('button', { class: 'btn ikincil', onclick: () => goster(v) }, 'Metni gör'),
      yazabilir && v.status === 'DRAFT' ? [' ', h('button', { class: 'btn', onclick: () => yayinla(v) }, 'Yayınla')] : null,
      yazabilir && v.status !== 'ARCHIVED' ? [' ', h('button', { class: 'btn tehlike', onclick: () => arsivle(v) }, 'Pasife al')] : null) }], surumler));
};

// ── Destek / ayarlar / duyurular ──────────────────────────────
SAYFALAR.destek = async () => {
  const d = await api('/support');
  const ac = h('textarea', {}, d?.description ?? '');
  const ep = h('input', { class: 'genis', type: 'email', value: d?.email ?? '' });
  const kaydet = async () => { if (await guvenli(() => api('/support', { yontem: 'PUT', govde: { description: ac.value, email: ep.value } }))) bildir('Kaydedildi'); };
  return h('div', {}, h('h2', {}, 'Destek Bilgisi'), h('div', { class: 'kart' },
    h('p', { class: 'not' }, 'Uygulamadaki Destek Merkezi panelinde ve kullanıcıya giden SMS/e-postalardaki iletişim satırında kullanılır.'),
    h('label', {}, 'Açıklama'), ac, h('label', {}, 'Destek e-postası'), ep, h('br'), h('br'), h('button', { class: 'btn', onclick: kaydet }, 'Kaydet')));
};

SAYFALAR.ayarlar = async () => {
  const yazabilir = ['super_admin', 'operations'].includes(ben.role);
  const liste = await api('/config/app');
  const kart = (c) => {
    const bakim = h('input', { type: 'checkbox', ...(c.maintenanceActive ? { checked: true } : {}) });
    const mesaj = h('input', { class: 'genis', value: c.maintenanceMessage ?? '' });
    const bitis = h('input', { class: 'genis', type: 'datetime-local', value: c.maintenanceEndAt ? c.maintenanceEndAt.slice(0, 16) : '' });
    const min = h('input', { class: 'genis', placeholder: '1.0.0', value: c.minSupportedVersion ?? '' });
    const gun = h('input', { class: 'genis', placeholder: '1.0.0', value: c.latestVersion ?? '' });
    const kaydet = async () => {
      const govde = { maintenanceActive: bakim.checked, maintenanceMessage: mesaj.value || null, maintenanceEndAt: bitis.value ? new Date(bitis.value).toISOString() : null, minSupportedVersion: min.value || null, latestVersion: gun.value || null };
      if (await guvenli(() => api(`/config/app/${c.platform}`, { yontem: 'PUT', govde }))) bildir(`${c.platform} kaydedildi`);
    };
    return h('div', { class: 'kart' }, h('h3', {}, { android: 'Android', ios: 'iOS', web: 'Web' }[c.platform]),
      h('label', {}, bakim, ' Bakım modu'), h('label', {}, 'Bakım mesajı'), mesaj, h('label', {}, 'Bakım bitiş zamanı'), bitis,
      h('label', {}, 'En düşük desteklenen sürüm'), min, h('label', {}, 'Güncel sürüm'), gun, h('br'), h('br'),
      yazabilir ? h('button', { class: 'btn', onclick: kaydet }, 'Kaydet') : null, h('p', { class: 'not' }, `Son güncelleme: ${tarih(c.updatedAt)}`));
  };
  return h('div', {}, h('h2', {}, 'Uygulama Ayarları'), liste.map(kart));
};

SAYFALAR.duyurular = async () => {
  const gecmis = await api('/announcements');
  const gonder = async () => {
    const d = await form('Duyuru gönder', [{ ad: 'title', etiket: 'Başlık', zorunlu: true }, { ad: 'body', etiket: 'Metin', tur: 'textarea', zorunlu: true },
      { ad: 'target', etiket: 'Hedef', tur: 'select', deger: 'ALL', secenekler: [['ALL', 'Herkes'], ['CUSTOMER', 'Hizmet alanlar'], ['PROVIDER', 'Hizmet verenler']] }], 'Gönder');
    const r = d && await guvenli(() => api('/announcements', { yontem: 'POST', govde: d }));
    if (r) { bildir(`${r.recipients} kullanıcıya gönderildi`); yenile(); }
  };
  return h('div', {}, h('div', { class: 'ust' }, h('h2', {}, 'Duyurular'), h('button', { class: 'btn', onclick: gonder }, 'Duyuru gönder')),
    h('p', { class: 'not' }, 'Duyurular uygulamadaki Bildirimler sekmesine düşer; yalnız etkin hesaplara gider.'),
    tablo([{ baslik: 'Başlık', deger: (a) => a.title }, { baslik: 'Hedef', deger: (a) => a.target }, { baslik: 'Alıcı', deger: (a) => a.recipients }, { baslik: 'Tarih', deger: (a) => tarih(a.createdAt) }], gecmis));
};

// ── Kayıt listeleri ───────────────────────────────────────────
SAYFALAR.gonderimler = async () => h('div', {}, h('h2', {}, 'SMS / E-posta Kayıtları'), h('p', { class: 'not' }, 'Doğrulama kodları (OTP) burada listelenmez.'),
  tablo([{ baslik: 'Kanal', deger: (m) => m.channel }, { baslik: 'Hedef', deger: (m) => m.target }, { baslik: 'Şablon', deger: (m) => m.template },
    { baslik: 'Durum', deger: (m) => rozet(m.status) }, { baslik: 'Sağlayıcı yanıtı', deger: (m) => m.providerResponse ?? '—' }, { baslik: 'Tarih', deger: (m) => tarih(m.createdAt) }],
  await api('/notifications/outbound'), (m) => m.userId && (location.hash = `#/kullanici/${m.userId}`)));

SAYFALAR.hesaptalepleri = async () => h('div', {}, h('h2', {}, 'Gelen Talepler'), h('p', { class: 'not' }, 'Silme talepleri 30 gün sonra otomatik uygulanır: kişisel veri anonimleştirilir.'),
  tablo([{ baslik: 'Kullanıcı', deger: (a) => a.name }, { baslik: 'Tür', deger: (a) => (a.type === 'FREEZE' ? 'Dondurma' : 'Silme') },
    { baslik: 'Durum', deger: (a) => rozet(a.status) }, { baslik: 'Talep', deger: (a) => tarih(a.createdAt) }, { baslik: 'Planlanan', deger: (a) => tarih(a.scheduledFor) }],
  await api('/account-requests'), (a) => (location.hash = `#/kullanici/${a.userId}`)));

SAYFALAR.geribildirim = async () => h('div', {}, h('h2', {}, 'Uygulama Geri Bildirimleri'), tablo([
  { baslik: 'Kullanıcı', deger: (f) => f.name }, { baslik: 'Puan', deger: (f) => f.stars }, { baslik: 'Yorum', deger: (f) => f.comment ?? '—' },
  { baslik: 'Platform', deger: (f) => `${f.platform} ${f.appVersion}` }, { baslik: 'Tarih', deger: (f) => tarih(f.updatedAt) },
], await api('/feedback'), (f) => (location.hash = `#/kullanici/${f.userId}`)));

SAYFALAR.denetim = async () => h('div', {}, h('h2', {}, 'Denetim Kaydı'), h('p', { class: 'not' }, 'Kayıtlar değiştirilemez ve silinemez.'),
  tablo([{ baslik: 'Tarih', deger: (x) => tarih(x.createdAt) }, { baslik: 'Admin', deger: (x) => x.admin ?? 'sistem' }, { baslik: 'İşlem', deger: (x) => x.action },
    { baslik: 'Hedef', deger: (x) => `${x.targetType ?? ''} ${x.targetId ?? ''}` }, { baslik: 'Gerekçe', deger: (x) => x.reason ?? '—' },
    { baslik: 'Değişiklik', deger: (x) => (x.before || x.after ? `${JSON.stringify(x.before)} → ${JSON.stringify(x.after)}` : '—') }], await api('/audit-log?limit=300')));

// ── Entegrasyonlar ────────────────────────────────────────────
SAYFALAR.entegrasyonlar = async () => {
  const liste = await api('/integrations');
  const superMi = ben.role === 'super_admin';
  const ekle = async () => {
    const d = await form('Entegrasyon ekle', [
      { ad: 'type', etiket: 'Tür', tur: 'select', deger: 'SMS', secenekler: [['SMS', 'SMS (HTTPS köprü)'], ['EMAIL', 'E-posta (HTTPS köprü)'], ['STORAGE', 'Dosya depolama (S3 uyumlu)']] },
      { ad: 'url', etiket: 'SMS/E-posta: köprü adresi (https)' }, { ad: 'endpoint', etiket: 'Depolama: uç nokta (https)' },
      { ad: 'bucket', etiket: 'Depolama: kova' }, { ad: 'region', etiket: 'Depolama: bölge (ör. auto, eu-central-1)' }], 'Ekle');
    if (!d) return;
    const govde = d.type === 'STORAGE'
      ? { type: 'STORAGE', provider: 's3', config: { endpoint: d.endpoint, bucket: d.bucket, region: d.region } }
      : { type: d.type, provider: 'webhook', config: { url: d.url } };
    if (await guvenli(() => api('/integrations', { yontem: 'POST', govde }))) { bildir('Eklendi (pasif). Gizli anahtarı girip etkinleştirin.'); yenile(); }
  };
  const sir = async (x) => {
    const alanlar = x.type === 'STORAGE'
      ? [{ ad: 'accessKeyId', etiket: 'Erişim anahtarı kimliği', tur: 'password', zorunlu: true }, { ad: 'secretAccessKey', etiket: 'Gizli erişim anahtarı', tur: 'password', zorunlu: true }]
      : [{ ad: 'token', etiket: 'Köprü anahtarı (Bearer)', tur: 'password', zorunlu: true }];
    const d = await form('Gizli anahtarı değiştir', alanlar, 'Kaydet', { aciklama: 'Değer şifreli saklanır ve bir daha gösterilmez.' });
    if (d && await guvenli(() => api(`/integrations/${x.id}/secret`, { yontem: 'PUT', govde: d }))) { bildir('Kaydedildi'); yenile(); }
  };
  const etkin = async (x) => { if (await guvenli(() => api(`/integrations/${x.id}`, { yontem: 'PATCH', govde: { active: !x.active } }))) { bildir('Güncellendi'); yenile(); } };
  const test = async (x) => { const r = await guvenli(() => api(`/integrations/${x.id}/test`, { yontem: 'POST', govde: {} })); if (r) { bildir(`${r.ok ? 'Başarılı' : 'Başarısız'}: ${r.message}`, !r.ok); yenile(); } };
  const sil = async (x) => { const n = await gerekceIle('Entegrasyonu kaldır', 'Kaldır'); if (n && await guvenli(() => api(`/integrations/${x.id}`, { yontem: 'DELETE', govde: { reason: n } }))) { bildir('Kaldırıldı'); yenile(); } };
  return h('div', {}, h('div', { class: 'ust' }, h('h2', {}, 'Entegrasyonlar'), h('button', { class: 'btn', onclick: ekle }, 'Ekle')),
    h('p', { class: 'not' }, 'Gizli anahtarlar yalnız sunucuda, şifreli saklanır; bu panele asla geri gelmez. Her türde aynı anda tek sağlayıcı etkindir.'),
    tablo([{ baslik: 'Tür', deger: (x) => x.type }, { baslik: 'Sağlayıcı', deger: (x) => x.provider },
      { baslik: 'Ayar', deger: (x) => JSON.stringify(x.config) }, { baslik: 'Anahtar', deger: (x) => (x.secretSet ? x.secretHint : 'girilmedi') },
      { baslik: 'Durum', deger: (x) => rozet(x.active ? 'aktif' : 'pasif') },
      { baslik: 'Son test', deger: (x) => (x.lastTestAt ? `${x.lastTestOk ? '✓' : '✗'} ${x.lastTestMessage}` : '—') },
      { baslik: '', deger: (x) => h('span', {}, superMi ? h('button', { class: 'btn ikincil', onclick: () => sir(x) }, 'Anahtar') : null, ' ',
        h('button', { class: 'btn ikincil', onclick: () => test(x) }, 'Test'), ' ', h('button', { class: 'btn', onclick: () => etkin(x) }, x.active ? 'Pasifleştir' : 'Etkinleştir'), ' ',
        h('button', { class: 'btn tehlike', onclick: () => sil(x) }, 'Kaldır')) }], liste));
};

// ── Yöneticiler ───────────────────────────────────────────────
const ROL_TR = [['super_admin', 'Süper yönetici'], ['moderator', 'Moderatör'], ['content', 'İçerik yöneticisi'], ['operations', 'Operasyon'], ['readonly', 'Salt okunur']];
SAYFALAR.yoneticiler = async () => {
  const liste = await api('/admins');
  const ekle = async () => {
    const d = await form('Yönetici ekle', [{ ad: 'email', etiket: 'E-posta', tur: 'email', zorunlu: true }, { ad: 'name', etiket: 'Ad soyad', zorunlu: true },
      { ad: 'role', etiket: 'Rol', tur: 'select', deger: 'readonly', secenekler: ROL_TR }, { ad: 'password', etiket: 'Geçici şifre (en az 12, harf+rakam)', tur: 'password', zorunlu: true }]);
    const r = d && await guvenli(() => api('/admins', { yontem: 'POST', govde: d }));
    if (r) {
      bilgiPenceresi('Yönetici oluşturuldu', h('p', {}, 'Aşağıdaki doğrulama anahtarını yöneticiye GÜVENLİ kanalla iletin. Bir daha gösterilmez.'),
        h('div', { class: 'sir' }, r.totpSecret), h('p', { class: 'not' }, r.otpauth));
      yenile();
    }
  };
  const duzenle = async (a) => {
    const d = await form(`${a.email}`, [{ ad: 'role', etiket: 'Rol', tur: 'select', deger: a.role, secenekler: ROL_TR }, { ad: 'active', etiket: 'Aktif', tur: 'checkbox', deger: a.active }]);
    if (d && await guvenli(() => api(`/admins/${a.id}`, { yontem: 'PATCH', govde: d }))) { bildir('Güncellendi'); yenile(); }
  };
  return h('div', {}, h('div', { class: 'ust' }, h('h2', {}, 'Yöneticiler'), h('button', { class: 'btn', onclick: ekle }, 'Yönetici ekle')),
    tablo([{ baslik: 'Ad', deger: (a) => a.name }, { baslik: 'E-posta', deger: (a) => a.email }, { baslik: 'Rol', deger: (a) => ROL_TR.find(([v]) => v === a.role)?.[1] },
      { baslik: 'MFA', deger: (a) => (a.mfa ? 'Kurulu' : 'Yok') }, { baslik: 'Durum', deger: (a) => rozet(a.active ? 'aktif' : 'pasif') }], liste, (a) => (a.id !== ben.id ? duzenle(a) : null)));
};

// ── Başlangıç ─────────────────────────────────────────────────
(async () => {
  try {
    ben = await api('/auth/me');
    cizim();
  } catch {
    girisEkrani();
  }
})();
