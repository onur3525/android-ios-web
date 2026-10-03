// ═══════════════════════════════════════════════════════════════
// KULLANICI DETAY — Özet/Kullanıcılar ile aynı görsel dil (.oz-* .ku-* .kd-*)
//
// YALNIZ MEVCUT UÇLAR (backend değişmedi; demo/sahte veri YOK):
//   GET  /admin/v1/users/:id                  profil, durum, durum geçmişi,
//                                             oturumlar, SMS/e-posta kayıtları
//   GET  /admin/v1/listings?ownerId=          ilanları
//   GET  /admin/v1/offers?providerId=         teklifleri
//   GET  /admin/v1/teklif-talepleri?hizmetAlanId= / ?saglayiciId=
//   GET  /admin/v1/reviews?providerId= / ?authorId=
//   GET  /admin/v1/users/:id/legal-acceptances
//   GET  /admin/v1/account-requests           (bu kullanıcıya ait olanlar)
//   POST /admin/v1/users/:id/{suspend|unsuspend|ban|unban}  (gerekçe + yeniden doğrulama)
// Bölümler bağımsız yüklenir; yetkisi olmayan bölüm "Yetkiniz yok" der.
// ═══════════════════════════════════════════════════════════════
import { api, bildir, gerekceIle, h } from './cekirdek.js';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DURUM_ADI = { ACTIVE: 'Aktif', SUSPENDED: 'Askıda', BANNED: 'Banlı' };
const ROL_ADI = { CUSTOMER: 'Hizmet Alan', PROVIDER: 'Hizmet Veren' };
const ROZET_ADI = {
  ACTIVE: 'Aktif', EXPIRED: 'Süresi doldu', USER_DELETED: 'Sahibi sildi', ADMIN_REMOVED: 'Yönetim kaldırdı',
  SELECTED: 'Seçildi', CLOSED: 'Kapandı', PUBLISHED: 'Yayında', ADMIN_DELETED: 'Yönetim kaldırdı',
  PENDING: 'Bekliyor', SENT: 'Gönderildi', FAILED: 'Başarısız', COMPLETED: 'Tamamlandı', CANCELLED: 'İptal',
  BEKLEMEDE: 'Beklemede', TEKLIF_GELDI: 'Teklif geldi', SECILDI: 'Seçildi', REDDEDILDI: 'Reddedildi',
  SURESI_DOLDU: 'Süresi doldu', TAMAMLANDI: 'Tamamlandı',
};
const SABLON_ADI = {
  HESAP_ASKIYA_ALINDI: 'Hesap askıya alındı', HESAP_ASKI_KALDIRILDI: 'Askı kaldırıldı',
  HESAP_BANLANDI: 'Hesap banlandı', HESAP_BAN_KALDIRILDI: 'Ban kaldırıldı', ILAN_KALDIRILDI: 'İlan kaldırıldı',
};
const OTURUM_KAPANIS = {
  LOGOUT: 'Çıkış yaptı', ROTATED: 'Yenilendi', USER_REVOKED: 'Kullanıcı sonlandırdı', PASSWORD_CHANGED: 'Şifre değişti',
  PASSWORD_RESET: 'Şifre sıfırlandı', SUSPENDED: 'Askıya alındı', BANNED: 'Banlandı', FROZEN: 'Hesap donduruldu',
  DELETED: 'Hesap silindi', REUSE_DETECTED: 'Güvenlik: token yeniden kullanımı',
};

