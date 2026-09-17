import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// CİHAZ OTURUM TERCİHİ — "Beni Hatırla".
///
/// ⚠ NE YAPAR: kullanıcı giriş yaparken kutucuğu işaretlerse, o CİHAZ
/// bir daha kimlik sormaz. Uygulama açıldığında karşılama ekranı
/// atlanır ve kullanıcı doğrudan kendi rol paneline gider.
///
/// ⚠ NE YAPMAZ: şifre SAKLAMAZ. Yalnız telefon numarası ve tercih
/// bayrağı tutulur. Gerçek kimlik doğrulama backend'e taşındığında
/// burada oturum JETONU tutulacaktır — numara yalnız mock/geçiş
/// dönemi içindir.
///
/// ⚠ Depolama `flutter_secure_storage`: Android'de
/// EncryptedSharedPreferences, iOS'ta Keychain. Düz
/// `SharedPreferences` KULLANILMAZ — cihaz yedeğiyle dışarı alınabilir.
///
/// ## ÇIKIŞ
///
/// Kullanıcı profilden çıkış yaptığında [temizle] çağrılır ve cihaz
/// artık hatırlamaz. Bu KASITLI bir karardır: "beni hatırla" oturumu
/// sonsuza kadar açık tutmaz, yalnız kullanıcı kendisi kapatana kadar.
class OturumTercihi {
  static const _kBayrak = 'oturum_hatirla';
  static const _kTelefon = 'oturum_telefon';

  final FlutterSecureStorage _s;

  OturumTercihi([FlutterSecureStorage? storage])
      : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  /// ⚠ DEPO HATASI AKIŞI KESMEZ.
  ///
  /// `flutter_secure_storage` bir PLATFORM EKLENTİSİDİR. Kanal hazır
  /// değilse (widget testi, ilk açılış yarışı, kısıtlı cihaz)
  /// `MissingPluginException` atar.
  ///
  /// "Beni Hatırla" bir KOLAYLIKTIR; giriş akışının kritik parçası
  /// değildir. Yazılamazsa kullanıcı yine giriş yapabilmeli, çıkış
  /// yapabilmeli, uygulamayı açabilmelidir. Bu yüzden tüm işlemler
  /// sessizce yutulur.
  ///
  /// ⚠ Okuma hatası `false` döner: cihaz HATIRLAMIYOR sayılır.
  /// Güvenli taraf budur — belirsizlikte otomatik giriş YAPILMAZ.

  /// Tercihi kaydeder. [telefon] ham yerel biçimdir (`05XXXXXXXXX`).
  Future<void> kaydet(String telefon) async {
    try {
      await _s.write(key: _kBayrak, value: '1');
      await _s.write(key: _kTelefon, value: telefon);
    } catch (_) {
      // Tercih kaydedilemedi — giriş yine tamamlanır.
    }
  }

  /// AÇILIŞTA BEKLENEN EN UZUN SÜRE.
  ///
  /// ⚠ ZORUNLU: platform kanalı bazı ortamlarda (widget testi, mock
  /// binding, kısıtlı cihaz) ne yanıt verir ne hata atar — çağrı
  /// ASKIDA KALIR. `try/catch` bunu yakalayamaz çünkü ortada
  /// exception yoktur.
  ///
  /// Zaman aşımı olmadan splash ekranı sonsuza kadar bekler ve
  /// kullanıcı açılış ekranında kilitli kalır.
  static const _sure = Duration(milliseconds: 400);

  /// Cihaz bu kullanıcıyı hatırlıyor mu?
  ///
  /// ⚠ Hata VEYA zaman aşımında `false` döner: cihaz HATIRLAMIYOR
  /// sayılır. Belirsizlikte otomatik giriş YAPILMAZ — güvenli taraf
  /// budur ve açılış her hâlükârda tamamlanır.
  Future<bool> get hatirlaniyor async {
    try {
      final v = await _s
          .read(key: _kBayrak)
          .timeout(_sure, onTimeout: () => null);
      return v == '1';
    } catch (_) {
      return false;
    }
  }

  /// Hatırlanan telefon — yoksa `null`.
  Future<String?> get telefon async {
    try {
      return await _s
          .read(key: _kTelefon)
          .timeout(_sure, onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  /// Çıkışta çağrılır; cihaz bir daha otomatik giriş yapmaz.
  Future<void> temizle() async {
    try {
      await _s.delete(key: _kBayrak);
      await _s.delete(key: _kTelefon);
    } catch (_) {
      // Silinemedi — oturum zaten kapanıyor.
    }
  }
}

/// ÇİFT ROLLÜ HESAPTA AÇILIŞ ROLÜ.
///
/// ⚠ İŞ KURALI: kullanıcının hem Hizmet Veren hem Hizmet Alan rolü
/// varsa uygulama HİZMET VEREN rolüyle açılır.
///
/// Sebep: hizmet veren tarafı zamana duyarlıdır — gelen iş ilanları
/// 30 saat içinde kapanır ve teklif yarışı vardır. Hizmet alan tarafı
const bool kCiftRoldeSaglayiciOncelikli = true;
