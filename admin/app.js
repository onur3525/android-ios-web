// ═══════════════════════════════════════════════════════════════
// HizmetCep Yönetim — SAYFALAR
// Ücretsiz model: ödeme/komisyon/abonelik/onay/reklam modülü YOKTUR.
// ═══════════════════════════════════════════════════════════════
import {
  ApiHata, alanlarListesi, api, bildir, bilgiPenceresi, form, gerekceIle, guvenli, h,
  hareketsizlikKilidi, oturumDusunce, rozet, tablo, tarih,
} from './cekirdek.js';
import { ozetSayfasi } from './ozet.js';
import { sistemSayfasi } from './sistem.js';
import { kapatmaPaneli } from './hesap_kapatma.js';
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
  ['talepler', 'Teklif Talepleri', ['super_admin', 'moderator', 'readonly']],
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
  // Özet'i olan roller Silme Kuyrukları'nı Özet içinden açar; Özet'i
  // olmayan operasyon rolü için menüde kalır.
  ['silmekuyruklari', 'Silme Kuyrukları', ['operations']],
  ['yoneticiler', 'Yöneticiler', ['super_admin']],
  ['denetim', 'Denetim Kaydı', ['super_admin']],
];
const DURUM_TR = { ACTIVE: 'Aktif', SUSPENDED: 'Askıda', BANNED: 'Banlı' };

// ── Giriş ─────────────────────────────────────────────────────
/** Giriş yapıldı: 5 dk hareketsizlikte ekran kilitlenir (süre sunucudan). */
function oturumBasladi() {
  hareketsizlikKilidi(ben?.idleTimeoutSeconds, async () => {
    ben = null;
    await api('/auth/logout', { yontem: 'POST', govde: {} }).catch(() => {}); // sunucuda zaten kapanmış olabilir
    girisEkrani('Hareketsizlik nedeniyle oturum kapandı. Yeniden giriş yapın.');
  });
}

function girisEkrani(bilgi) {
  hareketsizlikKilidi(0);
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
        oturumBasladi();
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
  kok.replaceChildren(h('div', { class: 'giris' }, h('h1', {}, 'Yönetim Girişi'),
    bilgi ? h('p', { class: 'not' }, bilgi) : null, email, h('br'), h('br'), sifre, adim2, hata, h('br'), dugme));
  email.focus();
}

// ── Düzen ve yönlendirme ──────────────────────────────────────
// ── ÖZET'İN ALT SAYFALARI (21 Eki, kullanıcı kararı) ──
// Özet kartlarının "Tümünü gör" ile açtığı sayfaların sol menüde ayrı
// düğmesi yoktur; Özet içinde açılır: menüde Özet seçili kalır, üstte
// "‹ Özet" ile geri dönülür. (Menüsünde bu sayfa olan rolde — ör. operasyon
// için Silme Kuyrukları — normal menü sayfası gibi davranır.)
const OZET_ALT_SAYFALARI = new Set(['sistem', 'kullanicilar', 'kullanici', 'ilanlar', 'ilan', 'sohbet', 'teklifler', 'silmekuyruklari', 'yorumlar']);