const tarihSaat = (v) => (v ? new Date(v).toLocaleString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—');
const kisaTarih = (v) => (v ? new Date(v).toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '—');
const rozet = (v) => h('span', { class: `ku-durum kd-rozet ${v}` }, ROZET_ADI[v] ?? v);

function basHarfler(ad) {
  const p = String(ad || '').trim().split(/\s+/).filter(Boolean);
  return ((p[0]?.[0] ?? '') + (p.length > 1 ? p[p.length - 1][0] : '')).toLocaleUpperCase('tr-TR') || '?';
}

function bilgi(etiket, deger) {
  return h('div', { class: 'kd-bilgi' }, h('div', { class: 'oz-etiket' }, etiket), h('div', { class: 'kd-deger' }, deger ?? '—'));
}

function dogrulama(etiket, dogru) {
  return h('span', { class: `ku-dogrulama ${dogru ? 'evet' : 'hayir'}` }, dogru ? `✓ ${etiket} doğrulanmış` : `${etiket} doğrulanmamış`);
}

function tablo(kolonlar, satirlar, tikla) {
  if (!satirlar?.length) return h('p', { class: 'oz-bos kd-bos' }, 'Kayıt yok.');
  return h('div', { class: 'oz-tablo-sar' }, h('table', { class: 'oz-tablo kd-tablo' },
    h('thead', {}, h('tr', {}, kolonlar.map((k) => h('th', {}, k[0])))),
    h('tbody', {}, satirlar.map((s) => h('tr', { class: tikla ? 'tikla' : '', onclick: tikla ? () => tikla(s) : null },
      kolonlar.map((k) => h('td', { 'data-baslik': k[0] }, k[1](s))))))));
}

const durumMesaji = (e) => (e?.durum === 403 ? 'Bu bölüm için yetkiniz yok.' : 'Veri alınamadı. Lütfen sayfayı yenileyin.');

function hataEkrani(baslik, aciklama) {
  return h('div', { class: 'oz ku' },
    h('section', { class: 'oz-kart kd-hata' },
      h('div', { class: 'ku-bos-baslik' }, baslik),
      h('p', { class: 'oz-bos' }, aciklama),
      h('a', { class: 'btn ikincil', href: '#/kullanicilar' }, '‹ Kullanıcılara dön')));
}

export async function kullaniciDetaySayfasi(id, yenile) {
  if (!UUID.test(String(id || ''))) return hataEkrani('Kullanıcı bulunamadı', 'Adres geçerli bir kullanıcıya ait değil.');

  let u;
  try {
    u = await api(`/users/${id}`);
  } catch (e) {
    if (e.durum === 404) return hataEkrani('Kullanıcı bulunamadı', 'Bu kullanıcı kaydı mevcut değil ya da kaldırılmış.');
    if (e.durum === 403) return hataEkrani('Yetkiniz yok', 'Kullanıcı ayrıntılarını görüntüleme yetkiniz bulunmuyor.');
    return hataEkrani('Kullanıcı yüklenemedi', e.message || 'Beklenmeyen bir hata oluştu.');
  }

  // ── Faaliyet kaynakları: paralel, bağımsız ──
  const al = (yol) => api(yol).then((v) => ({ v }), (e) => ({ e }));
  const [il, te, taA, taV, yoP, yoA, ya, gt] = await Promise.all([
    al(`/listings?ownerId=${encodeURIComponent(id)}&limit=200`),
    al(`/offers?providerId=${encodeURIComponent(id)}`),
    al(`/teklif-talepleri?hizmetAlanId=${encodeURIComponent(id)}`),
    al(`/teklif-talepleri?saglayiciId=${encodeURIComponent(id)}`),
    al(`/reviews?providerId=${encodeURIComponent(id)}`),
    al(`/reviews?authorId=${encodeURIComponent(id)}`),
    al(`/users/${encodeURIComponent(id)}/legal-acceptances`),
    al('/account-requests'),
  ]);
  const ilanlar = il.v?.items;
  const talepler = taA.e || taV.e ? null : [...taA.v, ...taV.v].sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt));
  const yorumlar = yoP.e || yoA.e ? null : [...yoP.v.map((y) => ({ ...y, yon: 'Aldığı' })), ...yoA.v.map((y) => ({ ...y, yon: 'Verdiği' }))]
    .sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt));
  const gelen = gt.v ? gt.v.filter((a) => a.userId === id) : null;

  // ── Yönetim işlemleri (yalnız API'nin desteklediği 4 geçiş) ──
  const islem = async (eylem, baslik, aciklama) => {
    const neden = await gerekceIle(baslik, baslik, aciklama);
    if (!neden) return;
    try {
      const r = await api(`/users/${id}/${eylem}`, { yontem: 'POST', govde: { reason: neden } });
      bildir(`İşlem tamamlandı. Bildirim: ${r.notifications.map((n) => (n.status === 'SENT' ? 'gönderildi' : 'gönderilemedi')).join(', ') || 'gönderilmedi'}`);
      yenile(); // kullanıcı verisi API'den yeniden yüklenir
    } catch (e) {
      bildir(e.durum === 403 && e.kod !== 'REAUTH_REQUIRED' ? 'Bu işlem için yetkiniz yok.' : e.message, true);
    }
  };
  const silindi = !!u.deletedAt;
  const tuslar = silindi ? [] : [
    u.status === 'ACTIVE' ? h('button', { class: 'btn kd-turuncu', onclick: () => islem('suspend', 'Askıya al', 'Kullanıcının bütün oturumları kapanır; doğrulanmış telefon/e-postasına gerekçeyle bildirim gider.') }, 'Askıya al') : null,
    u.status === 'SUSPENDED' ? h('button', { class: 'btn', onclick: () => islem('unsuspend', 'Askıdan çıkar', 'Kullanıcı yeniden giriş yapabilir; bildirim gönderilir.') }, 'Askıdan çıkar') : null,
    u.status !== 'BANNED' ? h('button', { class: 'btn tehlike', onclick: () => islem('ban', 'Banla', 'Hesap kalıcı olarak kapatılır; bütün oturumlar sonlanır, giriş yapılamaz.') }, 'Banla') : null,
    u.status === 'BANNED' ? h('button', { class: 'btn', onclick: () => islem('unban', 'Banı kaldır', 'Kullanıcı yeniden giriş yapabilir; bildirim gönderilir.') }, 'Banı kaldır') : null,
  ].filter(Boolean);

  const sonEtkinlik = u.sessions.reduce((m, o) => (o.lastUsedAt && (!m || o.lastUsedAt > m) ? o.lastUsedAt : m), null);
  const acikOturum = u.sessions.filter((o) => !o.revokedAt).length;

  const ust = h('section', { class: 'oz-kart kd-ust' },
    h('div', { class: 'kd-kimlik' },
      h('span', { class: `ku-avatar kd-avatar ${u.roles.includes('PROVIDER') ? 'mor' : 'mavi'}`, 'aria-hidden': 'true' }, basHarfler(u.name)),
      h('div', { class: 'kd-kimlik-metin' },
        h('h2', {}, u.name),
        h('div', { class: 'kd-rozetler' },
          h('span', { class: `ku-durum ${u.status}` }, DURUM_ADI[u.status] ?? u.status),
          u.roles.map((r) => h('span', { class: `oz-rol ${r}` }, ROL_ADI[r] ?? r)),
          silindi ? h('span', { class: 'ku-durum BANNED' }, 'Hesap silinmiş') : null),
        h('div', { class: 'kd-id', title: 'Kullanıcı kimliği' }, `ID: ${u.id}`))),
    tuslar.length ? h('div', { class: 'kd-tuslar' }, tuslar) : null);

  const bilgiler = h('section', { class: 'oz-kart' },
    h('div', { class: 'oz-kart-ust' }, h('h3', {}, 'Hesap Bilgileri')),
    h('div', { class: 'kd-bilgi-izgara' },
      bilgi('Telefon', u.phone),
      bilgi('E-posta', u.email || '—'),
      bilgi('Aktif rol', ROL_ADI[u.activeRole] ?? u.activeRole),
      bilgi('Kayıt tarihi', tarihSaat(u.createdAt)),
      bilgi('Son oturum etkinliği', sonEtkinlik ? tarihSaat(sonEtkinlik) : 'Henüz bulunmuyor'),
      bilgi('Adres', u.address ? `${u.address.neighborhood}, ${u.address.district}, ${u.address.city}` : 'Henüz bulunmuyor'),
      u.providerProfile ? bilgi('Hizmet kategorileri', u.providerProfile.categories.join(', ') || '—') : null,
      u.providerProfile ? bilgi('Hizmet ilçeleri', u.providerProfile.districts.join(', ') || '—') : null),
    h('div', { class: 'kd-dogrulamalar' },
      dogrulama('Telefon', u.phoneVerified), dogrulama('E-posta', u.emailVerified),
      h('span', { class: `ku-dogrulama ${u.termsAccepted ? 'evet' : 'hayir'}` }, u.termsAccepted ? '✓ Sözleşme onaylı' : 'Sözleşme onayı yok')));

  // ── Sekmeler (sayılar gerçek; yetkisiz/başarısız bölüm sayısız) ──
  const sayiOf = (x) => (Array.isArray(x) ? x.length : null);
  const sekmeler = [
    ['İlanlar', il.e ? null : (il.v.total ?? sayiOf(ilanlar)), () => (il.e ? h('p', { class: 'oz-bos kd-bos' }, durumMesaji(il.e)) : tablo([
      ['No', (l) => l.ilanNo], ['Hizmet', (l) => l.title], ['Konum', (l) => l.location],
      ['Durum', (l) => rozet(l.status)], ['Oluşturulma', (l) => kisaTarih(l.createdAt)],
    ], ilanlar, (l) => (location.hash = `#/ilan/${l.id}`)))],
    ['Teklifler', te.e ? null : sayiOf(te.v), () => (te.e ? h('p', { class: 'oz-bos kd-bos' }, durumMesaji(te.e)) : tablo([
      ['Tutar (TL)', (o) => o.amountTl.toLocaleString('tr-TR')], ['Not', (o) => o.note || '—'],
      ['Durum', (o) => rozet(o.status)], ['Tarih', (o) => kisaTarih(o.createdAt)],
      ['İlan', () => h('span', { class: 'oz-tumu' }, 'İlanı aç ›')],
    ], te.v, (o) => (location.hash = `#/ilan/${o.listingId}`)))],
    ['Teklif Talepleri', talepler ? talepler.length : null, () => (!talepler ? h('p', { class: 'oz-bos kd-bos' }, durumMesaji(taA.e || taV.e)) : tablo([
      ['No', (t) => t.talepNo], ['Hizmet', (t) => `${t.kategori} / ${t.hizmet}`],
      ['Kullanıcının rolü', (t) => (t.hizmetAlanId === id ? 'Talep eden' : 'Hizmet veren')],
      ['Karşı taraf', (t) => (t.hizmetAlanId === id ? t.saglayiciAdi : 'Talep eden')],
      ['Durum', (t) => rozet(t.durum)], ['Tarih', (t) => kisaTarih(t.createdAt)],
    ], talepler, (t) => (location.hash = `#/talep/${t.id}`)))],
    ['Değerlendirmeler', yorumlar ? yorumlar.length : null, () => (!yorumlar ? h('p', { class: 'oz-bos kd-bos' }, durumMesaji(yoP.e || yoA.e)) : tablo([
      ['Yön', (y) => y.yon], ['Puan', (y) => h('span', { class: 'kd-yildiz' }, '★'.repeat(y.stars) + '☆'.repeat(5 - y.stars))],
      ['Yorum', (y) => y.text || '—'], ['Durum', (y) => rozet(y.status)], ['Tarih', (y) => kisaTarih(y.createdAt)],
      ['İlgili', (y) => (y.listingId ? 'İlan' : y.talepId ? 'Teklif talebi' : '—')],
    ], yorumlar, (y) => (y.listingId ? (location.hash = `#/ilan/${y.listingId}`) : y.talepId ? (location.hash = `#/talep/${y.talepId}`) : null)))],
    ['Oturumlar', u.sessions.length, () => tablo([
      ['Durum', (o) => (o.revokedAt ? h('span', { class: 'ku-durum kd-kapali' }, 'Kapalı') : h('span', { class: 'ku-durum ACTIVE' }, 'Açık'))],
      ['Cihaz / tarayıcı', (o) => o.userAgent || '—'],
      ['Açılış', (o) => tarihSaat(o.createdAt)], ['Son kullanım', (o) => tarihSaat(o.lastUsedAt)],
      ['Kapanış', (o) => (o.revokedAt ? `${tarihSaat(o.revokedAt)} · ${OTURUM_KAPANIS[o.revokeReason] ?? o.revokeReason ?? ''}` : '—')],
    ], u.sessions)],
    ['Bildirimler', u.notifications.length, () => h('div', {},
      h('p', { class: 'oz-bos' }, 'Yönetim işlemleri nedeniyle kullanıcıya gönderilen SMS ve e-postalar.'),
      tablo([
        ['Kanal', (n) => (n.channel === 'SMS' ? 'SMS' : 'E-posta')], ['Konu', (n) => SABLON_ADI[n.template] ?? n.template],
        ['Durum', (n) => rozet(n.status)], ['Sağlayıcı yanıtı', (n) => n.providerResponse || '—'], ['Tarih', (n) => tarihSaat(n.createdAt)],
      ], u.notifications))],
    ['Güvenlik', null, () => h('div', { class: 'kd-guvenlik' },
      h('div', { class: 'kd-bilgi-izgara' },
        bilgi('Hesap durumu', DURUM_ADI[u.status] ?? u.status),
        bilgi('Durum gerekçesi', u.statusReason || '—'),
        bilgi('Durum değişikliği', u.statusChangedAt ? tarihSaat(u.statusChangedAt) : '—'),
        bilgi('Açık oturum', String(acikOturum))),
      h('h4', {}, 'Durum geçmişi'),
      tablo([
        ['Önceki', (x) => DURUM_ADI[x.from] ?? x.from], ['Yeni', (x) => DURUM_ADI[x.to] ?? x.to],
        ['Gerekçe', (x) => x.reason], ['Yönetici', (x) => x.admin || '—'], ['Tarih', (x) => tarihSaat(x.at)],
      ], u.statusHistory),
      h('h4', {}, 'Yasal belge onayları'),
      ya.e ? h('p', { class: 'oz-bos kd-bos' }, durumMesaji(ya.e)) : tablo([
        ['Belge', (a) => a.slug], ['Sürüm', (a) => a.version], ['Platform', (a) => a.platform || '—'], ['Tarih', (a) => tarihSaat(a.acceptedAt)],
      ], ya.v),
      h('h4', {}, 'Gelen talepler'),
      !gelen ? h('p', { class: 'oz-bos kd-bos' }, durumMesaji(gt.e)) : tablo([
        ['Tür', (a) => (a.type === 'FREEZE' ? 'Hesap dondurma' : 'Hesap silme')], ['Durum', (a) => rozet(a.status)],
        ['Talep', (a) => tarihSaat(a.createdAt)], ['Planlanan', (a) => (a.scheduledFor ? tarihSaat(a.scheduledFor) : '—')],
      ], gelen))],
  ];

  const alan = h('div', { class: 'kd-sekme-icerik' });
  const dugmeler = sekmeler.map(([ad, sayi], i) => h('button', {
    class: 'ku-sekme', role: 'tab',
    onclick: () => sec(i),
  }, ad, sayi === null ? null : h('span', { class: 'ku-sekme-sayi' }, sayi.toLocaleString('tr-TR'))));
  function sec(i) {
    dugmeler.forEach((d, j) => { d.classList.toggle('secili', i === j); d.setAttribute('aria-selected', i === j ? 'true' : 'false'); });
    alan.replaceChildren(sekmeler[i][2]());
  }
  sec(0);

  return h('div', { class: 'oz ku kd' },
    h('a', { class: 'oz-tumu kd-geri', href: '#/kullanicilar' }, '‹ Kullanıcılar'),
    ust,
    bilgiler,
    h('section', { class: 'oz-kart' },
      h('div', { class: 'ku-sekmeler kd-sekmeler', role: 'tablist' }, dugmeler),
      alan));
}
