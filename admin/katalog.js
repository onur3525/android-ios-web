// ═══════════════════════════════════════════════════════════════
// KATEGORİ VE HİZMETLER — gerçek katalog yönetimi (.kt)
//
// MEVCUT UÇLAR (backend değişmedi; demo/sahte veri YOK):
//   GET   /admin/v1/catalog/categories            sırayla (sort, ad) + gerçek hizmet sayısı
//   GET   /admin/v1/catalog/icons                 uygulama paketindeki ikon dosyaları
//   POST  /admin/v1/catalog/categories            yeni kategori → sort = MAX+1 (SONA)
//   PATCH /admin/v1/catalog/categories/:id        ad, aktif, ikon, kart dışı
//   GET   /admin/v1/catalog/categories/:id/services   sırayla (sort, ad)
//   POST  /admin/v1/catalog/categories/:id/services   yeni hizmet → sort = kategorideki MAX+1 (EN ALTA)
//   PATCH /admin/v1/catalog/services/:id          ad, aktif, öne çıkan
// Sıra SUNUCUDA atanır; istemci sort GÖNDERMEZ (mevcut sıra hiç değişmez).
// Uygulama (Flutter) kataloğu GET /api/v1/categories ile aynı sırada okur.
//
// ÇATILAR (22 Eki, kullanıcı kararı): sayfa uygulamanın ana sayfası gibi
// açılır — yalnız 24 çatı, 3'lü ızgara, uygulamadaki fotoğraf/ad/açıklama.
// Çatıya dokununca o çatının kategorileri ikonlarıyla görünür. Çatının adı
// ve fotoğrafı, kategorinin ikonu buradan değişir (GET/PATCH
// /admin/v1/catalog/roofs…). Adres: #/katalog (ızgara), #/katalog/<çatı>.
//
// BİLİNÇLİ SINIRLAR (ayrıntı: rapor):
//   · İkon: Flutter yalnız paketindeki SVG'leri çizer → yalnız o listeden seçilir.
//   · Fotoğraf YALNIZ ÇATILARDA (22 Eki, kullanıcı kararı): kategoride
//     fotoğraf yok, yalnız ikon; kategori fotoğrafı ekleme/kaldırma yok.
//   · Hizmet ikonu: veri modelinde YOK.
//   · Silme yerine Aktif/Pasif (geçmiş ilan/talep kayıtları etkilenmez).
// ═══════════════════════════════════════════════════════════════
import { api, bildir, form, h } from './cekirdek.js';

const FOTO_TURLERI = ['image/jpeg', 'image/png', 'image/webp']; // backend ile aynı
const FOTO_AZAMI = 5 * 1024 * 1024; // backend ile aynı (5 MB)

/** Görsel ya da anlaşılır boş/kırık durumu (sahte görsel YOK). */
function gorsel(url, sinif, bosMetin = 'Fotoğraf yok') {
  const kutu = h('div', { class: `kt-gorsel ${sinif}` });
  if (!url) {
    kutu.append(h('span', { class: 'kt-gorsel-bos' }, bosMetin));
    return kutu;
  }
  const img = h('img', { src: url, alt: '', loading: 'lazy' });
  img.addEventListener('error', () => kutu.replaceChildren(h('span', { class: 'kt-gorsel-bos hata' }, 'Fotoğraf bulunamadı')));
  kutu.append(img);
  return kutu;
}

/** Dosyayı seçtirir ve doğrular; { tur, veri(base64), onizleme(dataURL) } döndürür. */
function dosyaSec() {
  return new Promise((coz) => {
    const girdi = h('input', { type: 'file', accept: FOTO_TURLERI.join(','), hidden: true });
    girdi.addEventListener('change', () => {
      const f = girdi.files?.[0];
      girdi.remove();
      if (!f) return coz(null);
      if (!FOTO_TURLERI.includes(f.type)) { bildir('Yalnız JPEG, PNG ya da WEBP seçebilirsiniz', true); return coz(null); }
      if (f.size > FOTO_AZAMI) { bildir('Fotoğraf en fazla 5 MB olabilir', true); return coz(null); }
      const okuyucu = new FileReader();
      okuyucu.onload = () => {
        const url = String(okuyucu.result);
        coz({ tur: f.type, veri: url.slice(url.indexOf(',') + 1), onizleme: url, ad: f.name });
      };
      okuyucu.onerror = () => coz(null);
      okuyucu.readAsDataURL(f);
    });
    document.body.append(girdi);
    girdi.click();
  });
}

