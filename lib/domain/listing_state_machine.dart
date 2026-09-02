import '../data/models/listing.dart';

/// İlan durum makinesi — İZİNLİ geçişlerin TEK merkezi tanımı.
/// completed uç durumdur: iptal/süre dolumu/silme YAPILAMAZ;
/// tamamlanmış işin blokesi asla iade akışına giremez.
abstract final class ListingStateMachine {
  /// ── ⚠ NİHAİ GEÇİŞ TABLOSU (API sözleşmesi §24) ──
  ///
  /// Eski tablo altı durumluydu ve `open → providerSelected →
  /// inProgress → completed` zincirini taşıyordu. O zincir İŞİN
  /// GİDİŞATIYDI, ilanın yaşamı değil; ikisi tek alanda karışıyordu.
  ///
  /// Nihai tablo yalnız YAŞAM geçişlerini tanımlar:
  ///   · `active` → süresi dolabilir, kullanıcı silebilir, admin
  ///     kaldırabilir
  ///   · kapanmış üç durumdan GERİ DÖNÜŞ YOKTUR
  ///
  /// ⚠ TEKLİF SEÇİMİ BU TABLODA YOKTUR. Seçim ilanın durumunu
  static const Map<ListingStatus, Set<ListingStatus>> transitions = {
    ListingStatus.active: {
      ListingStatus.expired,
      ListingStatus.userDeleted,
      ListingStatus.adminRemoved,
    },
    ListingStatus.expired: {
      // Süresi dolmuş ilan kullanıcı tarafından silinebilir (§12) ve
      // admin tarafından kaldırılabilir.
      ListingStatus.userDeleted,
      ListingStatus.adminRemoved,
    },
    ListingStatus.userDeleted: {},
    ListingStatus.adminRemoved: {},
  };

  static bool canTransition(ListingStatus from, ListingStatus to) =>
      transitions[from]?.contains(to) ?? false;

  /// ⚠ TAMAMLANMIŞ İŞ SİLİNEMEZ.
  ///
  /// Eski kural "completed hariç hepsi silinebilir" idi ve `completed`
  /// bir durumdu. Artık tamamlanmışlık `selectedOfferId` ile
  /// belirlendiği için denetim de oradan yapılır — bu yüzden
  /// `canDelete` artık İLANI alır, yalnız durumu değil.
  static bool canDelete(Listing l) =>
      l.selectedOfferId == null &&
      (l.status == ListingStatus.active || l.status == ListingStatus.expired);
}
