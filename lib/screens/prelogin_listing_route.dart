import 'package:flutter/material.dart';

import 'create_listing_screen.dart';

/// KAYIT ÖNCESİ İLAN HAZIRLAMA — PUBLIC ROUTE
///
/// ⚠ GÜVENLİK MODELİ
///
/// Bu route rol korumasının ALTINDA DEĞİLDİR; oturumsuz kullanıcının ilan
/// formunu doldurabilmesi içindir. Ancak hiçbir yetki VERMEZ:
///
///   • kullanıcıya `customer` rolü atanmaz,
///   • customer-only API uçları çağrılmaz,
///   • fotoğraflar backend'e YÜKLENMEZ (`uploadEnabled: false`),
///   • ilan YAYINLANMAZ — yalnız yerel taslak üretilir.
///
/// Gerçek yayın, kullanıcı Hizmet Alan olarak kayıt ve zorunlu
/// doğrulamaları tamamladıktan SONRA `PendingListingController`
/// üzerinden yapılır. `/customer/new-listing` korumalı kalmaya
/// devam eder ve bu route onu BYPASS ETMEZ; rol koruması
/// gevşetilmemiştir.
class PreLoginListingRoute {
  const PreLoginListingRoute._();

  static const String name = '/listing/new';
}

/// Kategori ekranı ve arama sonucundan taşınan seçim.
class PreLoginListingArgs {
  final String category;
  final String? subService;

  const PreLoginListingArgs({required this.category, this.subService});
}

/// Route oluşturucu — argüman yoksa güvenli varsayılana düşer.
Widget preLoginListingBuilder(BuildContext context) {
  final a = ModalRoute.of(context)?.settings.arguments;
  final args = a is PreLoginListingArgs ? a : null;
  return CreateListingScreen(
    initialCategory: args?.category,
    initialSubService: args?.subService,
    // ⚠ Kayıt öncesi mod: yükleme ve yayın KAPALI.
    preLogin: true,
  );
}