/** Seçilen dosyanın YEREL önizlemesi + onay (kaydetmeden gerçek kayıt değişmez). */
function onizlemeOnayi(baslik, secim, mevcutUrl) {
  return new Promise((coz) => {
    const kapat = (v) => { perde.remove(); coz(v); };
    const perde = h('div', { class: 'perde', role: 'dialog', 'aria-modal': 'true' },
      h('div', { class: 'pencere kt-pencere' },
        h('h3', {}, baslik),
        h('div', { class: 'kt-karsilastir' },
          mevcutUrl !== undefined ? h('div', {}, h('div', { class: 'oz-etiket' }, 'Mevcut'), gorsel(mevcutUrl, 'kt-orta')) : null,
          h('div', {}, h('div', { class: 'oz-etiket' }, 'Yeni (önizleme)'), gorsel(secim.onizleme, 'kt-orta'))),
        h('p', { class: 'not' }, 'Kaydedene kadar mevcut kayıt değişmez. Fotoğraf uygulamada çatı görseli olarak kullanılır.'),
        h('div', { class: 'tuslar' },
          h('button', { class: 'btn ikincil', onclick: () => kapat(false) }, 'Vazgeç'),
          h('button', { class: 'btn', onclick: () => kapat(true) }, 'Kaydet'))));
    document.body.append(perde);
  });
}

const YAZABILIR = ['super_admin', 'content']; // backend catalog.write ile aynı
const dosyaAdi = (yol) => (yol ? String(yol).split('/').pop() : null);
const kucuk = (s) => s.toLocaleLowerCase('tr-TR');

const CATISIZ = '_';

/** Çatı kartı: uygulamadaki kartla aynı içerik (fotoğraf, kart etiketi, açıklama). */
function catiKarti(c) {
  return h('a', { class: 'kt-cati', href: `#/katalog/${encodeURIComponent(c.key)}` },
    gorsel(c.photoUrl || c.bundledPhotoUrl, 'kt-cati-foto'),
    h('span', { class: 'kt-cati-ad' }, c.cardLabel || c.name),
    h('span', { class: 'kt-cati-aciklama' }, c.description));
}

