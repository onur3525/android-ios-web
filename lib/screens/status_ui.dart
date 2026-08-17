import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/models/listing.dart';
import '../data/models/offer.dart';

/// Durum → etiket/renk eşlemesi (HTML rozet dili).
(String, Color) listingStatusUi(ListingStatus s) => switch (s) {
      ListingStatus.open => ('Açık', HC.green),
      // ⚠ "Usta" DEĞİL — katalog tüm meslekleri kapsıyor.
      ListingStatus.providerSelected => ('Hizmet Veren Seçildi', HC.blue),
      ListingStatus.inProgress => ('Devam Ediyor', HC.orange),
      ListingStatus.completed => ('Tamamlandı', HC.green),
      ListingStatus.cancelled => ('İptal Edildi', HC.red),
      ListingStatus.expired => ('Süresi Doldu', HC.lightGrey),
    };

(String, Color) offerStatusUi(OfferStatus s) => switch (s) {
      OfferStatus.active => ('Aktif', HC.blue),
      OfferStatus.selected => ('Seçildi', HC.green),
      OfferStatus.cancelled => ('İptal', HC.lightGrey),
    };

String tl(int v) => '₺$v';
