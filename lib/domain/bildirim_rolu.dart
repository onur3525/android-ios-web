import '../data/models/account.dart';
import '../data/models/notification.dart';

/// ── ⚠ BİLDİRİM ROL SÜZGECİ — TEK KAYNAK ──
///
/// KULLANICI KURALI (9 Eyl): "Hizmet veren veya alan bir kişi mevcut
/// rolünden diğer role geçiş yaptığında diğer rolüne ait bildirimleri
/// vb. şeyleri GÖRMEMELİ."
///
/// ⚠ SORUNUN KAYNAĞI: `AppNotification` kayıtları yalnız `userId`
/// taşıyor, ROL taşımıyor. Aynı kişi iki rolde de aynı hesabı
/// kullandığı için (kimlik telefon/e-posta değil, değişmeyen
/// `userId`), hizmet alan rolündeyken "Teklifiniz seçildi" gibi
/// hizmet verene ait bildirimler de listeleniyordu.
///
/// ⚠ MODELE ALAN EKLENMEDİ: bildirimin hangi tarafa ait olduğu zaten
/// TÜRÜNDE saklı (`NotifType`). Yeni bir alan eklemek, geçmiş
/// kayıtların o alanı boş taşıması ve sunucunun da doldurması
/// gerektiği anlamına gelirdi. Eşleme burada, tek yerde tanımlı.
///
/// ⚠ SUNUCU TARAFI AYRI İŞ: bu süzgeç İSTEMCİDE çalışır. Gerçek
/// backend, `/notifications` yanıtını role göre süzmelidir; aksi hâlde
/// karşı rolün bildirimleri ağda taşınmaya devam eder. (Aynı
/// "istemci-only kural" uyarısı çıkar çatışması ve ilan ömrü için de
/// geçerli.)

/// Bu bildirim türü hangi rolde gösterilir?
///
/// `null` = HER İKİ ROLDE de gösterilir. İki durum vardır:
///   • Duyuru (`announcement`) — role bağlı değil, herkese.
///   • Bilinmeyen tür (`unknown`) — sunucu yeni bir tür eklediyse
///     GİZLENMEZ. Gizleseydik, tanımadığımız bir bildirim sessizce
///     kaybolurdu; görünür kalması daha güvenli.
Role? bildirimRolu(NotifType tur) => switch (tur) {
      // ── HİZMET ALAN (ilan sahibi) ──
      NotifType.newOffer => Role.customer,
      NotifType.listingExpired => Role.customer,
      NotifType.teklifVerildi => Role.customer,
      NotifType.teklifIsiTamamlandi => Role.customer,

      // ── HİZMET VEREN (usta) ──
      NotifType.offerSelected => Role.provider,
      NotifType.refund => Role.provider,
      NotifType.accountStatus => Role.provider,
      NotifType.categoryRequest => Role.provider,
      NotifType.teklifTalebiGeldi => Role.provider,
      NotifType.teklifSecildi => Role.provider,
      NotifType.teklifReddedildi => Role.provider,
      NotifType.teklifSuresiDoldu => Role.provider,

      // ── HER İKİ ROL ──
      //
      // ⚠ İLETİŞİM VE MESAJ İKİ TARAFA DA GİDER: "iletişim açıldı" ve
      // "yeni mesaj" bildirimleri karşı taraf kim olursa olsun
      // üretilir; tek bir role bağlanamaz. Rol değiştiren kullanıcı
      // kendi sohbetini kaybetmemeli.
      NotifType.contactOpened => null,
      NotifType.newMessage => null,
      NotifType.teklifYeniMesaj => null,
      NotifType.announcement => null,
      NotifType.unknown => null,
    };

/// [rol] için görünmesi gereken bildirimler.
List<AppNotification> rolBildirimleri(
  List<AppNotification> hepsi,
  Role rol,
) =>
    [
      for (final n in hepsi)
        if (bildirimRolu(n.type) == null || bildirimRolu(n.type) == rol) n,
    ];

/// [rol] için okunmamış bildirim sayısı.
///
/// ⚠ ROZET DE SÜZÜLÜR: liste süzülüp rozet süzülmeseydi kullanıcı
/// "3 okunmamış" görüp listeyi açtığında hiçbir şey bulamazdı.
int rolOkunmamisSayisi(List<AppNotification> hepsi, Role rol) =>
    rolBildirimleri(hepsi, rol).where((n) => !n.read).length;
