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
// BİLİNÇLİ SINIRLAR (ayrıntı: rapor):
//   · İkon: Flutter yalnız paketindeki SVG'leri çizer → yalnız o listeden seçilir.
//   · Kategori fotoğrafı (008 göçü): admin'den yüklenen fotoğraf MEVCUT nesne
//     depolamaya sunucu üzerinden yazılır (POST/DELETE …/categories/:id/photo);
//     önizleme aynı kökenden gelir (/api/v1/categories/photo/…, paket
//     görselleri /katalog-varlik/…). Yüklenmiş fotoğraf yoksa paket fotoğrafı.
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
        h('p', { class: 'not' }, 'Kaydedene kadar mevcut kayıt değişmez. Fotoğraf uygulamada kategori görseli olarak kullanılır.'),
        h('div', { class: 'tuslar' },
          h('button', { class: 'btn ikincil', onclick: () => kapat(false) }, 'Vazgeç'),
          h('button', { class: 'btn', onclick: () => kapat(true) }, 'Kaydet'))));
    document.body.append(perde);
  });
}

const YAZABILIR = ['super_admin', 'content']; // backend catalog.write ile aynı
const dosyaAdi = (yol) => (yol ? String(yol).split('/').pop() : null);
const kucuk = (s) => s.toLocaleLowerCase('tr-TR');

