import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// ═══════════════════════════════════════════════════════════════
/// DIŞ BAĞLANTI AÇILIŞ MODU — PLATFORMA GÖRE
///
/// ## ⚠ NİÇİN TEK YERDE
///
/// Yedi çağrı yeri `LaunchMode.externalApplication` yazıyordu. O mod
/// MOBİL İÇİN doğrudur: telefon uygulamasını, mağazayı veya tarayıcıyı
/// uygulamanın DIŞINDA açar.
///
/// ⚠ WEB'DE AYNI ANLAMA GELMEZ. Tarayıcıda "harici uygulama" diye bir
/// kavram yok; bu mod bazı tarayıcılarda `tel:` ve `mailto:`
/// bağlantılarında beklenmedik davranır veya sessizce başarısız olur.
/// `platformDefault`, tarayıcının kendi köprüsünü kullanır — telefon
/// bağlantısını işletim sistemine devreder, http adresini yeni
/// sekmede açar.
///
/// ⚠ MOBİL DAVRANIŞ DEĞİŞMEZ: `kIsWeb` değilse bugünkü mod aynen
/// döner. Android/iOS baseline'ı kilitli.
///
/// ⚠ YEDİ YERDE AYRI KOŞUL YAZILMADI: kural burada; çağıranlar
/// `acilisModu` çağırır. Biri güncellenip öteki unutulamaz.
///
/// ⚠ TELEFON ARAMASI WEB'DE ÇALIŞMAYABİLİR: masaüstünde `tel:`
/// bağlantısını karşılayacak bir uygulama kurulu olmayabilir. Çağıran
/// taraflar `launchUrl` sonucunu zaten denetleyip kullanıcıyı
/// uyarıyor; sahte başarı gösterilmiyor.
/// ═══════════════════════════════════════════════════════════════
LaunchMode acilisModu() =>
    kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