export async function katalogSayfasi(rol, catiKey) {
  const yazabilir = YAZABILIR.includes(rol);
  if (!catiKey) return catiIzgarasi(yazabilir);
  let cati = null;
  let kategoriler = [];
  let ikonlar = [];
  let seciliId = null;
  let istekNo = 0;

  const ara = h('input', { class: 'ku-ara kt-ara', type: 'search', placeholder: 'Kategori ara', 'aria-label': 'Kategori ara' });
  const katListe = h('div', { class: 'kt-liste', role: 'list' });
  const detay = h('div', { class: 'kt-detay' });
  const duzen = h('div', { class: 'kt-duzen' });

  const ikonSecenekleri = (secili) => [['', '— genel ikon —'], ...ikonlar.map((i) => [i, dosyaAdi(i)])]
    .concat(secili && !ikonlar.includes(secili) ? [[secili, dosyaAdi(secili)]] : []);

  async function hataGoster(e) {
    bildir(e.durum === 403 && e.kod !== 'REAUTH_REQUIRED' ? 'Bu işlem için yetkiniz yok.' : e.message, true);
  }

  // ── KATEGORİLER ──
  async function kategorileriYukle() {
    const no = ++istekNo;
    katListe.replaceChildren(h('div', { class: 'il-yukleniyor', role: 'status' }, 'Kategoriler yükleniyor…'));
    try {
      const [r, i] = await Promise.all([api('/catalog/roofs'), ikonlar.length ? ikonlar : api('/catalog/icons').catch(() => [])]);
      if (no !== istekNo) return;
      cati = catiKey === CATISIZ
        ? { key: CATISIZ, name: 'Çatıya bağlı olmayan kategoriler', categories: r.unassigned, sabit: true }
        : r.roofs.find((c) => c.key === catiKey) ?? null;
      if (!cati) { location.hash = '#/katalog'; return; }
      kategoriler = cati.categories;
      ikonlar = i;
      catiUstunuCiz();
    } catch (e) {
      if (no !== istekNo) return;
      katListe.replaceChildren(h('div', { class: 'ku-bos' },
        h('div', { class: 'ku-bos-baslik' }, e.durum === 403 ? 'Yetkiniz yok' : 'Katalog yüklenemedi'),
        h('p', { class: 'oz-bos' }, e.durum === 403 ? 'Kataloğu görüntüleme yetkiniz bulunmuyor.' : (e.message || 'Beklenmeyen bir hata oluştu.')),
        e.durum === 403 ? null : h('button', { class: 'btn ikincil', onclick: () => kategorileriYukle() }, 'Tekrar dene')));
      return;
    }
    listeyiCiz();
    if (seciliId && kategoriler.some((x) => x.id === seciliId)) await hizmetleriYukle(seciliId);
  }

  function listeyiCiz() {
    const q = kucuk(ara.value.trim());
    const goster = kategoriler
      .map((k, i) => ({ ...k, siraNo: i + 1 }))
      .filter((k) => !q || kucuk(k.name).includes(q));
    if (!kategoriler.length) {
      katListe.replaceChildren(h('div', { class: 'ku-bos' }, h('div', { class: 'ku-bos-baslik' }, 'Henüz kategori bulunmuyor')));
      return;
    }
    if (!goster.length) {
      katListe.replaceChildren(h('div', { class: 'ku-bos' }, h('div', { class: 'ku-bos-baslik' }, 'Eşleşen kategori bulunamadı')));
      return;
    }
    katListe.replaceChildren(...goster.map((k) => h('button', {
      class: `kt-kat${k.id === seciliId ? ' secili' : ''}${k.active ? '' : ' pasif'}`, role: 'listitem',
      onclick: () => { seciliId = k.id; listeyiCiz(); hizmetleriYukle(k.id); duzen.classList.add('detay-acik'); },
    },
    h('span', { class: 'kt-sira' }, String(k.siraNo)),
    // Uygulamadaki rozet: kategori ikonu.
    gorsel(k.iconUrl, 'kt-kucuk-gorsel kt-rozet', 'İkon'),
    h('span', { class: 'kt-kat-metin' },
      h('span', { class: 'ku-ad' }, k.name),
      h('span', { class: 'ku-eposta' }, `${k.serviceCount.toLocaleString('tr-TR')} hizmet${k.kartDisi ? ' · ana sayfa ızgarasında yok' : ''}`)),
    k.active ? null : h('span', { class: 'ku-durum kd-kapali' }, 'Pasif'))));
  }

  // ── HİZMETLER ──
  async function hizmetleriYukle(id) {
    const k = kategoriler.find((x) => x.id === id);
    if (!k) return;
    detay.replaceChildren(h('div', { class: 'il-yukleniyor', role: 'status' }, 'Hizmetler yükleniyor…'));
    let hizmetler;
    try {
      hizmetler = await api(`/catalog/categories/${id}/services`);
    } catch (e) {
      detay.replaceChildren(h('div', { class: 'ku-bos' },
        h('div', { class: 'ku-bos-baslik' }, 'Hizmetler yüklenemedi'), h('p', { class: 'oz-bos' }, e.message || ''),
        h('button', { class: 'btn ikincil', onclick: () => hizmetleriYukle(id) }, 'Tekrar dene')));
      return;
    }
    if (seciliId !== id) return;
    detay.replaceChildren(
      h('button', { class: 'oz-tumu kt-geri', onclick: () => duzen.classList.remove('detay-acik') }, '‹ Kategoriler'),
      h('div', { class: 'kt-kat-ust' },
        h('div', {},
          h('h3', {}, k.name),
          h('div', { class: 'kd-rozetler' },
            h('span', { class: `ku-durum ${k.active ? 'ACTIVE' : 'kd-kapali'}` }, k.active ? 'Aktif' : 'Pasif'),
            k.kartDisi ? h('span', { class: 'ku-dogrulama hayir' }, 'Ana sayfa ızgarasında gösterilmiyor') : null)),
        yazabilir ? h('div', { class: 'kt-tuslar' },
          h('button', { class: 'btn ikincil', onclick: () => kategoriDuzenle(k) }, 'Kategoriyi düzenle'),
          h('button', { class: 'btn', onclick: () => hizmetEkle(k) }, '+ Yeni Hizmet')) : null),
      h('div', { class: 'kt-medya' },
        h('div', { class: 'kt-ikon-alani' },
          h('div', { class: 'oz-etiket' }, 'İkon'),
          gorsel(k.iconUrl, 'kt-ikon', 'Genel ikon'),
          h('div', { class: 'ku-eposta' }, dosyaAdi(k.icon) ?? 'Genel ikon'),
          yazabilir ? h('button', { class: 'btn ikincil kt-kucuk', onclick: () => ikonDegistir(k) }, 'İkonu değiştir') : null)),
      h('div', { class: 'kd-bilgi-izgara kt-bilgi' },
        h('div', { class: 'kd-bilgi' }, h('div', { class: 'oz-etiket' }, 'Katalog sırası'), h('div', { class: 'kd-deger' }, String(Number(k.sort) + 1))),
        h('div', { class: 'kd-bilgi' }, h('div', { class: 'oz-etiket' }, 'Hizmet sayısı'), h('div', { class: 'kd-deger' }, String(hizmetler.length)))),
      h('h4', { class: 'kt-alt-baslik' }, 'Hizmetler (uygulamadaki sırayla)'),
      hizmetler.length ? h('ol', { class: 'kt-hizmetler' }, hizmetler.map((s) => h('li', { class: `kt-hizmet${s.active ? '' : ' pasif'}` },
        h('span', { class: 'kt-hizmet-ad' }, s.name),
        h('span', { class: 'kt-hizmet-rozet' },
          s.lider ? h('span', { class: 'ku-dogrulama evet' }, 'Öne çıkan') : null,
          s.active ? null : h('span', { class: 'ku-durum kd-kapali' }, 'Pasif')),
        yazabilir ? h('button', { class: 'btn ikincil kt-kucuk', onclick: () => hizmetDuzenle(k, s) }, 'Düzenle') : null)))
        : h('div', { class: 'ku-bos' }, h('div', { class: 'ku-bos-baslik' }, 'Bu kategoride henüz hizmet yok'),
          h('p', { class: 'oz-bos' }, 'Hizmeti olmayan kategori uygulamada listelenmez.')));
  }

  // ── FORMLAR (yalnız API'nin kabul ettiği alanlar) ──
  async function kategoriDuzenle(k) {
    const d = await form(`Kategoriyi düzenle — ${k.name}`, [
      { ad: 'name', etiket: 'Kategori adı', deger: k.name, zorunlu: true },
      { ad: 'icon', etiket: 'İkon (uygulama paketindeki ikonlar)', tur: 'select', deger: k.icon ?? '', secenekler: ikonSecenekleri(k.icon) },
      { ad: 'active', etiket: 'Aktif (pasif kategori uygulamada gösterilmez)', tur: 'checkbox', deger: k.active },
      { ad: 'kartDisi', etiket: 'Ana sayfa ızgarasında gösterme (arama ve seçimde görünür)', tur: 'checkbox', deger: k.kartDisi },
    ], 'Kaydet');
    if (!d) return;
    const govde = {};
    if (d.name !== k.name) govde.name = d.name;
    if ((d.icon || null) !== (k.icon || null)) govde.icon = d.icon || null;
    if (d.active !== k.active) govde.active = d.active;
    if (d.kartDisi !== k.kartDisi) govde.kartDisi = d.kartDisi;
    if (!Object.keys(govde).length) return bildir('Değişiklik yok');
    try {
      await api(`/catalog/categories/${k.id}`, { yontem: 'PATCH', govde });
      bildir('Kategori kaydedildi');
      await kategorileriYukle(); // gerçek kayıt yeniden okunur
    } catch (e) { hataGoster(e); }
  }

  async function hizmetEkle(k) {
    const d = await form(`Yeni hizmet — ${k.name}`, [{ ad: 'name', etiket: 'Hizmet adı (2–100 karakter)', zorunlu: true }],
      'Ekle', { aciklama: 'Yeni hizmet bu kategorinin hizmet listesinin EN ALTINA eklenir; mevcut hizmetlerin sırası değişmez.' });
    if (!d) return;
    try {
      await api(`/catalog/categories/${k.id}/services`, { yontem: 'POST', govde: { name: d.name } });
      bildir('Hizmet eklendi');
      await kategorileriYukle(); // sayı ve liste sunucudan
    } catch (e) { hataGoster(e); }
  }

  async function hizmetDuzenle(k, s) {
    const d = await form(`Hizmeti düzenle — ${s.name}`, [
      { ad: 'name', etiket: 'Hizmet adı', deger: s.name, zorunlu: true },
      { ad: 'active', etiket: 'Aktif (pasif hizmet uygulamada gösterilmez)', tur: 'checkbox', deger: s.active },
      { ad: 'lider', etiket: 'Aramada öne çıkar', tur: 'checkbox', deger: s.lider },
    ], 'Kaydet');
    if (!d) return;
    const govde = {};
    if (d.name !== s.name) govde.name = d.name;
    if (d.active !== s.active) govde.active = d.active;
    if (d.lider !== s.lider) govde.lider = d.lider;
    if (!Object.keys(govde).length) return bildir('Değişiklik yok');
    try {
      await api(`/catalog/services/${s.id}`, { yontem: 'PATCH', govde });
      bildir('Hizmet kaydedildi');
      await hizmetleriYukle(k.id);
    } catch (e) { hataGoster(e); }
  }

  // ── İKON SEÇİCİ: uygulama paketindeki ikonlar görsel olarak seçilir ──
  async function ikonDegistir(k) {
    const secim = await new Promise((coz) => {
      const kapat = (v) => { perde.remove(); coz(v); };
      const izgara = h('div', { class: 'kt-ikon-izgara' }, ikonlar.map((i) => h('button', {
        class: `kt-ikon-sec${i === k.icon ? ' secili' : ''}`, title: dosyaAdi(i), onclick: () => kapat(i),
      }, h('img', { src: `/katalog-varlik/${i}`, alt: dosyaAdi(i) }))));
      const perde = h('div', { class: 'perde', role: 'dialog', 'aria-modal': 'true' },
        h('div', { class: 'pencere kt-pencere' },
          h('h3', {}, `İkon seç — ${k.name}`),
          h('p', { class: 'not' }, 'Uygulama yalnız kendi paketindeki ikonları çizebilir; liste bu ikonlardır.'),
          izgara,
          h('div', { class: 'tuslar' }, h('button', { class: 'btn ikincil', onclick: () => kapat(null) }, 'Vazgeç'))));
      perde.addEventListener('keydown', (e) => { if (e.key === 'Escape') kapat(null); });
      document.body.append(perde);
    });
    if (!secim || secim === k.icon) return;
    try {
      await api(`/catalog/categories/${k.id}`, { yontem: 'PATCH', govde: { icon: secim } });
      bildir('İkon kaydedildi');
      await kategorileriYukle();
    } catch (e) { hataGoster(e); }
  }

  // ── ÇATI BAŞLIĞI: ad ve fotoğraf ──
  const catiUst = h('div', { class: 'kt-cati-ust' });
  function catiUstunuCiz() {
    if (cati.sabit) { catiUst.replaceChildren(h('p', { class: 'not' }, 'Bu kategoriler uygulamada aramada ve ilan verirken görünür; ana sayfa çatılarında görünmez.')); return; }
    catiUst.replaceChildren(
      gorsel(cati.photoUrl || cati.bundledPhotoUrl, 'kt-cati-ust-foto'),
      h('div', { class: 'kt-cati-ust-metin' },
        h('div', { class: 'oz-etiket' }, 'Çatı'),
        h('h3', {}, cati.name),
        h('p', { class: 'ku-eposta' }, cati.description),
        h('p', { class: 'ku-eposta' }, cati.photoUrl ? 'Fotoğraf: admin\'den yüklendi' : 'Fotoğraf: uygulama paketi'),
        yazabilir ? h('div', { class: 'kt-tuslar' },
          h('button', { class: 'btn ikincil kt-kucuk', onclick: catiAdiDegistir }, 'Adı değiştir'),
          h('button', { class: 'btn ikincil kt-kucuk', onclick: catiFotoDegistir }, 'Fotoğrafı değiştir'),
          cati.photoRef ? h('button', { class: 'btn tehlike kt-kucuk', onclick: catiFotoKaldir }, 'Fotoğrafı kaldır') : null) : null));
  }
  async function catiAdiDegistir() {
    const d = await form(`Çatı adı — ${cati.name}`, [{ ad: 'name', etiket: 'Çatı adı (2–60 karakter)', deger: cati.name, zorunlu: true }], 'Kaydet',
      { aciklama: 'Uygulamanın ana sayfasındaki kartta ve çatı ekranında bu ad görünür.' });
    if (!d || d.name === cati.name) return;
    try {
      await api(`/catalog/roofs/${encodeURIComponent(cati.key)}`, { yontem: 'PATCH', govde: { name: d.name } });
      bildir('Çatı adı kaydedildi');
      await kategorileriYukle();
    } catch (e) { hataGoster(e); }
  }
  async function catiFotoDegistir() {
    const secim = await dosyaSec();
    if (!secim) return;
    if (!(await onizlemeOnayi(`Fotoğraf — ${cati.name}`, secim, cati.photoUrl || cati.bundledPhotoUrl || null))) return;
    try {
      await api(`/catalog/roofs/${encodeURIComponent(cati.key)}/photo`, { yontem: 'POST', govde: { contentType: secim.tur, data: secim.veri } });
      bildir('Fotoğraf kaydedildi');
      await kategorileriYukle();
    } catch (e) { hataGoster(e); }
  }
  async function catiFotoKaldir() {
    const d = await form(`Fotoğraf kaldırılsın mı? — ${cati.name}`, [], 'Kaldır',
      { tehlike: true, aciklama: 'Yüklenen fotoğraf depodan silinir; uygulama bu çatıda paketindeki fotoğrafa döner.' });
    if (!d) return;
    try {
      await api(`/catalog/roofs/${encodeURIComponent(cati.key)}/photo`, { yontem: 'DELETE', govde: {} });
      bildir('Fotoğraf kaldırıldı');
      await kategorileriYukle();
    } catch (e) { hataGoster(e); }
  }

  ara.addEventListener('input', () => listeyiCiz()); // katalog API'si listenin TAMAMINI verir

  await kategorileriYukle();
  if (!seciliId && kategoriler[0]) { seciliId = kategoriler[0].id; listeyiCiz(); await hizmetleriYukle(seciliId); }

  duzen.replaceChildren(
    h('section', { class: 'oz-kart kt-sol' }, h('div', { class: 'kt-sol-ust' }, ara), katListe),
    h('section', { class: 'oz-kart kt-sag' }, detay));

  return h('div', { class: 'oz ku kt' },
    h('a', { class: 'oz-geri', href: '#/katalog' }, '‹ Çatılar'),
    h('section', { class: 'oz-kart' }, catiUst),
    duzen);
}

