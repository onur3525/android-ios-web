import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/controllers/auth_controller.dart';
import '../data/controllers/incelenen_ilan_controller.dart';
import '../data/controllers/pending_listing_controller.dart';

/// ═══════════════════════════════════════════════════════════════
/// OTURUM KAPATMA — TOKEN VE YEREL VERİ BİRLİKTE
///
/// ## NİÇİN AYRI BİR FONKSİYON
///
/// ⚠ BULGU (güvenlik denetimi): `AuthController.logout()` yalnız
/// oturum jetonlarını siliyordu. Cihazda kalan kutular:
///   · `IncelenenIlanStore`  — kullanıcının incelediği ilan kimlikleri
///   · `PendingListingStore` — kayıt öncesi ilan taslağı
///
/// İkisi de `flutter_secure_storage` içinde ve KULLANICIYA ÖZELDİR.
/// Aynı cihazda ikinci bir hesapla giriş yapıldığında önceki
/// kullanıcının incelediği ilanlar "okundu" görünüyor ve yarım kalmış
/// taslağı yeni kullanıcının karşısına çıkıyordu. Bu bir yetki açığı
/// değil ama KİŞİSEL VERİNİN BAŞKASINA GÖRÜNMESİDİR (KVKK).
///
/// ⚠ ÜÇ EKRANDAN ÇAĞRILIYOR (profil, hesap ayarları x2). Temizliği
/// her birine ayrı ayrı yazmak, bu depoda defalarca yaşanan
/// ayrışmanın aynısını üretirdi: biri güncellenir, öteki eskide
/// kalır. Kural tek yerde.
///
/// ## SIRA
///
/// ⚠ ÖNCE YEREL, SONRA OTURUM. `logout()` sunucuya da gider ve ağ
/// hatasında uzun sürebilir; yerel temizlik onu beklememelidir.
/// Ayrıca `logout` sonrası ekran değişimi başlarsa `context` geçersiz
/// olabilir — bu yüzden denetleyiciler ÖNCEDEN okunur.
///
/// ⚠ YEREL TEMİZLİK HATA VERSE DE OTURUM KAPANIR: kullanıcının
/// çıkamaması, artık verinin kalmasından daha kötüdür.
///
/// ## KAPSAM DIŞI
///
/// ⚠ `AccountTestStore` TEMİZLENMEZ: adı üstünde, DEBUG test hesabı
/// deposudur ve `kDebugMode` ile tohumlanır. Çıkışta silinmesi
/// geliştirme akışını bozar; release'te zaten hiç yazılmaz.
/// ═══════════════════════════════════════════════════════════════
Future<void> oturumuKapat(BuildContext context) async {
  final auth = context.read<AuthController>();
  final incelenen = context.read<IncelenenIlanController>();
  final taslak = context.read<PendingListingController>();

  try {
    await incelenen.clear();
    await taslak.clear();
  } catch (_) {
    // Yerel temizlik başarısız olsa da çıkış engellenmez.
  }

  await auth.logout();
}