function duzen(sayfa, icerik) {
  const menu = MENU.filter(([, , roller]) => roller.includes(ben.role));
  const ozetAlti = OZET_ALT_SAYFALARI.has(sayfa) && menu.some(([k]) => k === 'ozet') && !menu.some(([k]) => k === sayfa);
  const secili = ozetAlti ? 'ozet' : sayfa;
  return h('div', { class: 'duzen' },
    h('nav', { class: 'yan' },
      h('div', { class: 'marka' }, 'HizmetCep', h('small', {}, `${ben.name} · ${ben.role}`)),
      menu.map(([k, ad]) => h('a', { class: secili === k ? 'secili' : '', href: `#/${k}` }, ad)),
      h('div', { class: 'cikis' }, h('a', { onclick: cikis }, 'Çıkış'))),
    h('main', { class: 'icerik' },
      // Kullanıcı detayının kendi "‹ Kullanıcılar" bağlantısı var; ikisi üst üste çıkmasın.
      ozetAlti && sayfa !== 'kullanici' ? h('a', { class: 'oz-geri', href: '#/ozet' }, '‹ Özet') : null,
      icerik));
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
oturumDusunce(() => { ben = null; girisEkrani('Oturum süresi doldu. Yeniden giriş yapın.'); });

// ── Özet ──────────────────────────────────────────────────────
// Tasarım ve veri kaynakları: ozet.js (yalnız mevcut admin API'leri).
SAYFALAR.ozet = () => ozetSayfasi();
// Özet → Sistem Durumu "Tümünü gör" (21 Eki): kartın ayrıntısı (sistem.js).
// '#/sistem/yedek': yedekleme durumu Render'dan hemen yeniden okunur (22 Eki).
SAYFALAR.sistem = (alt) => sistemSayfasi({ yedekYenile: alt === 'yedek' });

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
      ['İletişim tercihi', l.iletisimTercihi === 'yalnizMesaj' ? 'Sadece uygulama içi mesaj (telefon gizli)' : 'Telefon + uygulama içi mesaj'],
      ['Sahip', h('a', { href: `#/kullanici/${l.owner.id}` }, `${l.owner.name} (${l.owner.status})`)],
      ['Fotoğraf', l.photoPaths.length ? `${l.photoPaths.length} adet` : 'yok'], ['Oluşturma', tarih(l.createdAt)], ['Bitiş', tarih(l.expiresAt)],
      ['Kaldırma gerekçesi', l.removedReason], ['Sahibin silme nedeni', l.deleteReason],
    ])),
    h('h3', {}, 'Teklifler'),
    tablo([{ baslik: 'Hizmet veren', deger: (o) => h('a', { href: `#/kullanici/${o.providerId}` }, o.providerName) },
      { baslik: 'Tutar (TL)', deger: (o) => o.amountTl }, { baslik: 'Not', deger: (o) => o.note }, { baslik: 'Durum', deger: (o) => rozet(o.status) },
      { baslik: 'İletişim', deger: (o) => (o.contactOpenedAt
        ? `Açık — ${({ OWNER: 'hizmet alan açtı', PROVIDER: 'hizmet veren açtı' })[o.contactOpenedBy] ?? 'açıldı'} (${tarih(o.contactOpenedAt)})`
        : 'Kapalı') },
      { baslik: 'Sohbet', deger: (o) => h('a', { href: `#/sohbet/${o.id}` }, 'görüntüle') }], l.offers),
    h('p', { class: 'not' }, 'Teklif tutarı hizmet verenin müşteriye sunduğu bedeldir; HizmetCep ücret almaz.'),
    l.review ? h('div', { class: 'kart' }, h('h3', {}, 'Değerlendirme'), alanlarListesi([['Puan', l.review.stars], ['Yorum', l.review.text], ['Durum', rozet(l.review.status)]])) : null);
};

// ⚠ ÖZEL YAZIŞMA GEREKÇEYLE AÇILIR (15 Eki): sunucu `reason` ister ve
// denetim kaydına yazar. Gerekçe girilmezse içerik istenmez.
// Gerekçe adres satırında DEĞİL başlıkta gider: sunucu/proxy erişim
// günlüklerine (adres + sorgu) kişisel bilgi içerebilecek metin yazılmasın.
const gerekceBasligi = (neden) => ({ 'X-HC-Reason': encodeURIComponent(neden) });
const yazismaGerekcesi = () => gerekceIle('Yazışmayı görüntüle', 'Görüntüle',
  'Kullanıcıların özel yazışması yalnız şikâyet, güvenlik veya destek gerekçesiyle açılır. Gerekçe ve görüntüleme denetim kaydına yazılır.');

SAYFALAR.sohbet = async (offerId) => {
  const neden = await yazismaGerekcesi();
  if (!neden) return h('p', { class: 'not' }, 'Gerekçe girilmediği için yazışma açılmadı.');
  const m = await api(`/chats/${offerId}/messages`, { basliklar: gerekceBasligi(neden) });
  return h('div', {}, h('h2', {}, 'Sohbet (salt okunur)'), h('p', { class: 'not' }, 'Bu görüntüleme denetim kaydına yazıldı.'),
    m.length ? m.map((x) => h('div', { class: 'mesaj' }, h('div', { class: 'ust' }, h('span', {}, x.senderId), h('span', {}, tarih(x.createdAt))), x.text ?? '[görsel]')) : h('p', { class: 'not' }, 'Mesaj yok.'));
};

// Tasarım ve veri kaynakları: teklifler.js (yalnız mevcut admin API'leri).
SAYFALAR.teklifler = () => tekliflerSayfasi(ben.role);

// Tasarım ve veri kaynakları: teklif_talepleri.js (yalnız mevcut admin API'leri).
SAYFALAR.talepler = () => teklifTalepleriSayfasi(ben.role);

