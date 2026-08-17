import '../data/models/listing.dart';

/// İlan durum makinesi — İZİNLİ geçişlerin TEK merkezi tanımı.
/// completed uç durumdur: iptal/süre dolumu/silme YAPILAMAZ;
/// tamamlanmış işin blokesi asla iade akışına giremez.
abstract final class ListingStateMachine {
  static const Map<ListingStatus, Set<ListingStatus>> transitions = {
    ListingStatus.open: {
      ListingStatus.providerSelected,
      ListingStatus.cancelled,
      ListingStatus.expired,
    },
    ListingStatus.providerSelected: {
      // ⚠ AYRI "İŞİ BAŞLAT" ADIMI KALDIRILDI.
      //
      // Ürün kararı: teklif seçildikten sonra iş fiilen başlamıştır;
      // ayrıca "başlat" demek kullanıcıya fazladan bir adım yüklüyor
      // ve unutulduğunda ilan tamamlanamaz duruma düşüyordu.
      //
      // `inProgress` GEÇİŞİ KORUNUR: eski kayıtlar bu durumda olabilir
      // ve backend bu durumu göndermeye devam edebilir.
      ListingStatus.completed,
      ListingStatus.inProgress,
      ListingStatus.cancelled,
    },
    ListingStatus.inProgress: {
      ListingStatus.completed,
      ListingStatus.cancelled,
    },
    ListingStatus.completed: {},
    ListingStatus.cancelled: {},
    ListingStatus.expired: {},
  };

  static bool canTransition(ListingStatus from, ListingStatus to) =>
      transitions[from]?.contains(to) ?? false;

  /// Silinebilir durumlar: completed HARİÇ hepsi
  /// (kapalı ilanların silinmesi arşiv temizliğidir; blokeler zaten çözülmüştür).
  static const Set<ListingStatus> deletable = {
    ListingStatus.open,
    ListingStatus.providerSelected,
    ListingStatus.inProgress,
    ListingStatus.cancelled,
    ListingStatus.expired,
  };

  static bool canDelete(ListingStatus s) => deletable.contains(s);
}