export async function katalogSayfasi(rol) {
  const yazabilir = YAZABILIR.includes(rol);
  let kategoriler = [];
  let ikonlar = [];
  let seciliId = null;
  let istekNo = 0;

  const ara = h('input', { class: 'ku-ara kt-ara', type: 'search', placeholder: 'Kategori ara', 'aria-label': 'Kategori ara' });
  const sayac = h('div', { class: 'ku-sayac', hidden: true });
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
      const [k, i] = await Promise.all([api('/catalog/categories'), ikonlar.length ? ikonlar : api('/catalog/icons').catch(() => [])]);
      if (no !== istekNo) return;
      kategoriler = k;
      ikonlar = i;
    } catch (e) {
      if (no !== istekNo) return;
      katListe.replaceChildren(h('div', { class: 'ku-bos' },
        h('div', { class: 'ku-bos-baslik' }, e.durum === 403 ? 'Yetkiniz yok' : 'Katalog yüklenemedi'),
        h('p', { class: 'oz-bos' }, e.durum === 403 ? 'Kataloğu görüntüleme yetkiniz bulunmuyor.' : (e.message || 'Beklenmeyen bir hata oluştu.')),
        e.durum === 403 ? null : h('button', { class: 'btn ikincil', onclick: () => kategorileriYukle() }, 'Tekrar dene')));
      return;
    }
    sayac.hidden = false;
    sayac.textContent = `${kategoriler.length.toLocaleString('tr-TR')} kategori`;
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
    gorsel(k.photoUrl || k.bundledPhotoUrl, 'kt-kucuk-gorsel', 'Yok'),
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
        h('div', { class: 'kt-foto-alani' },
          h('div', { class: 'oz-etiket' }, 'Kategori fotoğrafı'),
          gorsel(k.photoUrl || k.bundledPhotoUrl, 'kt-buyuk'),
          h('div', { class: 'ku-eposta' }, k.photoUrl
            ? `Admin'den yüklendi · ${dosyaAdi(k.photoRef)}`
            : (k.photo ? `Uygulama paketi · ${dosyaAdi(k.photo)}` : 'Fotoğraf yok')),
          yazabilir ? h('div', { class: 'kt-tuslar' },
            h('button', { class: 'btn ikincil kt-kucuk', onclick: () => fotoDegistir(k) }, k.photoUrl || k.photo ? 'Fotoğrafı değiştir' : 'Fotoğraf ekle'),
            k.photoRef ? h('button', { class: 'btn tehlike kt-kucuk', onclick: () => fotoKaldir(k) }, 'Fotoğrafı kaldır') : null) : null),
        h('div', { class: 'kt-ikon-alani' },
          h('div', { class: 'oz-etiket' }, 'İkon'),
          gorsel(k.iconUrl, 'kt-ikon', 'Genel ikon'),
          h('div', { class: 'ku-eposta' }, dosyaAdi(k.icon) ?? 'Genel ikon'))),
      h('div', { class: 'kd-bilgi-izgara kt-bilgi' },
        h('div', { class: 'kd-bilgi' }, h('div', { class: 'oz-etiket' }, 'Katalog sırası'), h('div', { class: 'kd-deger' }, String(kategoriler.indexOf(k) + 1))),
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
  async function kategoriEkle() {
    const d = await form('Yeni kategori', [
      { ad: 'name', etiket: 'Kategori adı (2–100 karakter)', zorunlu: true },
      { ad: 'icon', etiket: 'İkon (uygulama paketindeki ikonlar)', tur: 'select', deger: '', secenekler: ikonSecenekleri(null) },
      { ad: 'foto', etiket: 'Oluşturduktan sonra fotoğraf seç (JPEG/PNG/WEBP, en fazla 5 MB)', tur: 'checkbox', deger: true },
    ], 'Oluştur', { aciklama: 'Yeni kategori kataloğun SONUNA eklenir; mevcut sıra değişmez. Uygulamada görünmesi için en az bir hizmet ekleyin.' });
    if (!d) return;
    try {
      const k = await api('/catalog/categories', { yontem: 'POST', govde: { name: d.name, ...(d.icon ? { icon: d.icon } : {}) } });
      bildir('Kategori oluşturuldu');
      seciliId = k.id;
      if (d.foto) {
        const secim = await dosyaSec();
        if (secim && await onizlemeOnayi(`Fotoğraf — ${k.name}`, secim)) {
          try { await fotoGonder(k.id, secim); bildir('Kategori ve fotoğraf kaydedildi'); } catch (e) { hataGoster(e); }
        }
      }
      await kategorileriYukle();
      duzen.classList.add('detay-acik');
    } catch (e) { hataGoster(e); }
  }

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

  async function fotoGonder(id, secim) {
    await api(`/catalog/categories/${id}/photo`, { yontem: 'POST', govde: { contentType: secim.tur, data: secim.veri } });
  }

  async function fotoDegistir(k) {
    const secim = await dosyaSec();
    if (!secim) return;
    if (!(await onizlemeOnayi(`Fotoğraf — ${k.name}`, secim, k.photoUrl || k.bundledPhotoUrl || null))) return;
    try {
      await fotoGonder(k.id, secim);
      bildir('Fotoğraf kaydedildi');
      await kategorileriYukle(); // gerçek kayıt yeniden okunur
    } catch (e) { hataGoster(e); }
  }

  async function fotoKaldir(k) {
    const d = await form(`Fotoğraf kaldırılsın mı? — ${k.name}`, [], 'Kaldır', {
      tehlike: true,
      aciklama: k.photo ? 'Yüklenen fotoğraf depodan silinir; uygulama bu kategoride paketindeki fotoğrafa döner.' : 'Yüklenen fotoğraf depodan silinir; kategori fotoğrafsız kalır.',
    });
    if (!d) return;
    try {
      await api(`/catalog/categories/${k.id}/photo`, { yontem: 'DELETE', govde: {} });
      bildir('Fotoğraf kaldırıldı');
      await kategorileriYukle();
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

  ara.addEventListener('input', () => listeyiCiz()); // katalog API'si listenin TAMAMINI verir

  await kategorileriYukle();
  if (!seciliId && kategoriler[0]) { seciliId = kategoriler[0].id; listeyiCiz(); await hizmetleriYukle(seciliId); }

  duzen.replaceChildren(
    h('section', { class: 'oz-kart kt-sol' }, h('div', { class: 'kt-sol-ust' }, ara), katListe),
    h('section', { class: 'oz-kart kt-sag' }, detay));

  return h('div', { class: 'oz ku kt' },
    h('div', { class: 'oz-baslik' },
      h('div', {}, h('h2', {}, 'Kategori ve Hizmetler'), h('p', {}, 'Uygulamadaki katalog; sıra ve içerik buradan yönetilir, değişiklikler doğrudan veritabanına kaydedilir')),
      h('div', { class: 'kt-ust-sag' }, sayac, yazabilir ? h('button', { class: 'btn', onclick: kategoriEkle }, '+ Yeni Kategori') : null)),
    duzen);
}