SAYFALAR.talep = async (id) => {
  const neden = await yazismaGerekcesi();
  if (!neden) return h('p', { class: 'not' }, 'Gerekçe girilmediği için talep açılmadı.');
  const t = await api(`/teklif-talepleri/${id}`, { basliklar: gerekceBasligi(neden) });
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
  const yazabilir = ['super_admin', 'content'].includes(ben.role); // sunucu: support.write
  const d = await api('/support');
  const ac = h('textarea', {}, d?.description ?? '');
  const ep = h('input', { class: 'genis', type: 'email', value: d?.email ?? '' });
  const kaydet = async () => { if (await guvenli(() => api('/support', { yontem: 'PUT', govde: { description: ac.value, email: ep.value } }))) bildir('Kaydedildi'); };
  return h('div', {}, h('h2', {}, 'Destek Bilgisi'), h('div', { class: 'kart' },
    h('p', { class: 'not' }, 'Uygulamadaki Destek Merkezi panelinde ve kullanıcıya giden SMS/e-postalardaki iletişim satırında kullanılır.'),
    h('label', {}, 'Açıklama'), ac, h('label', {}, 'Destek e-postası'), ep, h('br'), h('br'), yazabilir ? h('button', { class: 'btn', onclick: kaydet }, 'Kaydet') : null));
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

// ── Gelen Talepler ────────────────────────────────────────────
// İki AYRI liste (karıştırılmaz):
//   · Destek Talepleri — kullanıcıların uygulamadan gönderdiği talepler
//     (/support/tickets; gerçek kayıtlar, admin yanıtı e-postayla gider)
//   · Dondurma / Silme — hesap yaşam döngüsü kayıtları (/account-requests)
const DESTEK_DURUM = { OPEN: 'Yanıt bekliyor', ANSWERED: 'Yanıtlandı', CLOSED: 'Kapandı' };
const destekRozet = (v) => h('span', { class: `rozet ${v}`, title: v }, DESTEK_DURUM[v] ?? v);

// 21 Eki: Gelen Talepler = destek e-postaları (ve eski uygulama formu).
// Hesap dondurma/silme otomatik işlendiği için talep değildir: kayıtları
// Silme Kuyrukları sayfasındadır (eski bağlantılar oraya yönlenir).
SAYFALAR.hesaptalepleri = async (sekme = 'destek', durum = '', aranan = '') => {
  if (sekme === 'hesap') { location.hash = '#/silmekuyruklari'; return h('p', { class: 'not' }, 'Yönlendiriliyor…'); }
  // Durum ve arama adres çubuğunda tutulur: geri dönünce aynı sonuç görünür.
  const git = (d, q) => { location.hash = `#/hesaptalepleri/destek/${encodeURIComponent(d)}${q ? `/${encodeURIComponent(q)}` : ''}`; };
  const filtre = h('select', { class: 'genis', onchange: (e) => git(e.target.value, aranan) },
    [['', 'Tümü'], ['OPEN', 'Yanıt bekleyenler'], ['ANSWERED', 'Yanıtlananlar'], ['CLOSED', 'Kapananlar']]
      .map(([v, e]) => h('option', { value: v, ...(v === durum ? { selected: true } : {}) }, e)));
  // ── ARAMA (21 Eki): talep no, e-posta, ad, konu ya da mesajdaki kelime ──
  const kutu = h('input', { type: 'search', class: 'genis', value: aranan, maxlength: 100, placeholder: 'Talep no, e-posta, ad ya da konu…', 'aria-label': 'Gelen taleplerde ara' });
  const aramaFormu = h('form', { class: 'gt-arama', onsubmit: (e) => { e.preventDefault(); git(durum, kutu.value.trim()); } },
    kutu, h('button', { class: 'btn', type: 'submit' }, 'Ara'),
    aranan ? h('button', { class: 'btn ikincil', type: 'button', onclick: () => git(durum, '') }, 'Temizle') : null);
  const SAYFA = 100;
  const sorgu = (ofset) => {
    const p = new URLSearchParams({ limit: String(SAYFA), offset: String(ofset) });
    if (durum) p.set('status', durum);
    if (aranan) p.set('q', aranan);
    return api(`/support/tickets?${p}`);
  };
  let liste = await sorgu(0);
  const kolonlar = [{ baslik: 'No', deger: (t) => t.ticketNo }, { baslik: 'Gönderen', deger: gonderenAdi },
    { baslik: 'Kaynak', deger: (t) => (t.source === 'EMAIL' ? 'E-posta' : 'Uygulama') }, { baslik: 'Konu', deger: (t) => t.subject },
    { baslik: 'Durum', deger: (t) => destekRozet(t.status) }, { baslik: 'Gönderim', deger: (t) => tarih(t.createdAt) }, { baslik: 'Son işlem', deger: (t) => tarih(t.updatedAt) }];
  const ac = (t) => (location.hash = `#/destektalebi/${t.id}`);
  const yer = h('div', {});
  const ciz = (sonGelen) => {
    const devam = sonGelen === SAYFA
      ? h('button', { class: 'btn ikincil', onclick: async (e) => {
        e.target.disabled = true;
        const ek = await guvenli(() => sorgu(liste.length));
        if (ek) { liste = liste.concat(ek); ciz(ek.length); } else e.target.disabled = false;
      } }, 'Daha fazla göster')
      : null;
    yer.replaceChildren(...[
      aranan ? h('p', { class: 'not' }, `"${aranan}" için ${liste.length}${sonGelen === SAYFA ? '+' : ''} sonuç.`) : null,
      aranan && !liste.length ? h('p', { class: 'not' }, 'Eşleşen talep yok.') : tablo(kolonlar, liste, ac),
      devam].filter(Boolean));
  };
  ciz(liste.length);
  return h('div', {}, h('div', { class: 'ust' }, h('h2', {}, 'Gelen Talepler')),
    h('p', { class: 'not' }, 'Destek e-posta adresine gelen e-postalar burada talep olarak açılır. Yanıtınız e-postayı gönderen adrese gider; kişi bu e-postayı yanıtlarsa yazdığı aynı talebe eklenir.'),
    h('div', { class: 'kart gt-filtre' }, h('div', {}, h('label', {}, 'Ara'), aramaFormu), h('div', {}, h('label', {}, 'Durum'), filtre)),
    yer);
};

/** Talebin göndereni: kayıtlı kullanıcının adı, yoksa e-postanın göndereni. */
const gonderenAdi = (t) => t.userName || t.senderName || t.senderEmail || '—';

SAYFALAR.destektalebi = async (id) => {
  const yazabilir = ['super_admin', 'moderator'].includes(ben.role);
  const t = await api(`/support/tickets/${id}`);
  const yanitla = async () => {
    const d = await form('Talebi yanıtla', [
      { ad: 'body', etiket: 'Yanıt (kullanıcıya e-postayla gider)', tur: 'textarea', zorunlu: true },
      { ad: 'close', etiket: 'Yanıtla ve talebi kapat', tur: 'checkbox' }], 'Gönder',
    { aciklama: t.source === 'EMAIL' ? `Yanıt ${t.senderEmail} adresine gider.` : t.userEmailVerified ? undefined : 'Kullanıcının doğrulanmış e-posta adresi yok: yanıt kaydedilir ve uygulamada görünür, e-posta gönderilemez.' });
    if (!d) return;
    const r = await guvenli(() => api(`/support/tickets/${id}/reply`, { yontem: 'POST', govde: { body: d.body, close: d.close === true } }));
    if (r) { bildir(`Yanıt kaydedildi. E-posta: ${DURUM_EPOSTA[r.email?.status] ?? r.email?.status ?? '—'}`, r.email?.status === 'FAILED'); yenile(); }
  };
  const kapat = async () => {
    const d = await form('Talebi kapat', [{ ad: 'reason', etiket: 'Not (isteğe bağlı)', tur: 'textarea' }], 'Kapat');
    if (d && await guvenli(() => api(`/support/tickets/${id}/close`, { yontem: 'POST', govde: d.reason ? { reason: d.reason } : {} }))) { bildir('Talep kapatıldı'); yenile(); }
  };
  return h('div', {},
    h('div', { class: 'ust' }, h('h2', {}, `Talep ${t.ticketNo}`), yazabilir && t.status !== 'CLOSED' ? h('div', { class: 'arac' },
      h('button', { class: 'btn', onclick: yanitla }, 'Yanıtla'), h('button', { class: 'btn ikincil', onclick: kapat }, 'Kapat')) : null),
    h('p', { class: 'not' }, 'Bu görüntüleme denetim kaydına yazıldı.'),
    h('div', { class: 'kart' }, alanlarListesi([
      ['Kaynak', t.source === 'EMAIL' ? 'Destek e-postası' : 'Uygulama'],
      ...(t.source === 'EMAIL' ? [['Gönderen', `${t.senderName ? `${t.senderName} · ` : ''}${t.senderEmail ?? '—'}`]] : []),
      ['Kullanıcı', t.userId ? h('a', { href: `#/kullanici/${t.userId}` }, t.userName || 'profil') : 'Kayıtlı kullanıcı değil'],
      ...(t.userId ? [['Hesap e-postası', `${t.userEmail || '—'}${t.userEmail ? (t.userEmailVerified ? ' (doğrulanmış)' : ' (doğrulanmamış)') : ''}`]] : []),
      ['Konu', t.subject], ['Durum', destekRozet(t.status)], ...(t.source === 'EMAIL' ? [] : [['Platform', t.platform ? `${t.platform} ${t.appVersion ?? ''}` : '—']]),
      ['Gönderim', tarih(t.createdAt)], ['Kapanış', tarih(t.closedAt)],
    ])),
    h('h3', {}, 'Mesaj'), h('div', { class: 'mesaj' }, t.message),
    h('h3', {}, 'Yazışma'),
    t.replies.length ? t.replies.map((y) => h('div', { class: `mesaj${y.author === 'USER' ? ' kullanici-mesaji' : ''}` },
      h('div', { class: 'ust' },
        h('span', {}, y.author === 'USER' ? `${gonderenAdi(t)} (e-postayla yanıt)` : (y.admin ?? 'yönetici')),
        h('span', {}, y.author === 'USER' ? tarih(y.createdAt) : `${tarih(y.createdAt)} · e-posta: ${DURUM_EPOSTA[y.emailStatus] ?? '—'}`)), y.body))
      : h('p', { class: 'not' }, 'Henüz yanıt yok.'));
};
const DURUM_EPOSTA = { SENT: 'gönderildi', FAILED: 'gönderilemedi', PENDING: 'bekliyor' };

SAYFALAR.geribildirim = async () => h('div', {}, h('h2', {}, 'Uygulama Geri Bildirimleri'), tablo([
  { baslik: 'Kullanıcı', deger: (f) => f.name }, { baslik: 'Puan', deger: (f) => f.stars }, { baslik: 'Yorum', deger: (f) => f.comment ?? '—' },
  { baslik: 'Platform', deger: (f) => `${f.platform} ${f.appVersion}` }, { baslik: 'Tarih', deger: (f) => tarih(f.updatedAt) },
], await api('/feedback'), (f) => (location.hash = `#/kullanici/${f.userId}`)));

SAYFALAR.denetim = async () => h('div', {}, h('h2', {}, 'Denetim Kaydı'), h('p', { class: 'not' }, 'Kayıtlar değiştirilemez ve silinemez.'),
  tablo([{ baslik: 'Tarih', deger: (x) => tarih(x.createdAt) }, { baslik: 'Admin', deger: (x) => x.admin ?? 'sistem' }, { baslik: 'İşlem', deger: (x) => x.action },
    { baslik: 'Hedef', deger: (x) => `${x.targetType ?? ''} ${x.targetId ?? ''}` }, { baslik: 'Gerekçe', deger: (x) => x.reason ?? '—' },
    { baslik: 'Değişiklik', deger: (x) => (x.before || x.after ? `${JSON.stringify(x.before)} → ${JSON.stringify(x.after)}` : '—') }], await api('/audit-log?limit=300')));

// ── Silme Kuyrukları (15 Eki güvenlik denetimi) ───────────────
// Hesap silmede Firebase kaydı ve dosyalar kuyrukla silinir. Kimlikler
// özetlenmiş gelir (Firebase uid'si ve dosya anahtarı gösterilmez).
const KUYRUK_DURUM = { BEKLIYOR: 'Bekliyor', BASARISIZ: 'Başarısız (yeniden denenecek)', DENEME_TUKENDI: 'Deneme hakkı tükendi', UZUN_SURELI_HATA: 'Uzun süredir başarısız' };
SAYFALAR.silmekuyruklari = async () => {
  // 21 Eki: hesap dondurma/silme kayıtları da burada (eskiden Gelen
  // Talepler'deydi; otomatik işlendikleri için talep değildir). İki kaynak
  // ayrı yetkiye bağlı: biri yoksa diğeri yine görünür.
  const kq = await api('/deletion-queues').then((v) => ({ v }), (e) => ({ e }));
  const yetkiYok = (e, ne) => h('p', { class: 'not' }, e?.durum === 403 ? `${ne} için yetkiniz yok.` : (e?.message ?? 'Veri alınamadı.'));
  const hesapBolumu = [
    h('h3', {}, 'Hesabını silenler ve donduranlar'),
    h('p', { class: 'not' }, 'Sistem bunları otomatik uygular. Hesabını yeniden etkinleştiren kişi listeden çıkar; silme yasal sürenin sonunda gerçekleşir ve kişisel bilgiler silinir, yalnız hesabın silindiği görünür. Ayrıntı için satıra tıklayın.'),
    kapatmaPaneli(),
  ];
  if (kq.e) return h('div', {}, h('h2', {}, 'Silme Kuyrukları'), ...hesapBolumu, h('h3', {}, 'Silme kuyrukları'), yetkiYok(kq.e, 'Silme kuyrukları'));
  const d = kq.v;
  const sayilar = (c) => Object.entries(c).map(([k, v]) => `${KUYRUK_DURUM[k] ?? k}: ${v}`).join(' · ') || 'Kuyruk boş';
  const yenidenDene = (kuyruk, id) => async (e) => {
    e?.stopPropagation?.();
    const neden = await gerekceIle('Yeniden dene', 'Yeniden dene', 'Başarısız silme işi bir sonraki turda (en geç 1 dakika) yeniden denenir. İşlem denetim kaydına yazılır.');
    if (!neden) return;
    const r = await guvenli(() => api('/deletion-queues/retry', { yontem: 'POST', govde: { queue: kuyruk, id, reason: neden } }));
    if (r) { bildir(`${r.retried} iş yeniden denemeye alındı`); yenile(); }
  };
  const kolonlar = (kuyruk) => [
    { baslik: 'Kimlik (özet)', deger: (x) => x.id }, ...(kuyruk === 'files' ? [{ baslik: 'Tür', deger: (x) => x.tur }] : []),
    { baslik: 'Durum', deger: (x) => KUYRUK_DURUM[x.durum] ?? x.durum }, { baslik: 'Deneme', deger: (x) => x.deneme },
    { baslik: 'Son hata', deger: (x) => x.sonHata ?? '—' }, { baslik: 'Sonraki deneme', deger: (x) => (x.sonrakiDeneme ? tarih(x.sonrakiDeneme) : '—') },
    { baslik: '', deger: (x) => (x.deneme > 0 ? h('button', { class: 'btn', onclick: yenidenDene(kuyruk, x.id) }, 'Yeniden dene') : '') },
  ];
  const a = d.accountDeletions;
  return h('div', {}, h('h2', {}, 'Silme Kuyrukları'),
    h('p', { class: 'not' }, 'Zamanlayıcı yalnız sunucu çalışırken işler. Sunucu uykudaysa (Render ücretsiz planı) süresi dolan silmeler ilk uyanışta uygulanır.'),
    h('div', { class: 'kart' }, alanlarListesi([
      ['Bekleyen silme talebi', a.pending], ['Süresi geçmiş, uygulanmamış', a.overdue], ['En eski gecikme', a.oldestOverdueAt ? tarih(a.oldestOverdueAt) : '—'],
    ])),
    ...hesapBolumu,
    h('h3', {}, 'Firebase kimlik kayıtları'),
    h('p', { class: 'not' }, `${d.firebase.configured ? 'Servis hesabı yapılandırılmış.' : '⚠ Servis hesabı yapılandırılmamış: kayıtlar silinemez, kuyrukta bekler.'} ${sayilar(d.firebase.counts)}. Hatalı işler artan aralıkla (en fazla 24 saatte bir) süresiz yeniden denenir.`),
    d.firebase.items.some((x) => x.deneme > 0) ? h('button', { class: 'btn', onclick: yenidenDene('firebase', null) }, 'Başarısızların tümünü yeniden dene') : null,
    tablo(kolonlar('firebase'), d.firebase.items),
    h('h3', {}, 'Dosyalar'),
    h('p', { class: 'not' }, `${d.files.configured ? 'Depo yapılandırılmış.' : '⚠ Depo yapılandırılmamış: dosyalar silinemez, kuyrukta bekler.'} ${sayilar(d.files.counts)}. En fazla ${d.files.maxAttempts} deneme; tükenen iş yalnız buradan yeniden denenir.`),
    d.files.items.some((x) => x.deneme > 0) ? h('button', { class: 'btn', onclick: yenidenDene('files', null) }, 'Başarısızların tümünü yeniden dene') : null,
    tablo(kolonlar('files'), d.files.items),
    h('h3', {}, 'Firebase işlemleri (oturum iptali / telefon eşitleme)'),
    h('p', { class: 'not' }, `${d.firebaseOps.configured ? 'Servis hesabı yapılandırılmış.' : '⚠ Servis hesabı yapılandırılmamış: işlemler kuyrukta bekler.'} ${sayilar(d.firebaseOps.counts)}. Firebase'e yazılamayan oturum iptali ve telefon eşitlemesi buradan tamamlanır; eski belgeyle oturum açılması sunucuda zaten engellidir.`),
    d.firebaseOps.items.some((x) => x.deneme > 0) ? h('button', { class: 'btn', onclick: yenidenDene('firebase_ops', null) }, 'Başarısızların tümünü yeniden dene') : null,
    tablo([{ baslik: 'İşlem', deger: (x) => (x.islem === 'REVOKE' ? 'Oturum iptali' : 'Telefon eşitleme') }, ...kolonlar('firebase_ops')], d.firebaseOps.items));
};

// ── Entegrasyonlar ────────────────────────────────────────────
SAYFALAR.entegrasyonlar = async () => {
  const liste = await api('/integrations');
  const yedek = await api('/system/backup-monitor');
  const superMi = ben.role === 'super_admin';
  const ekle = async () => {
    const d = await form('Entegrasyon ekle', [
      { ad: 'type', etiket: 'Tür', tur: 'select', deger: 'SMS', secenekler: [['SMS', 'SMS (HTTPS köprü)'], ['EMAIL_RESEND', 'E-posta (Resend — kurumsal tasarım)'], ['EMAIL', 'E-posta (HTTPS köprü)'], ['STORAGE', 'Dosya depolama (S3 uyumlu)']] },
      { ad: 'url', etiket: 'SMS/E-posta köprü: adres (https)' },
      { ad: 'from', etiket: 'Resend: gönderen (ör. HizmetCep <bildirim@hizmetcep.com>)' },
      { ad: 'endpoint', etiket: 'Depolama: uç nokta (https)' },
      { ad: 'bucket', etiket: 'Depolama: kova' }, { ad: 'region', etiket: 'Depolama: bölge (ör. auto, eu-central-1)' }], 'Ekle');
    if (!d) return;
    const govde = d.type === 'STORAGE'
      ? { type: 'STORAGE', provider: 's3', config: { endpoint: d.endpoint, bucket: d.bucket, region: d.region } }
      : d.type === 'EMAIL_RESEND'
        ? { type: 'EMAIL', provider: 'resend', config: { from: d.from } }
        : { type: d.type, provider: 'webhook', config: { url: d.url } };
    if (await guvenli(() => api('/integrations', { yontem: 'POST', govde }))) { bildir('Eklendi (pasif). Gizli anahtarı girip etkinleştirin.'); yenile(); }
  };
  const sir = async (x) => {
    const alanlar = x.type === 'STORAGE'
      ? [{ ad: 'accessKeyId', etiket: 'Erişim anahtarı kimliği', tur: 'password', zorunlu: true }, { ad: 'secretAccessKey', etiket: 'Gizli erişim anahtarı', tur: 'password', zorunlu: true }]
      : [{ ad: 'token', etiket: x.provider === 'resend' ? 'Resend API anahtarı (re_…)' : 'Köprü anahtarı (Bearer)', tur: 'password', zorunlu: true }];
    const d = await form('Gizli anahtarı değiştir', alanlar, 'Kaydet', { aciklama: 'Değer şifreli saklanır ve bir daha gösterilmez.' });
    if (d && await guvenli(() => api(`/integrations/${x.id}/secret`, { yontem: 'PUT', govde: d }))) { bildir('Kaydedildi'); yenile(); }
  };
  // Resend: destek e-postalarını Gelen Talepler'e düşüren webhook'un imza anahtarı.
  const gelenAnahtar = async (x) => {
    const d = await form('Gelen e-posta imza anahtarı', [{ ad: 'webhookSecret', etiket: 'Resend › Webhooks › email.received › Signing secret (whsec_…)', tur: 'password', zorunlu: true }], 'Kaydet',
      { aciklama: 'Destek adresine gelen e-postaların Gelen Talepler\'e düşmesi için. Değer şifreli saklanır ve bir daha gösterilmez.' });
    if (d && await guvenli(() => api(`/integrations/${x.id}/inbound-secret`, { yontem: 'PUT', govde: d }))) { bildir('Kaydedildi'); yenile(); }
  };
  const etkin = async (x) => { if (await guvenli(() => api(`/integrations/${x.id}`, { yontem: 'PATCH', govde: { active: !x.active } }))) { bildir('Güncellendi'); yenile(); } };
  const test = async (x) => { const r = await guvenli(() => api(`/integrations/${x.id}/test`, { yontem: 'POST', govde: {} })); if (r) { bildir(`${r.ok ? 'Başarılı' : 'Başarısız'}: ${r.message}`, !r.ok); yenile(); } };
  const sil = async (x) => { const n = await gerekceIle('Entegrasyonu kaldır', 'Kaldır'); if (n && await guvenli(() => api(`/integrations/${x.id}`, { yontem: 'DELETE', govde: { reason: n } }))) { bildir('Kaldırıldı'); yenile(); } };
  // ── Yedekleme izleme (22 Eki): Render API'sinden yalnız OKUMA ──
  const yedekBagla = async () => {
    const d = await form('Yedekleme izleme (Render)', [
      { ad: 'postgresId', etiket: 'Postgres kimliği (Render › veritabanı › Info: dpg-…)', zorunlu: true, deger: yedek.postgresId ?? '' },
      { ad: 'apiKey', etiket: 'Render API anahtarı (Account Settings › API Keys: rnd_…)', tur: 'password', zorunlu: true },
    ], 'Kaydet ve kontrol et', { aciklama: 'Anahtar yalnız yedekleme durumunu OKUMAK için kullanılır; şifreli saklanır ve bir daha gösterilmez.' });
    const r = d && await guvenli(() => api('/system/backup-monitor', { yontem: 'PUT', govde: d }));
    if (r) { bildir(r.checkOk ? 'Kaydedildi: Render API okundu' : `Kaydedildi ama okunamadı: ${r.checkMessage}`, !r.checkOk); yenile(); }
  };
  const yedekKaldir = async () => {
    const n = await gerekceIle('Yedekleme izlemeyi kaldır', 'Kaldır');
    if (n && await guvenli(() => api('/system/backup-monitor', { yontem: 'DELETE', govde: { reason: n } }))) { bildir('Kaldırıldı'); yenile(); }
  };
  const yedekBolumu = h('div', { class: 'kart' },
    h('h3', {}, 'Yedekleme izleme (Render)'),
    h('p', { class: 'not' }, yedek.configured
      ? `Postgres: ${yedek.postgresId} · anahtar ${yedek.secretHint} · son kontrol ${yedek.checkedAt ? tarih(yedek.checkedAt) : '—'} · ${yedek.checkOk ? 'okundu' : `okunamadı: ${yedek.checkMessage ?? '—'}`}`
      : 'Bağlı değil: Sistem Durumu\'nda yedekleme "doğrulanmadı" görünür.'),
    superMi ? h('span', {}, h('button', { class: 'btn ikincil', onclick: yedekBagla }, yedek.configured ? 'Değiştir' : 'Bağla'), ' ',
      yedek.configured ? h('button', { class: 'btn tehlike', onclick: yedekKaldir }, 'Kaldır') : null) : null);
  return h('div', {}, h('div', { class: 'ust' }, h('h2', {}, 'Entegrasyonlar'), h('button', { class: 'btn', onclick: ekle }, 'Ekle')),
    h('p', { class: 'not' }, 'Gizli anahtarlar yalnız sunucuda, şifreli saklanır; bu panele asla geri gelmez. Her türde aynı anda tek sağlayıcı etkindir.'),
    tablo([{ baslik: 'Tür', deger: (x) => x.type }, { baslik: 'Sağlayıcı', deger: (x) => x.provider },
      { baslik: 'Ayar', deger: (x) => JSON.stringify(x.config) },
      { baslik: 'Anahtar', deger: (x) => [x.secretSet ? x.secretHint : 'girilmedi', x.provider === 'resend' ? ` · gelen e-posta: ${x.inboundSecretSet ? 'girildi' : 'girilmedi'}` : ''].join('') },
      { baslik: 'Durum', deger: (x) => rozet(x.active ? 'aktif' : 'pasif') },
      { baslik: 'Son test', deger: (x) => (x.lastTestAt ? `${x.lastTestOk ? '✓' : '✗'} ${x.lastTestMessage}` : '—') },
      { baslik: '', deger: (x) => h('span', {}, superMi ? h('button', { class: 'btn ikincil', onclick: () => sir(x) }, 'Anahtar') : null, ' ',
        superMi && x.provider === 'resend' ? [h('button', { class: 'btn ikincil', onclick: () => gelenAnahtar(x) }, 'Gelen e-posta anahtarı'), ' '] : null,
        h('button', { class: 'btn ikincil', onclick: () => test(x) }, 'Test'), ' ', h('button', { class: 'btn', onclick: () => etkin(x) }, x.active ? 'Pasifleştir' : 'Etkinleştir'), ' ',
        h('button', { class: 'btn tehlike', onclick: () => sil(x) }, 'Kaldır')) }], liste),
    yedekBolumu);
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
    oturumBasladi();
    cizim();
  } catch {
    girisEkrani();
  }
})();