// ── ÇATI IZGARASI: uygulamanın ana sayfası gibi (3'lü) ──
async function catiIzgarasi(yazabilir) {
  const r = await api('/catalog/roofs');
  return h('div', { class: 'oz ku kt' },
    h('div', { class: 'oz-baslik' },
      h('div', {}, h('h2', {}, 'Kategori ve Hizmetler'), h('p', {}, 'Uygulamanın ana sayfasındaki çatılar; dokununca içindeki kategoriler açılır')),
      yazabilir ? h('div', { class: 'kt-ust-sag' }, h('button', { class: 'btn', onclick: () => yeniKategoriVeGit() }, '+ Yeni Kategori')) : null),
    h('div', { class: 'kt-cati-izgara' }, r.roofs.map(catiKarti)),
    r.unassigned.length ? h('a', { class: 'oz-tumu', href: `#/katalog/${CATISIZ}` }, `Çatıya bağlı olmayan ${r.unassigned.length.toLocaleString('tr-TR')} kategori ›`) : null);
}

/** Yeni kategori çatısız başlar; oluşturulunca o listeye gidilir. */
async function yeniKategoriVeGit() {
  const d = await form('Yeni kategori', [{ ad: 'name', etiket: 'Kategori adı (2–100 karakter)', zorunlu: true }], 'Oluştur',
    { aciklama: 'Yeni kategori hiçbir çatıya bağlı değildir: uygulamada aramada ve ilan verirken görünür. Uygulamada görünmesi için en az bir hizmet ekleyin.' });
  if (!d) return;
  try {
    await api('/catalog/categories', { yontem: 'POST', govde: { name: d.name } });
    bildir('Kategori oluşturuldu');
    location.hash = `#/katalog/${CATISIZ}`;
  } catch (e) { bildir(e.message, true); }
}
