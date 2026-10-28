// ═══════════════════════════════════════════════════════════════
// DENETİM DİLİ — TEK KAYNAK (28 Eki, kullanıcı isteği)
//
// Denetim kaydındaki teknik işlem kodları ("catalog.service.delete") ve ham
// değişiklik verisi okunur Türkçeye çevrilir. Yönetici detay sayfası
// (yonetici_detay.js) ve genel Denetim Kaydı sayfası AYNI metinleri kullanır.
// Bilinmeyen kod olduğu gibi gösterilir (kayıt gizlenmez).
// ═══════════════════════════════════════════════════════════════
import { h } from './cekirdek.js';

export const ROL_ADLARI = [['super_admin', 'Süper yönetici'], ['moderator', 'Moderatör'], ['content', 'İçerik yöneticisi'], ['operations', 'Operasyon'], ['readonly', 'Salt okunur']];
const ROL = Object.fromEntries(ROL_ADLARI);

const ISLEM_ADI = {
  'auth.login': 'Giriş yaptı',
  'auth.logout': 'Çıkış yaptı',
  'auth.session_end': 'Oturum kapandı',
  'auth.login_failed': 'Hatalı şifreyle giriş denemesi',
  'auth.mfa_failed': 'Hatalı doğrulama kodu girişi',
  'auth.reauth_failed': 'İşlem onayında hatalı şifre/kod',
  'auth.password_changed': 'Kendi şifresini değiştirdi',
  'admin.create': 'Yönetici ekledi',
  'admin.update': 'Yöneticiyi düzenledi',
  'admin.delete': 'Yönetici sildi',
  'admin.mfa_yenilendi': 'Yöneticinin doğrulama anahtarı yenilendi (bakım aracı)',
  'user.view': 'Kullanıcı detayını görüntüledi',
  'user.suspend': 'Kullanıcıyı askıya aldı',
  'user.unsuspend': 'Kullanıcının askısını kaldırdı',
  'user.ban': 'Kullanıcıyı banladı',
  'user.unban': 'Kullanıcının banını kaldırdı',
  'user.login.unlock': 'Kullanıcının giriş kilidini kaldırdı',
  'listing.remove': 'İlanı kaldırdı',
  'review.remove': 'Değerlendirmeyi kaldırdı',
  'chat.messages.view': 'Sohbet mesajlarını görüntüledi',
  'talep.messages.view': 'Teklif talebi mesajlarını görüntüledi',
  'catalog.category.create': 'Kategori ekledi',
  'catalog.category.update': 'Kategoriyi düzenledi',
  'catalog.category.delete': 'Kategoriyi kaldırdı',
  'catalog.service.create': 'Hizmet ekledi',
  'catalog.service.update': 'Hizmeti düzenledi',
  'catalog.service.delete': 'Hizmeti kaldırdı',
  'catalog.roof.update': 'Çatı kategorisini düzenledi',
  'catalog.roof.photo.set': 'Çatı fotoğrafı yükledi',
  'catalog.roof.photo.remove': 'Çatı fotoğrafını kaldırdı',
  'region.import': 'Hazır listeden il/ilçe ekledi',
  'region.city.create': 'İl ekledi', 'region.city.update': 'İli düzenledi', 'region.city.delete': 'İli kaldırdı',
  'region.district.create': 'İlçe ekledi', 'region.district.update': 'İlçeyi düzenledi', 'region.district.delete': 'İlçeyi kaldırdı',
  'region.neighborhood.create': 'Mahalle ekledi', 'region.neighborhood.update': 'Mahalleyi düzenledi', 'region.neighborhood.delete': 'Mahalleyi kaldırdı',
  'legal.document.create': 'Yasal belge oluşturdu',
  'legal.document.update': 'Yasal belgeyi düzenledi',
  'legal.version.create': 'Yasal belge sürümü hazırladı',
  'legal.version.publish': 'Yasal belge sürümünü yayınladı',
  'legal.version.archive': 'Yasal belge sürümünü arşivledi',
  'support.ticket.view': 'Destek talebini görüntüledi',
  'support.ticket.reply': 'Destek talebine yanıt verdi',
  'support.ticket.close': 'Destek talebini kapattı',
  'announcement.send': 'Duyuru gönderdi',
  'config.app.update': 'Uygulama ayarlarını değiştirdi',
  'integration.create': 'Entegrasyon ekledi',
  'integration.update': 'Entegrasyonu düzenledi',
  'integration.delete': 'Entegrasyonu sildi',
  'integration.test': 'Entegrasyonu test etti',
  'integration.secret.set': 'Entegrasyon gizli anahtarını değiştirdi',
  'integration.inbound_secret.set': 'Gelen e-posta anahtarını değiştirdi',
  'maintenance.tester.add': 'Bakım test hesabı ekledi',
  'maintenance.tester.remove': 'Bakım test hesabını kaldırdı',
  'maintenance.device.remove': 'Test hesabının tanınmış cihazını kaldırdı',
  'backup_monitor.set': 'Yedekleme izlemesini ayarladı',
  'backup_monitor.delete': 'Yedekleme izlemesini kaldırdı',
  'deletion.queue.retry': 'Silme işini yeniden denetti',
  'storage.delete.failed': 'Depodan dosya silinemedi (sistem)',
};

