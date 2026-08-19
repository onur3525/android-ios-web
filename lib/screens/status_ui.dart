import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/models/listing.dart';
import '../data/models/offer.dart';

/// Durum → etiket/renk eşlemesi (HTML rozet dili).
/// ⚠ YALNIZ YAŞAM DURUMU (§24). "Tamamlandı" burada YOKTUR —
/// tamamlanmışlık `Listing.isTamamlanmisIs` ile türetilir ve
/// `listingRozetiUi` ile çizilir.
(String, Color) listingStatusUi(ListingStatus s) => switch (s) {
      ListingStatus.active => ('Açık', HC.green),
      ListingStatus.expired => ('Süresi Doldu', HC.lightGrey),
      ListingStatus.userDeleted => ('Kapatıldı', HC.lightGrey),
      ListingStatus.adminRemoved => ('Kaldırıldı', HC.red),
    };

/// İLANIN GÖRÜNEN ROZETİ — tamamlanmışlık dâhil.
///
/// ⚠ TEK KAYNAK: ekranlar "Tamamlandı" etiketini kendileri
/// hesaplamaz. Sıra önemlidir — tamamlanmış bir iş sonradan
/// silinse de "Tamamlandı" kalır.
(String, Color) listingRozetiUi(Listing l) =>
    l.isTamamlanmisIs ? ('Tamamlandı', HC.green) : listingStatusUi(l.status);

(String, Color) offerStatusUi(OfferStatus s) => switch (s) {
      OfferStatus.active => ('Aktif', HC.blue),
      OfferStatus.selected => ('Seçildi', HC.green),
      // ⚠ Nihai sözleşmede kapanış İKİ durumdur (§24).
      OfferStatus.expired => ('Süresi Doldu', HC.lightGrey),
      OfferStatus.closed => ('Kapandı', HC.lightGrey),
    };

String tl(int v) => '₺$v';