/** İşlem türü süzgeci: işlem kodunun ön eki → ad (sunucu `type` parametresi). */
export const ISLEM_TURLERI = [
  ['auth', 'Oturum ve güvenlik'], ['user', 'Kullanıcılar'], ['listing', 'İlanlar'], ['review', 'Değerlendirmeler'],
  ['catalog', 'Kategori ve hizmetler'], ['region', 'İl / ilçe / mahalle'], ['legal', 'Yasal belgeler'],
  ['support', 'Gelen talepler'], ['announcement', 'Duyurular'], ['config', 'Uygulama ayarları'],
  ['integration', 'Entegrasyonlar'], ['admin', 'Yöneticiler'], ['maintenance', 'Bakım'],
  ['chat', 'Sohbet görüntüleme'], ['talep', 'Teklif talebi görüntüleme'],
];

/** Oturum kapanış nedenleri (sunucu: OTURUM_KAPANIS). */
export const KAPANIS_NEDENI = {
  CIKIS: 'Çıkış yaptı', HAREKETSIZLIK: '15 dk hareketsizlik', SURE_DOLDU: '8 saatlik süre doldu',
  SIFRE_DEGISTI: 'Şifre değişti', YONETICI_SILINDI: 'Yönetici silindi', YONETICI_PASIF: 'Yönetici pasife alındı',
  HESAP_KILITLENDI: 'Hatalı denemeler: hesap kilitlendi', MFA_YENILENDI: 'Doğrulama anahtarı yenilendi',
};

const ALAN_ADI = {
  name: 'Ad', title: 'Başlık', email: 'E-posta', role: 'Rol', active: 'Aktif', status: 'Durum', sort: 'Sıra',
  icon: 'İkon', lider: 'Aramada öne çıkan', kartDisi: 'Ana sayfa ızgarasında yok', photoRef: 'Fotoğraf', slug: 'Belge',
  version: 'Sürüm', platform: 'Platform', message: 'Mesaj', text: 'Metin', stars: 'Puan', type: 'Tür', provider: 'Sağlayıcı',
  lockedUntil: 'Giriş kilidi', lockedConnections: 'Kilitli bağlantı', parent: 'Üst bölge', city: 'İl', count: 'Adet',
  recipients: 'Alıcı', target: 'Hedef', ilanNo: 'İlan no', ownerId: 'Sahibi', category: 'Kategori',
  latestVersion: 'Son sürüm', minSupportedVersion: 'En düşük desteklenen sürüm', maintenanceActive: 'Bakım modu',
  maintenanceMessage: 'Bakım mesajı', maintenanceEndAt: 'Bakım bitişi', requiresAcceptance: 'Onay gerekli',
  cihaz: 'Cihaz / tarayıcı',
};

export const islemAdi = (kod) => ISLEM_ADI[kod] ?? kod;

function deger(anahtar, v) {
  if (v === null || v === undefined || v === '') return '—';
  if (v === true) return 'Evet';
  if (v === false) return 'Hayır';
  if (anahtar === 'role') return ROL[v] ?? v;
  if (Array.isArray(v)) return v.length > 6 ? `${v.length} kayıt` : v.map((x) => deger('', x)).join(', ');
  if (typeof v === 'object') return JSON.stringify(v);
  const s = String(v);
  return s.length > 140 ? `${s.slice(0, 140)}…` : s;
}

/** Kaydın konusu: kaldırılan/eklenen şeyin adı ya da e-postası. */
export function islemKonusu(x) {
  const k = { ...(x.after || {}), ...(x.before || {}) };
  return k.name ?? k.title ?? k.email ?? k.slug ?? (k.ilanNo ? `İlan No ${k.ilanNo}` : null);
}

/** Satır özeti: "Hizmeti kaldırdı: Çim Halı / Suni Çim". */
export function islemOzeti(x) {
  if (x.action === 'auth.session_end') {
    const n = x.after?.neden;
    return `Oturum kapandı · ${KAPANIS_NEDENI[n] ?? n ?? 'neden bilinmiyor'}`;
  }
  const konu = islemKonusu(x);
  return konu ? `${islemAdi(x.action)}: ${konu}` : islemAdi(x.action);
}

/**
 * Listede gösterilsin mi? Çıkışta iki kayıt oluşur (auth.logout ve nedeni
 * CIKIS olan auth.session_end); ikincisi listede tekrar gösterilmez. Oturum
 * tablosunda ikisi tek satırdır.
 */
export const listedeGorunur = (x) => !(x.action === 'auth.session_end' && x.after?.neden === 'CIKIS');

/** Değişiklik ayrıntısı: "Ad: Eski → Yeni" satırları (yalnız değişen alanlar). */
export function degisiklikAyrintisi(x) {
  if (x.action === 'auth.session_end' || x.action === 'auth.login') return null;
  // Kaldırma: konu satır özetinde zaten yazıyor; tekrar edilmez.
  if (x.before && !x.after) return null;
  const once = x.before || {};
  const sonra = x.after || {};
  const anahtarlar = [...new Set([...Object.keys(once), ...Object.keys(sonra)])];
  const satirlar = [];
  for (const a of anahtarlar) {
    const o = once[a];
    const s = sonra[a];
    if (JSON.stringify(o) === JSON.stringify(s)) continue;
    const ad = ALAN_ADI[a] ?? a;
    if (o === undefined) satirlar.push(`${ad}: ${deger(a, s)}`);
    else if (s === undefined) satirlar.push(`${ad}: ${deger(a, o)}`);
    else satirlar.push(`${ad}: ${deger(a, o)} → ${deger(a, s)}`);
  }
  return satirlar.length ? h('div', { class: 'dn-degisiklik' }, satirlar.map((t) => h('div', {}, t))) : null;
}
